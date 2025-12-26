import AVFoundation
import Atomics
import Combine
import CoreMedia
import Foundation
@preconcurrency import ScreenCaptureKit
import os.log

// MARK: - System Audio Recorder (Screen Capture)

/// Records system audio using ScreenCaptureKit to a separate file.
/// Uses SCStream to capture all system audio (excluding current app).
@MainActor
public class SystemAudioRecorder: ObservableObject, AudioRecordingService {
    public static let shared = SystemAudioRecorder()

    private let logger = Logger(subsystem: "MeetingAssistant", category: "SystemAudioRecorder")

    @Published public private(set) var isRecording = false
    public var isRecordingPublisher: AnyPublisher<Bool, Never> {
        $isRecording.eraseToAnyPublisher()
    }
    @Published public private(set) var currentRecordingURL: URL?
    @Published public private(set) var error: Error?

    // MARK: - SCStream
    private var stream: SCStream?
    private var streamOutput: SystemAudioStreamOutput?
    private var audioCaptureQueue: DispatchQueue?

    // MARK: - File Writing (nonisolated for callback)
    nonisolated(unsafe) private var audioFile: AVAudioFile?
    private let fileWriteLock = NSLock()

    // MARK: - Configuration
    private let sampleRate: Double = 16000.0
    private let channelCount: Int = 1

    // Minimal video config (we only want audio)
    private let minVideoDimension = 2
    private let videoFrameRate = 1

    // MARK: - Validation
    private var validationTimer: Timer?
    private let hasReceivedValidBuffer = ManagedAtomic<Bool>(false)
    public var onRecordingError: ((Error) -> Void)?

    private init() {}

    // MARK: - Deinit
    // NOTE: Ensures SCStream is stopped even on unexpected termination.
    // Without this, macOS keeps screen/audio capture active after crash.
    deinit {
        // Synchronously stop stream to prevent orphaned capture sessions
        if let stream = stream {
            let semaphore = DispatchSemaphore(value: 0)
            Task {
                try? await stream.stopCapture()
                semaphore.signal()
            }
            // Wait up to 1 second for cleanup
            _ = semaphore.wait(timeout: .now() + 1.0)
        }

        // Ensure file is finalized
        _ = getAndClearAudioFile()
    }

    // MARK: - Public API

    /// Start recording system audio to the specified URL.
    /// Note: retryCount is ignored for SystemAudio currently but required by protocol.
    public func startRecording(to outputURL: URL, retryCount: Int = 0) async throws {
        guard !isRecording else {
            logger.warning("Already recording system audio")
            return
        }

        guard await hasPermission() else {
            throw SystemAudioRecorderError.permissionDenied
        }

        logger.info("Starting system audio recording to: \(outputURL.path)")
        hasReceivedValidBuffer.store(false, ordering: .relaxed)

        // Setup SCStream
        try await setupScreenCapture()

        // Prepare output file (stereo 48kHz WAV)
        guard
            let format = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: sampleRate,
                channels: AVAudioChannelCount(channelCount),
                interleaved: false
            )
        else {
            throw SystemAudioRecorderError.invalidFormat
        }

        do {
            if FileManager.default.fileExists(atPath: outputURL.path) {
                try FileManager.default.removeItem(at: outputURL)
            }

            let file = try AVAudioFile(
                forWriting: outputURL,
                settings: format.settings,
                commonFormat: format.commonFormat,
                interleaved: format.isInterleaved
            )

            // Use sync dispatch to set file (avoids NSLock in async context)
            setAudioFile(file)
            currentRecordingURL = outputURL

        } catch {
            logger.error("Failed to create audio file: \(error.localizedDescription)")
            throw SystemAudioRecorderError.failedToCreateFile(error)
        }

