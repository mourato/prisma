import AppKit
import Atomics
@preconcurrency import AVFoundation
import Combine
import CoreAudio
import Foundation
import os.log

// MARK: - Audio Recorder (Microphone Only)

/// VoiceInk-style audio recorder using AVAudioEngine with direct file writing.
/// Records microphone audio to a 16kHz Mono WAV file.
///
/// Refactored to use a detached `AudioRecordingWorker` to handle audio buffer processing
/// ensuring strict actor isolation safety and preventing crashes on background threads.
@MainActor
public class AudioRecorder: ObservableObject, AudioRecordingService {
    public static let shared = AudioRecorder()

    // MARK: - Constants

    private enum Constants {
        static let tapBufferSize: AVAudioFrameCount = 4096
        static let tapBusNumber: AVAudioNodeBus = 0
        static let outputSampleRate: Double = 16_000.0
        static let outputChannels: AVAudioChannelCount = 1
        static let validationInterval: TimeInterval = 1.5
        static let retryDelay: UInt64 = 500_000_000 // 500ms in nanoseconds
        static let maxRetries = 2
        static let logSubsystem = "MeetingAssistant"
        static let logCategory = "AudioRecorder"
    }

    private let logger = Logger(subsystem: Constants.logSubsystem, category: Constants.logCategory)

    @Published public private(set) var isRecording = false
    public var isRecordingPublisher: AnyPublisher<Bool, Never> {
        self.$isRecording.eraseToAnyPublisher()
    }

    @Published public private(set) var currentRecordingURL: URL?
    @Published public private(set) var error: Error?
    @Published public private(set) var currentAveragePower: Float = -160.0
    @Published public private(set) var currentPeakPower: Float = -160.0

    // MARK: - Audio Engine

    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?

    // MARK: - Worker & State

    /// Thread-safe worker that handles file writing and processing off the main actor.
    private let worker = AudioRecordingWorker()

    private var validationTimer: Timer?
    public var onRecordingError: ((Error) -> Void)?

    private init() {
        // Setup worker callbacks to bridge back to MainActor
        self.worker.onPowerUpdate = { [weak self] avg, peak in
            Task { @MainActor [weak self] in
                self?.currentAveragePower = avg
                self?.currentPeakPower = peak
            }
        }

        self.worker.onError = { [weak self] error in
            Task { @MainActor [weak self] in
                self?.handleWorkerError(error)
            }
        }
    }

    // MARK: - Public API

    /// Start recording microphone audio to the specified URL.
    /// Uses automatic retry mechanism if initial start fails.
    public func startRecording(to outputURL: URL, retryCount: Int = 0) async throws {
        // Stop any existing recording first
        await self.stopRecording()

        self.logger.info("Starting microphone recording to: \(outputURL.path)")

        // Create new engine instance
        let engine = AVAudioEngine()
        self.audioEngine = engine

        let input = engine.inputNode
        self.inputNode = input

        // Validate Input
        let inputFormat = input.outputFormat(forBus: Constants.tapBusNumber)
        try self.validateInputFormat(inputFormat)

        // Configure Worker
        try self.worker.start(writingTo: outputURL, inputFormat: inputFormat)
        self.currentRecordingURL = outputURL

        // Install tap on input node
        // CRITICAL: We capture `worker` (which is thread-safe and independent of MainActor)
        // instead of `self`. This prevents MainActor isolation checks from crashing the audio thread.
        let worker = self.worker
        input.installTap(
            onBus: Constants.tapBusNumber, bufferSize: Constants.tapBufferSize, format: inputFormat
        ) { buffer, _ in
            worker.process(buffer)
        }

        try self.startAudioEngine(engine, input: input, outputURL: outputURL, retryCount: retryCount)
    }

    private func validateInputFormat(_ format: AVAudioFormat) throws {
        guard format.sampleRate > 0, format.channelCount > 0 else {
            self.logger.error("Invalid input format: sample rate or channel count is zero")
            throw AudioRecorderError.invalidInputFormat
        }
    }

    private func startAudioEngine(
        _ engine: AVAudioEngine,
        input: AVAudioInputNode,
        outputURL: URL,
        retryCount: Int
    ) throws {
        engine.prepare()

        do {
            try engine.start()
            self.isRecording = true
            self.startValidationTimer(url: outputURL, retryCount: retryCount)
            self.logger.info("Audio engine started successfully")
        } catch {
            self.logger.error("Failed to start audio engine: \(error.localizedDescription)")
            input.removeTap(onBus: Constants.tapBusNumber)
            throw AudioRecorderError.failedToStartEngine(error)
        }
    }

