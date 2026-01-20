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
        static let tapBufferSize: AVAudioFrameCount = 2048
        static let tapBusNumber: AVAudioNodeBus = 0
        static let outputSampleRate: Double = 48000.0
        static let outputChannels: AVAudioChannelCount = 2
        static let validationInterval: TimeInterval = 1.5
        static let retryDelay: UInt64 = 500_000_000 // 500ms
        static let maxRetries = 2
    }

    @Published public private(set) var isRecording = false
    public var isRecordingPublisher: AnyPublisher<Bool, Never> {
        $isRecording.eraseToAnyPublisher()
    }

    @Published public private(set) var currentRecordingURL: URL?
    @Published public private(set) var error: Error?
    @Published public private(set) var currentAveragePower: Float = -160.0
    @Published public private(set) var currentPeakPower: Float = -160.0

    // MARK: - Audio Engine

    private var audioEngine: AVAudioEngine?
    private var mixerNode: AVAudioMixerNode?
    private var systemAudioSourceNode: AVAudioSourceNode?

    // MARK: - Dependency Injection for Testing

    private var injectedEngine: AVAudioEngine?

    // MARK: - System Audio Integration

    private let systemRecorder = SystemAudioRecorder.shared
    // Non-isolated to allow background threads (SystemAudioRecorder) to enqueue without MainActor hopping
    private nonisolated let systemAudioQueue = AudioBufferQueue(capacity: 200)
    /// Tracks partially consumed buffers between render cycles to prevent frame loss
    private nonisolated let partialBufferState = PartialBufferState()

    // MARK: - Worker & State

    /// Thread-safe worker that handles file writing and processing off the main actor.
    private let worker = AudioRecordingWorker()
    private var validationTimer: Timer?
    public var onRecordingError: (@Sendable (Error) -> Void)?

    init() {
        // Setup worker callbacks to bridge back to MainActor
        worker.setOnPowerUpdate { [weak self] avg, peak in
            Task { @MainActor [weak self] in
                self?.currentAveragePower = avg
                self?.currentPeakPower = peak
            }
        }

        worker.setOnError { [weak self] error in
            Task { @MainActor [weak self] in
                self?.handleWorkerError(error)
            }
        }

        // Link System Recorder to Queue
        // Capture queue directly to avoid 'self' (MainActor) capture in background thread
        let queue = systemAudioQueue
        systemRecorder.onAudioBuffer = { @Sendable buffer in
            queue.enqueue(buffer)
        }
    }

    // MARK: - Public API

    /// Start recording audio to the specified URL. (Protocol Conformance)
    /// Defaults to .all sources.
    public func startRecording(to outputURL: URL, retryCount: Int) async throws {
        try await startRecording(to: outputURL, source: .all, retryCount: retryCount)
    }

    /// Start recording merged audio (Mic + System) to the specified URL.
    /// - Parameters:
    ///   - outputURL: The destination URL for the audio file.
    ///   - source: The audio source to record.
    ///   - retryCount: Number of retries attempted so far.
    public func startRecording(to outputURL: URL, source: RecordingSource, retryCount: Int = 0) async throws {
        // Stop any existing recording first
        await stopRecording()

        AppLogger.info(
            "Starting recording",
            category: .recordingManager,
            extra: ["path": outputURL.path, "source": source.rawValue]
        )

        // 1. Determine Hardware Sample Rate
        // We query a temporary engine to know what the hardware (MainMixer/Output) expects.
        // This ensures we capture System Audio at the same rate, avoiding heavy SRC or -10874 errors.
        let tempEngine = AVAudioEngine()
        let hardwareSampleRate = tempEngine.outputNode.outputFormat(forBus: 0).sampleRate
        let targetSampleRate = (hardwareSampleRate > 0) ? hardwareSampleRate : Constants.outputSampleRate

        AppLogger.info("Detected Hardware Sample Rate: \(targetSampleRate)", category: .recordingManager)

        // 2. Start Capture
        // Start system capture with the matching rate ONLY if source includes system audio
        if source == .system || source == .all {
            AppLogger.debug("Starting system recorder...", category: .recordingManager)
            try await systemRecorder.startRecording(to: outputURL, sampleRate: targetSampleRate)
        } else {
            AppLogger.debug("Skipping system recorder start (source: \(source.rawValue))", category: .recordingManager)
        }

        do {
            try await setupAndStartEngine(
                writingTo: outputURL,
                source: source,
                retryCount: retryCount,
                sampleRate: targetSampleRate
            )
        } catch {
            await stopRecording()
            throw error
        }
    }

    // MARK: - Engine Setup Helpers

    private func setupAndStartEngine(
        writingTo outputURL: URL,
        source: RecordingSource,
        retryCount: Int,
        sampleRate: Double
    ) async throws {
        AppLogger.debug("Setting up Audio Engine...", category: .recordingManager)
        let engine = injectedEngine ?? AVAudioEngine()
        let mixer = AVAudioMixerNode()
        engine.attach(mixer)

        audioEngine = engine
        mixerNode = mixer

        AppLogger.debug("Configuring inputs...", category: .recordingManager)
        try configureInputs(engine: engine, mixer: mixer, source: source, sampleRate: sampleRate)
        AppLogger.debug("Configuring worker...", category: .recordingManager)
        try await configureWorker(writingTo: outputURL, mixer: mixer)

        // Increase maximum frames per slice to avoid kAudioUnitErr_TooManyFramesToProcess (-10874)
        // when hardware or drivers send buffers larger than the default 512 frames.
        // Using 2048 to reduce HALC overload risk while still handling most buffer sizes.
        let safeMaxFrames: AVAudioFrameCount = 2048
        engine.mainMixerNode.auAudioUnit.maximumFramesToRender = safeMaxFrames
        mixer.auAudioUnit.maximumFramesToRender = safeMaxFrames
        engine.outputNode.auAudioUnit.maximumFramesToRender = safeMaxFrames

        // Also apply to inputNode if we are using it (to be safe against Input AU errors too)
        if source == .microphone || source == .all {
            engine.inputNode.auAudioUnit.maximumFramesToRender = safeMaxFrames
        }

        AppLogger.debug(
            "Set maximumFramesToRender to \(safeMaxFrames) for mainMixer, mixer, and outputNode",
            category: .recordingManager
        )

        AppLogger.debug("Starting engine...", category: .recordingManager)
        try await startAudioEngine(engine, outputURL: outputURL, source: source, retryCount: retryCount)
        currentRecordingURL = outputURL
        AppLogger.debug("Audio Engine setup complete.", category: .recordingManager)
    }

    private func configureInputs(
        engine: AVAudioEngine,
        mixer: AVAudioMixerNode,
        source: RecordingSource,
        sampleRate: Double
    ) throws {
        if source == .microphone || source == .all {
            AppLogger.debug("Connecting Microphone...", category: .recordingManager)
            try connectMicrophone(to: engine, mixer: mixer)
        }

        if source == .system || source == .all {
            AppLogger.debug("Connecting System Audio...", category: .recordingManager)
            try connectSystemAudio(to: engine, mixer: mixer, sampleRate: sampleRate)
        }

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
            AppLogger.warning(
                "Microphone permission not authorized (status: \(status.rawValue)). Skipping microphone connection.",
                category: .recordingManager
            )
            return
        }

        let inputNode = engine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: Constants.tapBusNumber)

        guard inputFormat.sampleRate > 0 else {
            AppLogger.warning(
                "Microphone input has invalid sample rate. Skipping connection.",
                category: .recordingManager
            )
            return
        }

        guard inputFormat.channelCount > 0 else {
            AppLogger.warning("Microphone input has 0 channels. Skipping connection.", category: .recordingManager)
            return
        }

        guard inputFormat.commonFormat == .pcmFormatFloat32 else {
            AppLogger.warning(
                "Microphone input format is not Float32. Skipping connection.",
                category: .recordingManager
            )
            return
        }

        engine.connect(inputNode, to: mixer, format: inputFormat)
    }

    private func connectSystemAudio(to engine: AVAudioEngine, mixer: AVAudioMixerNode, sampleRate: Double) throws {
        let sourceNode = createSystemSourceNode(
            queue: systemAudioQueue,
            partialState: partialBufferState
        )

        systemAudioSourceNode = sourceNode
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

    private func configureWorker(writingTo url: URL, mixer: AVAudioMixerNode) async throws {
        // Use the mixer's actual output format for the Tap.
        // This avoids asking the Tap to perform sample rate conversion, which can be fragile.
        let tapFormat = mixer.outputFormat(forBus: 0)
        AppLogger.debug("Configuring Worker with format: \(tapFormat)", category: .recordingManager)

        try await self.worker.start(writingTo: url, format: tapFormat, fileFormat: AppSettingsStore.shared.audioFormat)

        let worker = worker
        mixer.installTap(
            onBus: 0,
            bufferSize: Constants.tapBufferSize,
            format: tapFormat // Request exact same format to avoid conversion overhead
        ) { @Sendable buffer, _ in
            worker.process(buffer)
        }
    }

    private func startAudioEngine(
        _ engine: AVAudioEngine,
        outputURL: URL,
        source: RecordingSource,
        retryCount: Int
    ) async throws {
        AppLogger.debug("Preparing engine...", category: .recordingManager)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                engine.prepare()
                try engine.start()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: 10_000_000_000)
                throw AudioRecorderError.failedToStartEngine(NSError(
                    domain: "AudioRecorder",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Audio engine start timeout"]
                ))
            }

            try await group.next()
            group.cancelAll()
        }

        AppLogger.debug("Engine started. IsRunning: \(engine.isRunning)", category: .recordingManager)
        isRecording = true
        startValidationTimer(url: outputURL, source: source, retryCount: retryCount)
        AppLogger.info("Audio engine started successfully", category: .recordingManager)
    }

    /// Stop recording and finalize the audio file.
    @discardableResult
    public func stopRecording() async -> URL? {
        guard isRecording else { return currentRecordingURL }

        AppLogger.info("Stopping recording...", category: .recordingManager)

        // Cancel validation timer
        validationTimer?.invalidate()
        validationTimer = nil

        // Stop Engine & System Capture
        _ = await systemRecorder.stopRecording()
        cleanupEngine()

        // Finalize worker
        let url = await worker.stop()

        // Reset state
        isRecording = false
        currentAveragePower = -160.0
        currentPeakPower = -160.0

        // Log dropped frames before clearing (for diagnostics)
        let queueStats = systemAudioQueue.stats
        if queueStats.dropped > 0 {
            AppLogger.warning(
                "System audio frames dropped during session",
                category: .recordingManager,
                extra: ["droppedFrames": queueStats.dropped, "buffersRemaining": queueStats.count]
            )
        }

        systemAudioQueue.clear()
        partialBufferState.clear()

        if let url {
            verifyFileIntegrity(url: url)
        }

        return url
    }

    private func cleanupEngine() {
        if let mixer = mixerNode {
            mixer.removeTap(onBus: 0)
        }
        if let engine = audioEngine {
            if engine.isRunning {
                engine.stop()
            }
            engine.reset() // Break connections
        }

        audioEngine = nil
        mixerNode = nil
        systemAudioSourceNode = nil
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

    /// Creates an AVAudioSourceNode for system audio capture.
    /// - Parameters:
    ///   - queue: Thread-safe queue for audio buffers.
    ///   - partialState: Tracks partially consumed buffers between render cycles.
    /// - Returns: Configured AVAudioSourceNode ready for engine attachment.
    private nonisolated func createSystemSourceNode(
        queue: AudioBufferQueue,
        partialState: PartialBufferState
    ) -> AVAudioSourceNode {
        AVAudioSourceNode { @Sendable [queue, partialState] _, _, frameCount, audioBufferList -> OSStatus in
            self.validateCallbackInputs(
                frameCount: frameCount,
                audioBufferList: audioBufferList,
                queue: queue,
                partialState: partialState
            )
        }
    }

    /// Validates callback inputs before processing audio data.
    /// - Parameters:
    ///   - frameCount: Number of frames requested.
    ///   - audioBufferList: Pointer to audio buffer list structure.
    /// - Returns: OSStatus error code; noErr if validation passes.
    private nonisolated func validateCallbackInputs(
        frameCount: UInt32,
        audioBufferList: UnsafeMutablePointer<AudioBufferList>,
        queue: AudioBufferQueue,
        partialState: PartialBufferState
    ) -> OSStatus {
        guard frameCount > 0 else {
            return -50 // kAudio_ParamError
        }

        return processAudioBuffers(
            frameCount: frameCount,
            audioBufferList: audioBufferList,
            queue: queue,
            partialState: partialState
        )
    }

    /// Processes audio buffers by filling them with silence.
    /// - Parameters:
    ///   - frameCount: Number of frames to process.
    ///   - audioBufferList: Pointer to audio buffer list structure.
    /// - Returns: OSStatus indicating success (noErr) or failure.
    private nonisolated func processAudioBuffers(
        frameCount: UInt32,
        audioBufferList: UnsafeMutablePointer<AudioBufferList>,
        queue: AudioBufferQueue,
        partialState: PartialBufferState
    ) -> OSStatus {
        let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
        let targetFrames = Int(frameCount)
        var framesFilled = 0

        // 1. First, satisfy from partial state if something was left from previous cycle
        if partialState.hasPartial {
            framesFilled += partialState.consume(maxFrames: targetFrames, into: buffers, destOffset: 0)
        }

        // 2. Fill the rest from the queue
        while framesFilled < targetFrames {
            guard let nextBuffer = queue.dequeue() else {
                break // No more data: stop filling and return noErr (filled with silence)
            }

            let framesToCopy = min(Int(nextBuffer.frameLength), targetFrames - framesFilled)

            let copied = PartialBufferState.copy(
                from: nextBuffer,
                srcOffset: 0,
                maxFrames: framesToCopy,
                into: buffers,
                destOffset: framesFilled
            )

            framesFilled += copied

            // If the buffer was only partially used, store it for next render cycle
            if copied < Int(nextBuffer.frameLength) {
                partialState.setBuffer(nextBuffer, offset: copied)
            }
        }

        // 3. Zero out any remaining frames to avoid noise/clicks
        if framesFilled < targetFrames {
            fillBuffersWithSilence(
                buffers: buffers,
                bufferCount: 2,
                targetFrames: targetFrames - framesFilled,
                destOffset: framesFilled
            )
        }

        return noErr
    }

    /// Fills audio buffers with silence (zeros).
    /// - Parameters:
    ///   - buffers: Pointer to mutable audio buffer list.
    ///   - bufferCount: Number of buffers to process.
    ///   - targetFrames: Number of frames to zero out.
    private nonisolated func fillBuffersWithSilence(
        buffers: UnsafeMutableAudioBufferListPointer,
        bufferCount: Int,
        targetFrames: Int,
        destOffset: Int = 0
    ) {
        for ch in 0..<bufferCount {
            guard ch < 2 else { break }
            let destBuffer = buffers[ch]
            if let dest = destBuffer.mData?.assumingMemoryBound(to: Float.self) {
                memset(dest.advanced(by: destOffset), 0, targetFrames * MemoryLayout<Float>.size)
            }
        }
    }

    // MARK: - Validation & Retry

    private func startValidationTimer(url: URL, source: RecordingSource, retryCount: Int) {
        validationTimer = Timer.scheduledTimer(
            withTimeInterval: Constants.validationInterval, repeats: false
        ) { @Sendable [weak self] _ in
            Task { @MainActor in
                await self?.handleValidationTimeout(url: url, source: source, retryCount: retryCount)
            }
        }
    }

    private func handleValidationTimeout(url: URL, source: RecordingSource, retryCount: Int) async {
        let validationPassed = await worker.getHasReceivedValidBuffer()

        guard !validationPassed else {
            AppLogger.info("Recording validation successful", category: .recordingManager)
            return
        }

        AppLogger.error("Recording validation failed - no valid buffers received", category: .recordingManager)
        _ = await stopRecording()

        if retryCount < Constants.maxRetries {
            await retryRecording(to: url, source: source, retryCount: retryCount)
        } else {
            AppLogger.fault("Recording failed after retries", category: .recordingManager)
            let error = AudioRecorderError.recordingValidationFailed
            self.error = error
            onRecordingError?(error)
        }
    }

    private func retryRecording(to url: URL, source: RecordingSource, retryCount: Int) async {
        AppLogger.info(
            "Retrying recording",
            category: .recordingManager,
            extra: ["attempt": retryCount + 1, "max": Constants.maxRetries]
        )
        do {
            try await Task.sleep(nanoseconds: Constants.retryDelay)
            try await startRecording(to: url, source: source, retryCount: retryCount + 1)
        } catch {
            AppLogger.error("Retry failed", category: .recordingManager, error: error)
            self.error = error
            onRecordingError?(error)
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
                AppLogger.info(
                    "Recording saved",
                    category: .recordingManager,
                    extra: ["filename": url.lastPathComponent, "duration": duration.seconds]
                )
            } catch {
                AppLogger.error("Verification failed", category: .recordingManager, error: error)
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
