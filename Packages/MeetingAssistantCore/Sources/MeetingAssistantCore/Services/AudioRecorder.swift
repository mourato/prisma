import AppKit
import Atomics
@preconcurrency import AVFoundation
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
        static let outputSampleRate: Double = 48_000.0
        static let outputChannels: AVAudioChannelCount = 2
        static let validationInterval: TimeInterval = 1.5
        static let retryDelay: UInt64 = 500_000_000 // 500ms
        static let maxRetries = 2
    }

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
    /// Start recording merged audio (Mic + System) to the specified URL.
    public func startRecording(to outputURL: URL, retryCount: Int = 0) async throws {
        // Stop any existing recording first
        await self.stopRecording()

        AppLogger.info("Starting merged recording", category: .recordingManager, extra: ["path": outputURL.path])

        // 1. Determine Hardware Sample Rate
        // We query a temporary engine to know what the hardware (MainMixer/Output) expects.
        // This ensures we capture System Audio at the same rate, avoiding heavy SRC or -10874 errors.
        let tempEngine = AVAudioEngine()
        let hardwareSampleRate = tempEngine.outputNode.outputFormat(forBus: 0).sampleRate
        let targetSampleRate = (hardwareSampleRate > 0) ? hardwareSampleRate : Constants.outputSampleRate

        AppLogger.info("Detected Hardware Sample Rate: \(targetSampleRate)", category: .recordingManager)

        // 2. Start Capture
        // Start system capture with the matching rate
        try await self.systemRecorder.startRecording(to: outputURL, sampleRate: targetSampleRate)

        do {
            try self.setupAndStartEngine(writingTo: outputURL, retryCount: retryCount, sampleRate: targetSampleRate)
        } catch {
            await self.stopRecording()
            throw error
        }
    }

    // MARK: - Engine Setup Helpers

    private func setupAndStartEngine(writingTo outputURL: URL, retryCount: Int, sampleRate: Double) throws {
        AppLogger.debug("Setting up Audio Engine...", category: .recordingManager)
        let engine = AVAudioEngine()
        let mixer = AVAudioMixerNode()
        engine.attach(mixer)

        self.audioEngine = engine
        self.mixerNode = mixer

        AppLogger.debug("Configuring inputs...", category: .recordingManager)
        try self.configureInputs(engine: engine, mixer: mixer, sampleRate: sampleRate)
        AppLogger.debug("Configuring worker...", category: .recordingManager)
        try self.configureWorker(writingTo: outputURL, mixer: mixer)

        AppLogger.debug("Starting engine...", category: .recordingManager)
        try self.startAudioEngine(engine, outputURL: outputURL, retryCount: retryCount)
        self.currentRecordingURL = outputURL
        AppLogger.debug("Audio Engine setup complete.", category: .recordingManager)
    }

    private func configureInputs(engine: AVAudioEngine, mixer: AVAudioMixerNode, sampleRate: Double) throws {
        AppLogger.debug("Connecting Microphone...", category: .recordingManager)
        try self.connectMicrophone(to: engine, mixer: mixer)
        AppLogger.debug("Connecting System Audio...", category: .recordingManager)
        try self.connectSystemAudio(to: engine, mixer: mixer, sampleRate: sampleRate)

        // Connect mixer to mainMixer without forcing a specific format.
        // This allows the engine to align with the hardware output sample rate (e.g., 44.1kHz or 48kHz)
        // preventing "Invalid Element" (-10877) errors due to failed graph updates or incompatible conversions.
        let mainMixerFormat = engine.mainMixerNode.outputFormat(forBus: 0)
        AppLogger.debug("Main Mixer Output Format: \(mainMixerFormat)", category: .recordingManager)

        engine.connect(mixer, to: engine.mainMixerNode, format: mainMixerFormat)
        engine.mainMixerNode.outputVolume = 0.0
    }

    private func connectMicrophone(to engine: AVAudioEngine, mixer: AVAudioMixerNode) throws {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        guard status == .authorized else {
            AppLogger.warning("Microphone permission not authorized (status: \(status.rawValue)). Skipping microphone connection.", category: .recordingManager)
            return
        }

        let inputNode = engine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: Constants.tapBusNumber)

        guard inputFormat.sampleRate > 0 else {
            throw AudioRecorderError.invalidInputFormat
        }

        guard inputFormat.channelCount > 0 else {
            AppLogger.warning("Microphone input has 0 channels. Skipping connection.", category: .recordingManager)
            return
        }

        engine.connect(inputNode, to: mixer, format: inputFormat)
    }

    private func connectSystemAudio(to engine: AVAudioEngine, mixer: AVAudioMixerNode, sampleRate: Double) throws {
        let sourceNode = self.createSystemSourceNode(queue: self.systemAudioQueue)
        self.systemAudioSourceNode = sourceNode
        engine.attach(sourceNode)

        guard let systemFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate, // Use aligned Hardware Rate
            channels: 2,
            interleaved: false
        ) else {
            throw AudioRecorderError.invalidRecordingFormat
        }

        engine.connect(sourceNode, to: mixer, format: systemFormat)
    }

    private func configureWorker(writingTo url: URL, mixer: AVAudioMixerNode) throws {
        // Use the mixer's actual output format for the Tap.
        // This avoids asking the Tap to perform sample rate conversion, which can be fragile.
        let tapFormat = mixer.outputFormat(forBus: 0)
        AppLogger.debug("Configuring Worker with format: \(tapFormat)", category: .recordingManager)

        try self.worker.start(writingTo: url, format: tapFormat)

        let worker = self.worker
        mixer.installTap(
            onBus: 0,
            bufferSize: Constants.tapBufferSize,
            format: tapFormat // Request exact same format to avoid conversion overhead
        ) { buffer, _ in
            worker.process(buffer)
        }
    }

    private func startAudioEngine(
        _ engine: AVAudioEngine,
        outputURL: URL,
        retryCount: Int
    ) throws {
        AppLogger.debug("Preparing engine...", category: .recordingManager)
        engine.prepare()

        do {
            AppLogger.debug("Calling engine.start()...", category: .recordingManager)
            try engine.start()
            AppLogger.debug("Engine started. IsRunning: \(engine.isRunning)", category: .recordingManager)
            self.isRecording = true
            self.startValidationTimer(url: outputURL, retryCount: retryCount)
            AppLogger.info("Audio engine started successfully", category: .recordingManager)
        } catch {
            AppLogger.fault("Failed to start audio engine", category: .recordingManager, error: error)
            self.cleanupEngine()
            throw AudioRecorderError.failedToStartEngine(error)
        }
    }

    /// Stop recording and finalize the audio file.
    @discardableResult
    public func stopRecording() async -> URL? {
        guard self.isRecording else { return self.currentRecordingURL }

        AppLogger.info("Stopping recording...", category: .recordingManager)

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
        if let engine = self.audioEngine {
            if engine.isRunning {
                engine.stop()
            }
            engine.reset() // Break connections
        }

        self.audioEngine = nil
        self.mixerNode = nil
        self.systemAudioSourceNode = nil
    }

    // MARK: - Permission Checking

    public func hasPermission() async -> Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    public func getPermissionState() -> PermissionState {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
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
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Source Node Configuration

    private nonisolated func createSystemSourceNode(queue: AudioBufferQueue) -> AVAudioSourceNode {
        AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
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

                        // Safety check
                        if framesFilled + framesToCopy <= Int(frameCount) {
                            // Manual copy loop is safest across buffer boundaries without complex memcpy math
                            for i in 0..<framesToCopy {
                                dest[framesFilled + i] = src[i]
                            }
                        }
                    }
                }

                framesFilled += framesToCopy
            }

            // 3. Silence remaining
            if framesFilled < targetFrames {
                for ch in 0..<buffers.count {
                    guard let dest = buffers[ch].mData?.assumingMemoryBound(to: Float.self) else { continue }
                    // Zero fill
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
            AppLogger.info("Recording validation successful", category: .recordingManager)
            return
        }

        AppLogger.error("Recording validation failed - no valid buffers received", category: .recordingManager)
        _ = await self.stopRecording()

        if retryCount < Constants.maxRetries {
            await self.retryRecording(to: url, retryCount: retryCount)
        } else {
            AppLogger.fault("Recording failed after retries", category: .recordingManager)
            let error = AudioRecorderError.recordingValidationFailed
            self.error = error
            self.onRecordingError?(error)
        }
    }

    private func retryRecording(to url: URL, retryCount: Int) async {
        AppLogger.info("Retrying recording", category: .recordingManager, extra: ["attempt": retryCount + 1, "max": Constants.maxRetries])
        do {
            try await Task.sleep(nanoseconds: Constants.retryDelay)
            try await self.startRecording(to: url, retryCount: retryCount + 1)
        } catch {
            AppLogger.error("Retry failed", category: .recordingManager, error: error)
            self.error = error
            self.onRecordingError?(error)
        }
    }

    private func handleWorkerError(_ error: Error) {
        AppLogger.error("Worker error", category: .recordingManager, error: error)
        self.error = error
    }

    private func verifyFileIntegrity(url: URL) {
        let asset = AVAsset(url: url)
        Task {
            do {
                let duration = try await asset.load(.duration)
                AppLogger.info("Recording saved", category: .recordingManager, extra: ["filename": url.lastPathComponent, "duration": duration.seconds])
            } catch {
                AppLogger.error("Verification failed", category: .recordingManager, error: error)
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
                self.audioFile = nil // Close file
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
            "Formato de entrada de áudio inválido do dispositivo"
        case .invalidRecordingFormat:
            "Falha ao criar formato de gravação"
        case let .failedToCreateFile(error):
            "Falha ao criar arquivo de áudio: \(error.localizedDescription)"
        case .failedToCreateConverter:
            "Falha ao criar conversor de formato de áudio"
        case let .failedToStartEngine(error):
            "Falha ao iniciar motor de áudio: \(error.localizedDescription)"
        case let .audioConversionError(error):
            "Falha na conversão de formato de áudio: \(error.localizedDescription)"
        case let .fileWriteFailed(error):
            "Falha ao gravar dados de áudio no arquivo: \(error.localizedDescription)"
        case .recordingValidationFailed:
            "A gravação falhou ao iniciar - nenhum áudio válido recebido do dispositivo"
        }
    }
}
