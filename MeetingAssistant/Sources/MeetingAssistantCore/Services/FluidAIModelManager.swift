@preconcurrency import AVFoundation
import FluidAudio
import Foundation
import os.log

/// Manages the lifecycle of FluidAudio models (Download, Load, Initialize).
@MainActor
class FluidAIModelManager: ObservableObject {
    static let shared = FluidAIModelManager()

    private let logger = Logger(subsystem: "MeetingAssistant", category: "FluidAIModelManager")

    @Published var modelState: ModelState = .unloaded
    @Published var progress: Double = 0.0

    private(set) var asrManager: AsrManager?
    private(set) var diarizerManager: OfflineDiarizerManager?

    enum ModelState: String {
        case unloaded
        case downloading
        case loading
        case loaded
        case error
    }

    private init() {}

    /// Loads the ASR models. Downloads them if not present.
    func loadModels() async {
        guard modelState != .loaded && modelState != .loading else { return }

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

            self.asrManager = manager
            modelState = .loaded
            logger.info("ASR Manager initialized successfully.")

        } catch {
            logger.error("Failed to load models: \(error.localizedDescription)")
            modelState = .error
        }
    }

    /// Loads the Diarization models.
    func loadDiarizationModels() async {
        guard diarizerManager == nil else { return }

        logger.info("Loading Diarization models...")

        do {
            let config = OfflineDiarizerConfig()
            let manager = OfflineDiarizerManager(config: config)
            try await manager.prepareModels()

            self.diarizerManager = manager
            logger.info("Diarization Manager initialized.")
        } catch {
            logger.error("Failed to load diarization models: \(error.localizedDescription)")
        }
    }

    /// Structure to hold raw diarization result
    struct DiarizationSegment: Identifiable, Sendable {
        let id = UUID()
        let speakerId: String
        let startTime: Double
        let endTime: Double
    }

    /// Perform speaker diarization on an audio file
    func diarize(audioURL: URL) async throws -> [DiarizationSegment] {
        guard let manager = diarizerManager else {
            logger.warning("Diarizer not loaded, attempting to load...")
            await loadDiarizationModels()
            if diarizerManager == nil {
                throw FluidError.diarizerNotLoaded
            }
            return try await diarize(audioURL: audioURL)
        }

        logger.info("Diarizing audio file: \(audioURL.path)")

        // FluidAudio Diarizer usually handles file reading internally for optimal performance
        // based on the documentation example: let result = try await manager.process(url)

        let result = try await manager.process(audioURL)

        return result.segments.map { segment in
            DiarizationSegment(
                speakerId: String(segment.speakerId),  // Ensure it's string
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
    func transcribe(audioURL: URL) async throws -> (text: String, segments: [AsrSegment]) {
        guard let manager = asrManager, modelState == .loaded else {
            throw FluidError.modelNotLoaded
        }

        logger.info("Transcribing audio file: \(audioURL.path)")

        // Use the file-based API for automatic conversion
        let result = try await manager.transcribe(audioURL, source: .system)

        // Map library segments to our internal struct
        // Assuming result.segments exists and has text, start, end (standard Whisper/Parakeet output)
        let mappedSegments = result.segments.map { segment in
            AsrSegment(
                text: segment.text,
                startTime: Double(segment.start),
                endTime: Double(segment.end)
            )
        }

        return (result.text, mappedSegments)
    }

    private func convertTo16kHz(buffer: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer {
        guard
            let targetFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)
        else {
            throw FluidError.conversionFailed
        }

        if buffer.format.sampleRate == 16000 && buffer.format.channelCount == 1 {
            return buffer
        }

        guard let converter = AVAudioConverter(from: buffer.format, to: targetFormat) else {
            throw FluidError.conversionFailed
        }

        let targetFrameCapacity = AVAudioFrameCount(
            Double(buffer.frameLength) * targetFormat.sampleRate / buffer.format.sampleRate)

        guard
            let targetBuffer = AVAudioPCMBuffer(
                pcmFormat: targetFormat, frameCapacity: targetFrameCapacity)
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

        if let error = error {
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
