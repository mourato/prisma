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

    // ... (rest of properties)

    // MARK: - Audio Engine

    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?

    // Thread-safe file handling (nonisolated for use in tap callback)
    private nonisolated(unsafe) var audioFile: AVAudioFile?
    private nonisolated(unsafe) var recordingFormat: AVAudioFormat?
    private nonisolated(unsafe) var converter: AVAudioConverter?

    // MARK: - Configuration

    // Output format: 16kHz Mono (optimized for transcription)

    // MARK: - Thread Safety

    private let audioProcessingQueue = DispatchQueue(
        label: "MeetingAssistant.audioProcessing",
        qos: .userInitiated
    )
    private let fileWriteLock = NSLock()

    // MARK: - Validation & Retry

    private var validationTimer: Timer?
    private let hasReceivedValidBuffer = ManagedAtomic<Bool>(false)
    public var onRecordingError: ((Error) -> Void)?

    private init() {}

    // MARK: - Public API

    /// Start recording microphone audio to the specified URL.
    /// Uses automatic retry mechanism if initial start fails.
    public func startRecording(to outputURL: URL, retryCount: Int = 0) async throws {
        // Stop any existing recording first
        await self.stopRecording()
        self.hasReceivedValidBuffer.store(false, ordering: .relaxed)

        self.logger.info("Starting microphone recording to: \(outputURL.path)")

        // Create new engine instance
        let engine = AVAudioEngine()
        self.audioEngine = engine

        let input = engine.inputNode
        self.inputNode = input

        let inputFormat = input.outputFormat(forBus: Constants.tapBusNumber)
        try self.validateInputFormat(inputFormat)

        let desiredFormat = try self.createDesiredFormat()
        let audioFile = try self.createAudioFile(at: outputURL, format: desiredFormat)
        let converter = try self.createAudioConverter(from: inputFormat, to: desiredFormat)

        // Store references (thread-safe sync helper)
        self.setFileState(
            format: desiredFormat, file: audioFile, converter: converter, url: outputURL
        )

        // Install tap on input node
        input.installTap(
            onBus: Constants.tapBusNumber, bufferSize: Constants.tapBufferSize, format: inputFormat
        ) { [weak self] buffer, _ in
            guard let self else { return }
            self.audioProcessingQueue.async {
                self.processAudioBuffer(buffer)
            }
        }

        try self.startAudioEngine(engine, input: input, outputURL: outputURL, retryCount: retryCount)
    }

    private func validateInputFormat(_ format: AVAudioFormat) throws {
        guard format.sampleRate > 0, format.channelCount > 0 else {
            self.logger.error("Invalid input format: sample rate or channel count is zero")
            throw AudioRecorderError.invalidInputFormat
        }
    }

    private func createDesiredFormat() throws -> AVAudioFormat {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: Constants.outputSampleRate,
            channels: Constants.outputChannels,
            interleaved: false
        ) else {
            self.logger.error("Failed to create desired recording format")
            throw AudioRecorderError.invalidRecordingFormat
        }
        return format
    }

    private func createAudioFile(at url: URL, format: AVAudioFormat) throws -> AVAudioFile {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

        do {
            return try AVAudioFile(
                forWriting: url,
                settings: format.settings,
                commonFormat: format.commonFormat,
                interleaved: format.isInterleaved
            )
        } catch {
            self.logger.error("Failed to create audio file: \(error.localizedDescription)")
            throw AudioRecorderError.failedToCreateFile(error)
        }
    }

    private func createAudioConverter(
        from inputFormat: AVAudioFormat,
        to outputFormat: AVAudioFormat
    ) throws -> AVAudioConverter {
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            self.logger.error("Failed to create audio format converter")
            throw AudioRecorderError.failedToCreateConverter
        }
        return converter
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
        self.inputNode?.removeTap(onBus: Constants.tapBusNumber)
        self.audioEngine?.stop()

        // Wait for processing queue to finish
        self.audioProcessingQueue.sync {}

        // Clean up file resources (thread-safe sync helper)
        let url = self.clearFileState()

        // Reset state
        self.audioEngine = nil
        self.inputNode = nil
        self.isRecording = false
        self.inputNode = nil
        self.isRecording = false
        self.hasReceivedValidBuffer.store(false, ordering: .relaxed)
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

    /// Returns the detailed permission state for the microphone.
    public func getPermissionState() -> PermissionState {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            return .granted
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        @unknown default:
            return .notDetermined
        }
    }

    public func requestPermission() async {
        await AVCaptureDevice.requestAccess(for: .audio)
    }

    public func openSettings() {
        self.openMicrophoneSettings()
    }

    private func openMicrophoneSettings() {
        if let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
        {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Private Methods

    private func setFileState(
        format: AVAudioFormat, file: AVAudioFile, converter: AVAudioConverter, url: URL
    ) {
        self.fileWriteLock.lock()
        defer { fileWriteLock.unlock() }
        self.recordingFormat = format
        self.audioFile = file
        self.converter = converter
        self.currentRecordingURL = url
    }

    private func clearFileState() -> URL? {
        self.fileWriteLock.lock()
        defer { fileWriteLock.unlock() }
        let url = self.currentRecordingURL
        self.audioFile = nil
        self.converter = nil
        self.recordingFormat = nil
        self.currentRecordingURL = nil
        return url
    }

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
        let validationPassed = self.hasReceivedValidBuffer.load(ordering: .relaxed)

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
        self.logger.info(
            "Retrying recording (attempt \(retryCount + 1)/\(Constants.maxRetries))..."
        )
        do {
            try await Task.sleep(nanoseconds: Constants.retryDelay)
            try await self.startRecording(to: url, retryCount: retryCount + 1)
        } catch {
            self.logger.error("Retry failed: \(error.localizedDescription)")
            self.error = error
            self.onRecordingError?(error)
        }
    }

    private nonisolated func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        self.updateMeters(from: buffer)
        self.writeBufferToFile(buffer)
    }

    private nonisolated func writeBufferToFile(_ buffer: AVAudioPCMBuffer) {
        self.fileWriteLock.lock()
        defer { fileWriteLock.unlock() }

        guard let audioFile,
              let converter,
              let format = recordingFormat
        else { return }

        guard buffer.frameLength > 0 else {
            self.logger.error("Empty buffer received")
            return
        }

        // Calculate output capacity based on sample rate ratio
        let inputSampleRate = buffer.format.sampleRate
        let outputSampleRate = format.sampleRate
        let ratio = outputSampleRate / inputSampleRate
        let outputCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio)

        guard
            let convertedBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: outputCapacity)
        else {
            self.logger.error("Failed to create converted buffer")
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
            self.logger.error("Audio conversion failed: \(error.localizedDescription)")
            return
        }

        do {
            try audioFile.write(from: convertedBuffer)

            // Atomically mark that we have received valid data
            self.hasReceivedValidBuffer.store(true, ordering: .relaxed)

        } catch {
            self.logger.error("File write failed: \(error.localizedDescription)")
        }
    }

    private nonisolated func updateMeters(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }

        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)

        guard channelCount > 0, frameLength > 0 else { return }

        let channel = channelData[0]
        var sum: Float = 0.0
        var peak: Float = 0.0

        for frame in 0..<frameLength {
            let sample = channel[frame]
            let absSample = abs(sample)

            if absSample > peak {
                peak = absSample
            }
            sum += sample * sample
        }

        let rms = sqrt(sum / Float(frameLength))
        let averagePowerDb = 20.0 * log10(max(rms, 0.000_001))
        let peakPowerDb = 20.0 * log10(max(peak, 0.000_001))

        Task { @MainActor in
            self.currentAveragePower = averagePowerDb
            self.currentPeakPower = peakPowerDb
        }
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

/// Thread-safe state for audio converter callback.
/// Used to avoid capturing mutable variables in sendable closures.
private final class ConverterState: @unchecked Sendable {
    var hasProvidedBuffer = false
}
