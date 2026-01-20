@preconcurrency import AVFoundation
import Combine
@preconcurrency import FluidAudio
import Foundation
import os.log

/// Manages the lifecycle of FluidAudio models (Download, Load, Initialize).
@MainActor
public protocol AIModelService: ObservableObject {
    var modelState: FluidAIModelManager.ModelState { get }
    var modelStatePublisher: AnyPublisher<FluidAIModelManager.ModelState, Never> { get }
    func loadModels() async
}

/// Manages the lifecycle of FluidAudio models (Download, Load, Initialize).
@MainActor
public class FluidAIModelManager: ObservableObject, AIModelService {
    public static let shared = FluidAIModelManager()

    private let logger = Logger(subsystem: "MeetingAssistant", category: "FluidAIModelManager")

    @Published public var modelState: ModelState = .unloaded
    public var modelStatePublisher: AnyPublisher<ModelState, Never> {
        $modelState.eraseToAnyPublisher()
    }

    @Published public var progress: Double = 0.0

    private(set) var asrManager: AsrManager?
    private(set) var diarizerManager: OfflineDiarizerManager?

    public enum ModelState: String {
        case unloaded
        case downloading
        case loading
        case loaded
        case error
    }

    private init() {}

    /// Loads the ASR models. Downloads them if not present.
    public func loadModels() async {
        guard modelState != .loaded, modelState != .loading else { return }

        modelState = .downloading
        logger.info("Starting model download/load...")

        do {
            // Use v3 (Multilingual)
            let models = try await AsrModels.downloadAndLoad(version: .v3)

            modelState = .loading
            logger.info("Initializing ASR Manager...")

            // AsrManager initialization
            let manager = AsrManager(config: .default)
            try await manager.initialize(models: models)

            asrManager = manager
            modelState = .loaded
            logger.info("ASR Manager initialized successfully.")

        } catch {
            logger.error("Failed to load models: \(error.localizedDescription)")
            modelState = .error
        }
    }

    /// Loads the Diarization models.
    func loadDiarizationModels(minSpeakers: Int? = nil, maxSpeakers: Int? = nil) async {
        let min = minSpeakers ?? AppSettingsStore.shared.minSpeakers
        let max = maxSpeakers ?? AppSettingsStore.shared.maxSpeakers

        // Check if we already have a manager with these same constraints
        if diarizerManager != nil,
           currentDiarizerMinSpeakers == min,
           currentDiarizerMaxSpeakers == max
        {
            return
        }

        logger.info("Loading Diarization models with constraints: \(min ?? 0)-\(max ?? 0)...")

        do {
            let config = OfflineDiarizerConfig.default
                .withSpeakers(min: min, max: max)

            let manager = OfflineDiarizerManager(config: config)
            try await manager.prepareModels()

            diarizerManager = manager
            currentDiarizerMinSpeakers = min
            currentDiarizerMaxSpeakers = max

            logger.info("Diarization Manager initialized successfully.")
        } catch {
            logger.error("Failed to load diarization models: \(error.localizedDescription)")
        }
    }

    private var currentDiarizerMinSpeakers: Int?
    private var currentDiarizerMaxSpeakers: Int?

    /// Structure to hold raw diarization result
    struct DiarizationSegment: Identifiable, Sendable {
        let id = UUID()
        let speakerId: String
        let startTime: Double
        let endTime: Double
    }

    /// Perform speaker diarization on an audio file
    func diarize(
        audioURL: URL,
        minSpeakers: Int? = nil,
        maxSpeakers: Int? = nil
    ) async throws -> [DiarizationSegment] {
        // Ensure models are loaded with the requested constraints
        await loadDiarizationModels(minSpeakers: minSpeakers, maxSpeakers: maxSpeakers)

        guard let manager = diarizerManager else {
            throw FluidError.diarizerNotLoaded
        }

        logger.info("Diarizing audio file: \(audioURL.path)")

        // If specific constraints provided, update manager config (assuming it supports it at runtime or we recreate)
        // For simplicity, we use the ones set during loadModels which uses AppSettings.
        // If we need runtime override, we'd rebuild the manager.

        let result = try await manager.process(audioURL)

        return result.segments.map { segment in
            DiarizationSegment(
                speakerId: String(segment.speakerId), // Ensure it's string
                startTime: Double(segment.startTimeSeconds),
                endTime: Double(segment.endTimeSeconds)
            )
        }
    }

    /// Structure to hold ASR segment (text + timing)
    struct AsrSegment: Sendable {
        let text: String
        let startTime: Double
        let endTime: Double
    }

    /// Transcribe audio from a URL
    /// Returns: Tuple of (full text, segments)
    func transcribe(
        audioURL: URL,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> (text: String, segments: [AsrSegment]) {
        guard let manager = asrManager, modelState == .loaded else {
            throw FluidError.modelNotLoaded
        }

        logger.info("Transcribing audio file: \(audioURL.path)")

        // Monitor progress via stream if callback provided
        let stream = await manager.transcriptionProgressStream
        let progressTask = Task {
            if let progress {
                do {
                    for try await p in stream {
                        progress(p * 100.0) // Convert to percentage if needed
                    }
                } catch {
                    // Progress stream failed, but we shouldn't fail transcription for this
                }
            }
        }

        // Use the file-based API for automatic conversion
        let result = try await manager.transcribe(audioURL, source: .system)
        progressTask.cancel()

        // Map library tokens to our internal struct

        let mappedSegments = (result.tokenTimings ?? []).compactMap { (token: Any) -> AsrSegment? in
            guard let timing = token as? TokenTiming else { return nil }
            return AsrSegment(
                text: timing.token,
                startTime: Double(timing.startTime),
                endTime: Double(timing.endTime)
            )
        }

        return (result.text, mappedSegments)
    }

    private func convertTo16kHz(buffer: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer {
        guard
            let targetFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false
            )
        else {
            throw FluidError.conversionFailed
        }

        if buffer.format.sampleRate == 16_000, buffer.format.channelCount == 1 {
            return buffer
        }

        guard let converter = AVAudioConverter(from: buffer.format, to: targetFormat) else {
            throw FluidError.conversionFailed
        }

        let targetFrameCapacity = AVAudioFrameCount(
            Double(buffer.frameLength) * targetFormat.sampleRate / buffer.format.sampleRate)

        guard
            let targetBuffer = AVAudioPCMBuffer(
                pcmFormat: targetFormat, frameCapacity: targetFrameCapacity
            )
        else {
            throw FluidError.conversionFailed
        }

        var error: NSError?

        // Use a local capture that is technically unsafe but safe in this context because convert is synchronous
        // To appease the compiler, we can't easily make AVAudioPCMBuffer sendable.
        // But we can define the block.
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        converter.convert(to: targetBuffer, error: &error, withInputFrom: inputBlock)

        if let error {
            throw error
        }

        return targetBuffer
    }

    private func arrayFloat(from buffer: AVAudioPCMBuffer) -> [Float] {
        guard let channelData = buffer.floatChannelData else { return [] }
        let channelPointer = channelData[0]
        return Array(UnsafeBufferPointer(start: channelPointer, count: Int(buffer.frameLength)))
    }
}

enum FluidError: Error {
    case modelNotLoaded
    case diarizerNotLoaded
    case audioReadFailed
    case conversionFailed
}