        // Start capture
        do {
            try await stream?.startCapture()
            isRecording = true
            startValidationTimer()
            logger.info("System audio capture started successfully")
        } catch {
            logger.error("Failed to start screen capture: \(error.localizedDescription)")
            await cleanup()
            throw SystemAudioRecorderError.failedToStartCapture(error)
        }
    }

    public func openSettings() {
        openScreenRecordingSettings()
    }

    // openScreenRecordingSettings is defined in Permission Checking section below, removed valid redeclaration here

    /// Stop recording and finalize the audio file.
    @discardableResult
    public func stopRecording() async -> URL? {
        guard isRecording else { return currentRecordingURL }

        logger.info("Stopping system audio recording...")

        validationTimer?.invalidate()
        validationTimer = nil

        if let stream = stream {
            try? await stream.stopCapture()
        }

        let url = currentRecordingURL
        await cleanup()

        if let url = url {
            verifyFileIntegrity(url: url)
        }

        return url
    }

    // MARK: - Permission Checking

    public func hasPermission() async -> Bool {
        return CGPreflightScreenCaptureAccess()
    }

    /// Returns the detailed permission state for screen recording.
    /// Note: macOS screen recording only has granted/denied visible states.
    public func getPermissionState() -> PermissionState {
        // CGPreflightScreenCaptureAccess returns true if permission was previously granted
        // It returns false if denied or never requested
        // Unfortunately, macOS doesn't distinguish between "not determined" and "denied"
        // for screen recording via API, so we use a simple binary check
        return CGPreflightScreenCaptureAccess() ? .granted : .notDetermined
    }

    public func requestPermission() async {
        _ = try? await SCShareableContent.current
    }

    public func openScreenRecordingSettings() {
        if let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
        {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Thread-Safe Helpers

    nonisolated private func setAudioFile(_ file: AVAudioFile?) {
        fileWriteLock.lock()
        audioFile = file
        fileWriteLock.unlock()
    }

    nonisolated private func getAndClearAudioFile() -> AVAudioFile? {
        fileWriteLock.lock()
        let file = audioFile
        audioFile = nil
        fileWriteLock.unlock()
        return file
    }

    nonisolated private func markValidBufferReceived() {
        hasReceivedValidBuffer.store(true, ordering: .relaxed)
    }

    // MARK: - Private Methods

    private func setupScreenCapture() async throws {
        let content = try await SCShareableContent.current

        guard let display = content.displays.first else {
            throw SystemAudioRecorderError.noDisplayFound
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()

        // Audio configuration
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        config.sampleRate = Int(sampleRate)
        config.channelCount = channelCount

        // Minimal video (required by SCStream but we don't use it)
        config.width = minVideoDimension
        config.height = minVideoDimension
        config.minimumFrameInterval = CMTime(value: 1, timescale: Int32(videoFrameRate))

        stream = SCStream(filter: filter, configuration: config, delegate: nil)

        let queue = DispatchQueue(label: "MeetingAssistant.systemAudioCapture", qos: .userInitiated)
        audioCaptureQueue = queue

        // Create output handler
        let output = SystemAudioStreamOutput(
            audioFile: { [weak self] in self?.audioFile },
            fileLock: fileWriteLock,
            logger: logger,
            onValidBuffer: { [weak self] in
                self?.markValidBufferReceived()
            }
        )
        streamOutput = output

        try stream?.addStreamOutput(output, type: .audio, sampleHandlerQueue: queue)
    }

    private func cleanup() async {
        // IMPORTANT: Stop the stream BEFORE releasing reference
        // Without this, macOS keeps capture active even after process ends
        if let activeStream = stream {
            do {
                try await activeStream.stopCapture()
                logger.debug("SCStream stopped successfully during cleanup")
            } catch {
                logger.warning(
                    "Failed to stop SCStream during cleanup: \(error.localizedDescription)")
            }
        }

        stream = nil
        streamOutput = nil
        audioCaptureQueue = nil

        _ = getAndClearAudioFile()

        isRecording = false
        hasReceivedValidBuffer.store(false, ordering: .relaxed)
    }

    private func startValidationTimer() {
        validationTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) {
            [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }

                let validationPassed = self.hasReceivedValidBuffer.load(ordering: .relaxed)

                if !validationPassed {
                    self.logger.warning(
                        "System audio validation failed - no valid buffers received")
                    let error = SystemAudioRecorderError.recordingValidationFailed
                    self.error = error
                    self.onRecordingError?(error)
                } else {
                    self.logger.info("System audio validation successful")
                }
            }
        }
    }

    private func verifyFileIntegrity(url: URL) {
        let asset = AVAsset(url: url)
        Task {
            do {
                let duration = try await asset.load(.duration)
                logger.info("System audio saved: \(url.lastPathComponent) (\(duration.seconds)s)")
            } catch {
                logger.error("Verification failed: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Stream Output Handler

private class SystemAudioStreamOutput: NSObject, SCStreamOutput {
    private let getAudioFile: () -> AVAudioFile?
    private let fileLock: NSLock
    private let logger: Logger
    private let onValidBuffer: () -> Void

    init(
        audioFile: @escaping () -> AVAudioFile?,
        fileLock: NSLock,
        logger: Logger,
        onValidBuffer: @escaping () -> Void
    ) {
        self.getAudioFile = audioFile
        self.fileLock = fileLock
        self.logger = logger
        self.onValidBuffer = onValidBuffer
    }

    func stream(
        _ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard type == .audio, sampleBuffer.isValid else { return }

        guard let buffer = createPCMBuffer(from: sampleBuffer) else { return }

        fileLock.lock()
        defer { fileLock.unlock() }

        guard let audioFile = getAudioFile() else { return }

        do {
            try audioFile.write(from: buffer)
            onValidBuffer()
        } catch {
            logger.error("Failed to write system audio buffer: \(error.localizedDescription)")
        }
    }

    private func createPCMBuffer(from sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
            return nil
        }
        let format = AVAudioFormat(cmAudioFormatDescription: formatDescription)

        let frames = AVAudioFrameCount(sampleBuffer.numSamples)

        guard frames > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)
        else { return nil }
        buffer.frameLength = frames

        let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(
            sampleBuffer,
            at: 0,
            frameCount: Int32(frames),
            into: buffer.mutableAudioBufferList
        )

        return status == noErr ? buffer : nil
    }
}

// MARK: - Errors

public enum SystemAudioRecorderError: LocalizedError {
    case permissionDenied
    case noDisplayFound
    case invalidFormat
    case failedToCreateFile(Error)
    case failedToStartCapture(Error)
    case recordingValidationFailed

    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Screen recording permission denied. Enable in System Preferences."
        case .noDisplayFound:
            return "No display found for audio capture."
        case .invalidFormat:
            return "Failed to create audio format."
        case .failedToCreateFile(let error):
            return "Failed to create audio file: \(error.localizedDescription)"
        case .failedToStartCapture(let error):
            return "Failed to start screen capture: \(error.localizedDescription)"
        case .recordingValidationFailed:
            return "System audio recording failed - no valid audio received"
        }
    }
}
