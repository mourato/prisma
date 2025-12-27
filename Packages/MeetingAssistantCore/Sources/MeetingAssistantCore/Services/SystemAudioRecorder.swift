import Atomics
import AVFoundation
import Combine
import CoreMedia
import Foundation
import os.log
@preconcurrency import ScreenCaptureKit

// MARK: - System Audio Recorder (Screen Capture Stream)

/// Captures system audio using ScreenCaptureKit and streams buffers via callback.
/// Does NOT write to file directly. Utilized by `AudioRecorder` for mixing.
@MainActor
public class SystemAudioRecorder: ObservableObject, AudioRecordingService {
    public static let shared = SystemAudioRecorder()

    private let logger = Logger(subsystem: "MeetingAssistant", category: "SystemAudioRecorder")

    @Published public private(set) var isRecording = false
    public var isRecordingPublisher: AnyPublisher<Bool, Never> {
        self.$isRecording.eraseToAnyPublisher()
    }

    // Legacy properties maintained for protocol conformance, but not used for file writing
    @Published public private(set) var currentRecordingURL: URL?
    @Published public private(set) var error: Error?

    // MARK: - SCStream

    private var stream: SCStream?
    private var streamOutput: SystemAudioStreamOutput?
    private var audioCaptureQueue: DispatchQueue?

    // MARK: - Streaming Output

    /// Callback for received audio buffers (Thread-safe, called on background queue)
    public var onAudioBuffer: ((AVAudioPCMBuffer) -> Void)?

    // MARK: - Configuration

    private let sampleRate: Double = 48_000.0 // Capture at 48kHz (native often)
    private let channelCount: Int = 2 // Stereo capture for system audio

    private let minVideoDimension = 2
    private let videoFrameRate = 1

    // MARK: - Validation

    private var validationTimer: Timer?
    private let hasReceivedValidBuffer = ManagedAtomic<Bool>(false)
    public var onRecordingError: ((Error) -> Void)?

    private init() {}

    deinit {
        if let stream {
            Task.detached { [stream] in
                try? await stream.stopCapture()
            }
        }
    }

    // MARK: - Public API

    /// Starts system audio capture.
    /// `outputURL` is ignored as this class no longer writes files, but kept for protocol conformance.
    public func startRecording(to outputURL: URL, retryCount: Int = 0) async throws {
        guard !self.isRecording else {
            self.logger.warning("Already recording system audio")
            return
        }

        guard await self.hasPermission() else {
            throw SystemAudioRecorderError.permissionDenied
        }

        self.logger.info("Starting system audio capture stream...")
        self.hasReceivedValidBuffer.store(false, ordering: .relaxed)

        try await self.setupScreenCapture()

        do {
            try await self.stream?.startCapture()
            self.isRecording = true
            self.startValidationTimer()
            self.logger.info("System audio capture started successfully")
        } catch {
            self.logger.error("Failed to start screen capture: \(error.localizedDescription)")
            await self.cleanup()
            throw SystemAudioRecorderError.failedToStartCapture(error)
        }
    }

    public func stopRecording() async -> URL? {
        guard self.isRecording else { return nil }

        self.logger.info("Stopping system audio capture...")

        self.validationTimer?.invalidate()
        self.validationTimer = nil

        if let stream {
            try? await stream.stopCapture()
        }

        await self.cleanup()
        return nil // No file produced by this class directly
    }

    public func openSettings() {
        self.openScreenRecordingSettings()
    }

    // MARK: - Permission Checking

    public func hasPermission() async -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    public func getPermissionState() -> PermissionState {
        CGPreflightScreenCaptureAccess() ? .granted : .notDetermined
    }

    public func requestPermission() async {
        _ = try? await SCShareableContent.current
    }

    public func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Private Methods

    private func setupScreenCapture() async throws {
        let content = try await SCShareableContent.current
        guard let display = content.displays.first else {
            throw SystemAudioRecorderError.noDisplayFound
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()

        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true // Essential to avoid feedback loop if we play back
        config.sampleRate = Int(self.sampleRate)
        config.channelCount = self.channelCount

        // Minimal video
        config.width = self.minVideoDimension
        config.height = self.minVideoDimension
        config.minimumFrameInterval = CMTime(value: 1, timescale: Int32(self.videoFrameRate))

        self.stream = SCStream(filter: filter, configuration: config, delegate: nil)

        let queue = DispatchQueue(label: "MeetingAssistant.systemAudioCapture", qos: .userInitiated)
        self.audioCaptureQueue = queue

        let output = SystemAudioStreamOutput(
            logger: logger,
            onBuffer: { [weak self] buffer in
                self?.handleBuffer(buffer)
            }
        )
        self.streamOutput = output

        try self.stream?.addStreamOutput(output, type: .audio, sampleHandlerQueue: queue)
    }

    private nonisolated func handleBuffer(_ buffer: AVAudioPCMBuffer) {
        // Mark validation
        if !self.hasReceivedValidBuffer.load(ordering: .relaxed) {
            self.hasReceivedValidBuffer.store(true, ordering: .relaxed)
        }

        // Forward buffer to listener
        Task { @MainActor in
            self.onAudioBuffer?(buffer)
        }
    }

    private func cleanup() async {
        if let activeStream = stream {
            try? await activeStream.stopCapture()
        }

        self.stream = nil
        self.streamOutput = nil
        self.audioCaptureQueue = nil
        self.isRecording = false
        self.hasReceivedValidBuffer.store(false, ordering: .relaxed)
    }

    private func startValidationTimer() {
        self.validationTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                await self?.handleValidationResult()
            }
        }
    }

    private func handleValidationResult() async {
        let validationPassed = self.hasReceivedValidBuffer.load(ordering: .relaxed)
        if !validationPassed {
            self.logger.warning("System audio validation failed - no valid buffers received")
            // We don't fail hard here for now, as system audio might just be silent,
            // but for diagnosis it is useful.
        } else {
            self.logger.info("System audio validation successful")
        }
    }
}

// MARK: - Stream Output Handler

private class SystemAudioStreamOutput: NSObject, SCStreamOutput {
    private let logger: Logger
    private let onBuffer: (AVAudioPCMBuffer) -> Void

    init(logger: Logger, onBuffer: @escaping (AVAudioPCMBuffer) -> Void) {
        self.logger = logger
        self.onBuffer = onBuffer
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio, sampleBuffer.isValid else { return }

        guard let buffer = createPCMBuffer(from: sampleBuffer) else { return }
        self.onBuffer(buffer)
    }

    private func createPCMBuffer(from sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        // Handle potential format mismatch or absence
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
            return nil
        }
        let format = AVAudioFormat(cmAudioFormatDescription: formatDescription)
        let frames = AVAudioFrameCount(sampleBuffer.numSamples)

        guard frames > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else {
            return nil
        }
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
    case failedToStartCapture(Error)
    case recordingValidationFailed

    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "Screen recording permission denied. Enable in System Preferences."
        case .noDisplayFound:
            "No display found for audio capture."
        case .invalidFormat:
            "Failed to create audio format."
        case let .failedToStartCapture(error):
            "Failed to start screen capture: \(error.localizedDescription)"
        case .recordingValidationFailed:
            "System audio recording failed - no valid audio received"
        }
    }
}