    /// Stop recording and finalize the audio file.
    @discardableResult
    public func stopRecording() async -> URL? {
        guard self.isRecording else { return self.currentRecordingURL }

        self.logger.info("Stopping recording...")

        // Cancel validation timer
        self.validationTimer?.invalidate()
        self.validationTimer = nil

        // Remove tap and stop engine
        if let input = self.inputNode {
            input.removeTap(onBus: Constants.tapBusNumber)
        }
        self.audioEngine?.stop()

        // Finalize worker
        let url = await self.worker.stop()

        // Reset state
        self.audioEngine = nil
        self.inputNode = nil
        self.isRecording = false
        self.currentAveragePower = -160.0
        self.currentPeakPower = -160.0

        if let url {
            self.verifyFileIntegrity(url: url)
        }

        return url
    }

    // MARK: - Permission Checking

    public func hasPermission() async -> Bool {
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        return micStatus == .authorized
    }

    public func getPermissionState() -> PermissionState {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized: return .granted
        case .denied: return .denied
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        @unknown default: return .notDetermined
        }
    }

    public func requestPermission() async {
        await AVCaptureDevice.requestAccess(for: .audio)
    }

    public func openSettings() {
        if let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
        {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Validation & Retry

    private func startValidationTimer(url: URL, retryCount: Int) {
        self.validationTimer = Timer.scheduledTimer(
            withTimeInterval: Constants.validationInterval, repeats: false
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleValidationTimeout(url: url, retryCount: retryCount)
            }
        }
    }

    private func handleValidationTimeout(url: URL, retryCount: Int) async {
        let validationPassed = self.worker.hasReceivedValidBuffer

        guard !validationPassed else {
            self.logger.info("Recording validation successful")
            return
        }

        self.logger.warning("Recording validation failed - no valid buffers received")
        _ = await self.stopRecording()

        if retryCount < Constants.maxRetries {
            await self.retryRecording(to: url, retryCount: retryCount)
        } else {
            self.logger.error("Recording failed after 2 retry attempts")
            let validationError = AudioRecorderError.recordingValidationFailed
            self.error = validationError
            self.onRecordingError?(validationError)
        }
    }

    private func retryRecording(to url: URL, retryCount: Int) async {
        self.logger.info("Retrying recording (attempt \(retryCount + 1)/\(Constants.maxRetries))...")
        do {
            try await Task.sleep(nanoseconds: Constants.retryDelay)
            try await self.startRecording(to: url, retryCount: retryCount + 1)
        } catch {
            self.logger.error("Retry failed: \(error.localizedDescription)")
            self.error = error
            self.onRecordingError?(error)
        }
    }

    private func handleWorkerError(_ error: Error) {
        self.logger.error("Worker error: \(error.localizedDescription)")
        self.error = error
    }

    private func verifyFileIntegrity(url: URL) {
        let asset = AVAsset(url: url)
        Task {
            do {
                let duration = try await asset.load(.duration)
                self.logger.info("Recording saved: \(url.lastPathComponent) (\(duration.seconds)s)")
            } catch {
                self.logger.error("Verification failed: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Audio Recording Worker

/// A thread-safe, non-isolated worker class that handles Audio Processing and File Writing.
/// This class is strictly separate from MainActor to avoid isolation violation crashes.
private final class AudioRecordingWorker: @unchecked Sendable {
    // MARK: - State

    private var audioFile: AVAudioFile?
    private var recordingFormat: AVAudioFormat?
    private var converter: AVAudioConverter?
    private var currentURL: URL?

    // Thread safety
    private let queue = DispatchQueue(label: "MeetingAssistant.audioProcessing", qos: .userInitiated)
    private let lock = NSLock()

    // Atomic state for validation (safe to read from any thread)
    private let _hasReceivedValidBuffer = ManagedAtomic<Bool>(false)
    var hasReceivedValidBuffer: Bool {
        self._hasReceivedValidBuffer.load(ordering: .relaxed)
    }

    // Callbacks
    var onPowerUpdate: ((Float, Float) -> Void)?
    var onError: ((Error) -> Void)?

    // Constants from parent
    private let outputSampleRate = 16_000.0
    private let outputChannels = AVAudioChannelCount(1)

    init() {}

    // MARK: - Lifecycle

    func start(writingTo url: URL, inputFormat: AVAudioFormat) throws {
        self.lock.lock()
        defer { lock.unlock() }

        // Reset state
        self.audioFile = nil
        self.converter = nil
        self.recordingFormat = nil
        self._hasReceivedValidBuffer.store(false, ordering: .relaxed)

        // Prepare file
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

        // Create Desired Format (16kHz Mono)
        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: outputSampleRate,
            channels: outputChannels,
            interleaved: false
        ) else {
            throw AudioRecorderError.invalidRecordingFormat
        }
        self.recordingFormat = outputFormat

        // Create Audio File
        let file = try AVAudioFile(
            forWriting: url,
            settings: outputFormat.settings,
            commonFormat: outputFormat.commonFormat,
            interleaved: outputFormat.isInterleaved
        )
        self.audioFile = file
        self.currentURL = url

        // Create Converter
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw AudioRecorderError.failedToCreateConverter
        }
        self.converter = converter
    }

    func stop() async -> URL? {
        await withCheckedContinuation { continuation in
            self.queue.async { [weak self] in
                guard let self else {
                    continuation.resume(returning: nil)
                    return
                }

                self.lock.lock()
                defer { self.lock.unlock() }

                let url = self.currentURL
                self.audioFile = nil
                self.converter = nil
                self.recordingFormat = nil
                self.currentURL = nil

                continuation.resume(returning: url)
            }
        }
    }

    // MARK: - Processing

    func process(_ buffer: AVAudioPCMBuffer) {
        // Dispatch processing to background queue to avoid blocking audio thread
        self.queue.async { [weak self] in
            self?.processBufferInternal(buffer)
        }
    }

    private func processBufferInternal(_ buffer: AVAudioPCMBuffer) {
        self.calculateMeters(from: buffer)

        self.lock.lock()
        defer { lock.unlock() }

        guard let audioFile,
              let converter,
              let outputFormat = recordingFormat
        else { return }

        guard buffer.frameLength > 0 else { return }

        // Calculate output capacity
        let inputSampleRate = buffer.format.sampleRate
        let ratio = outputFormat.sampleRate / inputSampleRate
        let outputCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio)

        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputCapacity) else {
            return
        }

        var error: NSError?
        let state = ConverterState()

        converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
            if state.hasProvidedBuffer {
                outStatus.pointee = .noDataNow
                return nil
            } else {
                state.hasProvidedBuffer = true
                outStatus.pointee = .haveData
                return buffer
            }
        }

        if let error {
            self.onError?(AudioRecorderError.audioConversionError(error))
            return
        }

        do {
            try audioFile.write(from: convertedBuffer)
            self._hasReceivedValidBuffer.store(true, ordering: .relaxed)
        } catch {
            self.onError?(AudioRecorderError.fileWriteFailed(error))
        }
    }

    private func calculateMeters(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)
        guard channelCount > 0, frameLength > 0 else { return }

        let channel = channelData[0]
        var sum: Float = 0.0
        var peak: Float = 0.0

        // Simple RMS/Peak calculation (optimized for loop)
        for frame in 0..<frameLength {
            let sample = channel[frame]
            let absSample = abs(sample)
            if absSample > peak { peak = absSample }
            sum += sample * sample
        }

        let rms = sqrt(sum / Float(frameLength))
        let averagePowerDb = 20.0 * log10(max(rms, 0.000_001))
        let peakPowerDb = 20.0 * log10(max(peak, 0.000_001))

        self.onPowerUpdate?(averagePowerDb, peakPowerDb)
    }
}

// MARK: - Errors

public enum AudioRecorderError: LocalizedError {
    case invalidInputFormat
    case invalidRecordingFormat
    case failedToCreateFile(Error)
    case failedToCreateConverter
    case failedToStartEngine(Error)
    case audioConversionError(Error)
    case fileWriteFailed(Error)
    case recordingValidationFailed

    public var errorDescription: String? {
        switch self {
        case .invalidInputFormat:
            "Invalid audio input format from device"
        case .invalidRecordingFormat:
            "Failed to create recording format"
        case let .failedToCreateFile(error):
            "Failed to create audio file: \(error.localizedDescription)"
        case .failedToCreateConverter:
            "Failed to create audio format converter"
        case let .failedToStartEngine(error):
            "Failed to start audio engine: \(error.localizedDescription)"
        case let .audioConversionError(error):
            "Audio format conversion failed: \(error.localizedDescription)"
        case let .fileWriteFailed(error):
            "Failed to write audio data to file: \(error.localizedDescription)"
        case .recordingValidationFailed:
            "Recording failed to start - no valid audio received from device"
        }
    }
}

// MARK: - Helper Classes

private final class ConverterState: @unchecked Sendable {
    var hasProvidedBuffer = false
}
