import AppKit
import Atomics
import AVFoundation
import Combine
import CoreAudio
import Foundation
import os.log

// MARK: - Audio Recorder (Merged Mic + System)

/// Recorder that merges Microphone (InputNode) and System Audio (ScreenCaptureKit)
/// into a single AAC (.m4a) file using AVAudioEngine's Mixer.
@MainActor
public class AudioRecorder: ObservableObject, AudioRecordingService {
    public static let shared = AudioRecorder()

    // MARK: - Constants

    private enum Constants {
        static let tapBufferSize: AVAudioFrameCount = 4096
        static let tapBusNumber: AVAudioNodeBus = 0
        static let outputSampleRate: Double = 48_000.0 // Standard for AAC/Video
        static let outputChannels: AVAudioChannelCount = 2 // Stereo mix
        static let validationInterval: TimeInterval = 1.5
        static let retryDelay: UInt64 = 500_000_000 // 500ms
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
    private var mixerNode: AVAudioMixerNode?
    private var systemAudioSourceNode: AVAudioSourceNode?

    // MARK: - System Audio Integration

    private let systemRecorder = SystemAudioRecorder.shared
    private let systemAudioQueue = AudioBufferQueue()

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

        // Link System Recorder to Queue
        self.systemRecorder.onAudioBuffer = { [weak self] buffer in
            self?.systemAudioQueue.enqueue(buffer)
        }
    }

    // MARK: - Public API

    /// Start recording merged audio (Mic + System) to the specified URL.
    public func startRecording(to outputURL: URL, retryCount: Int = 0) async throws {
        // Stop any existing recording first
        await self.stopRecording()

        self.logger.info("Starting merged recording to: \(outputURL.path)")

        // 1. Start System Audio Capture
        // We start this first so buffers begin filling for the engine to pull
        try await self.systemRecorder.startRecording(to: outputURL) // URL ignored by system recorder now

        // 2. Setup Audio Engine
        let engine = AVAudioEngine()
        self.audioEngine = engine

        let mixer = AVAudioMixerNode()
        self.mixerNode = mixer
        engine.attach(mixer)

        // Connect Mic (InputNode) -> Mixer
        let inputNode = engine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: Constants.tapBusNumber)
        engine.connect(inputNode, to: mixer, format: inputFormat)

        // Create System Audio Source Node -> Mixer
        let sourceNode = self.createSystemSourceNode()
        self.systemAudioSourceNode = sourceNode
        engine.attach(sourceNode)

        // Connect Source -> Mixer
        // We use the same format as input for simplicity, or standard stereo
        let systemFormat = AVAudioFormat(standardFormatWithSampleRate: Constants.outputSampleRate, channels: 2)
        engine.connect(sourceNode, to: mixer, format: systemFormat)

        // Connect Mixer to Main Output (Speaker) - Optional: Mute execution to prevent feedback if needed?
        // For recording, we just tap the mixer. connect to mainMixerNode to silence it if we want monitoring
        engine.connect(mixer, to: engine.mainMixerNode, format: systemFormat)

        // Mute the main output to prevent hearing yourself/system audio loopback
        engine.mainMixerNode.outputVolume = 0.0

        // 3. Configure Worker (AAC)
        try self.worker.start(writingTo: outputURL, format: systemFormat ?? inputFormat) // Use mixer format
        self.currentRecordingURL = outputURL

        // 4. Install Tap on Mixer Output
        // Tapping the mixer gives us the combined stream (Mic + System)
        let worker = self.worker
        let tapFormat = mixer.outputFormat(forBus: 0)

        mixer.installTap(
            onBus: 0,
            bufferSize: Constants.tapBufferSize,
            format: tapFormat
        ) { buffer, _ in
            worker.process(buffer)
        }

        try self.startAudioEngine(engine, outputURL: outputURL, retryCount: retryCount)
    }

    private func startAudioEngine(
        _ engine: AVAudioEngine,
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
            self.cleanupEngine()
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

        // Stop Engine & System Capture
        _ = await self.systemRecorder.stopRecording()

        self.cleanupEngine()

        // Finalize worker
        let url = await self.worker.stop()

        // Reset state
        self.isRecording = false
        self.currentAveragePower = -160.0
        self.currentPeakPower = -160.0
        self.systemAudioQueue.clear()

        if let url {
            self.verifyFileIntegrity(url: url)
        }

        return url
    }

    private func cleanupEngine() {
        if let mixer = self.mixerNode {
            mixer.removeTap(onBus: 0)
        }
        self.audioEngine?.stop()
        self.audioEngine = nil
        self.mixerNode = nil
        self.systemAudioSourceNode = nil
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

    // MARK: - Source Node Configuration

    private func createSystemSourceNode() -> AVAudioSourceNode {
        // Capture a thread-safe reference to the queue
        let queue = self.systemAudioQueue

        return AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)

            // 1. Identify valid data needs
            let targetFrames = Int(frameCount)
            var framesFilled = 0

            // 2. Pull from queue until satisfied
            while framesFilled < targetFrames {
                // If we don't have a current buffer, try dequeue
                guard let buffer = queue.dequeue() else {
                    break // No data available, fill rest with silence
                }

                let bufferLength = Int(buffer.frameLength)
                let framesToCopy = min(targetFrames - framesFilled, bufferLength)

                // Copy logic (naive implementation for PCM Float)
                // In production this needs robust circular buffer logic to handle partial buffer consumption
                // For this MVP, we are assuming 1:1 consumption or simple drops for safety,
                // but proper pointer arithmetic is required for split buffers.
                //
                // Simplified: We assume samples match and just copy what we can.

                if let srcChannels = buffer.floatChannelData {
                    for ch in 0..<min(buffers.count, Int(buffer.format.channelCount)) {
                        guard let dest = buffers[ch].mData?.assumingMemoryBound(to: Float.self) else { continue }
                        let src = srcChannels[ch]

                        // Copy 'framesToCopy' samples
                        // Offset: dest + framesFilled
                        // Src: src + 0 (Simplification: always consuming full buffer or dropping rest)

                        for i in 0..<framesToCopy {
                            dest[framesFilled + i] = src[i]
                        }
                    }
                }

                framesFilled += framesToCopy
            }

            // 3. Silence remaining
            if framesFilled < targetFrames {
                for ch in 0..<buffers.count {
                    guard let dest = buffers[ch].mData?.assumingMemoryBound(to: Float.self) else { continue }
                    for i in framesFilled..<targetFrames {
                        dest[i] = 0
                    }
                }
            }

            return noErr
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
private final class AudioRecordingWorker: @unchecked Sendable {
    // MARK: - State

    private var audioFile: AVAudioFile?
    private var currentURL: URL?

    // Thread safety
    private let queue = DispatchQueue(label: "MeetingAssistant.audioProcessing", qos: .userInitiated)
    private let lock = NSLock()

    // Atomic state for validation
    private let _hasReceivedValidBuffer = ManagedAtomic<Bool>(false)
    var hasReceivedValidBuffer: Bool {
        self._hasReceivedValidBuffer.load(ordering: .relaxed)
    }

    // Callbacks
    var onPowerUpdate: ((Float, Float) -> Void)?
    var onError: ((Error) -> Void)?

    init() {}

    // MARK: - Lifecycle

    func start(writingTo url: URL, format: AVAudioFormat) throws {
        self.lock.lock()
        defer { lock.unlock() }

        // Reset state
        self.audioFile = nil
        self._hasReceivedValidBuffer.store(false, ordering: .relaxed)

        // Prepare file
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

        // Create AAC Settings
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: 2, // Force Stereo
            AVEncoderBitRateKey: 128_000,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]

        // Create Audio File
        let file = try AVAudioFile(
            forWriting: url,
            settings: settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
        self.audioFile = file
        self.currentURL = url
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
                self.currentURL = nil

                continuation.resume(returning: url)
            }
        }
    }

    // MARK: - Processing

    func process(_ buffer: AVAudioPCMBuffer) {
        self.queue.async { [weak self] in
            self?.processBufferInternal(buffer)
        }
    }

    private func processBufferInternal(_ buffer: AVAudioPCMBuffer) {
        self.calculateMeters(from: buffer)

        self.lock.lock()
        defer { lock.unlock() }

        guard let audioFile else { return }
        guard buffer.frameLength > 0 else { return }

        do {
            try audioFile.write(from: buffer)
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

        // Downsample for metering (inspect every 10th sample)
        for frame in stride(from: 0, to: frameLength, by: 10) {
            let sample = channel[frame]
            let absSample = abs(sample)
            if absSample > peak { peak = absSample }
            sum += sample * sample
        }

        let rms = sqrt(sum / Float(frameLength / 10)) // adjust count
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
