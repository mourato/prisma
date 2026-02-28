import AppKit
import Atomics
@preconcurrency import AVFoundation
import Combine
import CoreAudio
import Foundation
import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import os.log

// MARK: - Audio Recorder (Merged Mic + System)

/// Recorder that merges Microphone (InputNode) and System Audio (ScreenCaptureKit)
/// into a single AAC (.m4a) file using AVAudioEngine's Mixer.
@MainActor
public class AudioRecorder: ObservableObject, AudioRecordingService {
    public static let shared = AudioRecorder()

    // MARK: - Constants

    enum Constants {
        static let tapBufferSize: AVAudioFrameCount = 2_048
        static let tapBusNumber: AVAudioNodeBus = 0
        static let outputSampleRate: Double = 48_000.0
        static let outputChannels: AVAudioChannelCount = 2
        static let validationInterval: TimeInterval = 1.5
        static let retryDelay: UInt64 = 500_000_000 // 500ms
        static let maxRetries = 2
        static let micDiagnosticsEnabled = true
        static let engineStartTimeout: UInt64 = 10_000_000_000 // 10 seconds
        static let fallbackSampleRate: Double = 48_000.0
        static let fallbackChannels: Int = 1
        static let fallbackBitRate: Int = 128_000
        static let fallbackMeterUpdateInterval: TimeInterval = 0.2
        static let fallbackMeterTimerToleranceRatio: Double = 0.25
        static let outputMuteDelayAfterStart: UInt64 = 200_000_000 // 200ms
        static let retriableEngineStartErrorCodes: Set<Int> = [-10_875, -10_877]
    }

    @Published public internal(set) var isRecording = false
    public var isRecordingPublisher: AnyPublisher<Bool, Never> {
        $isRecording.eraseToAnyPublisher()
    }

    @Published public internal(set) var currentRecordingURL: URL?
    @Published public internal(set) var error: Error?
    @Published public internal(set) var currentAveragePower: Float = -160.0
    @Published public internal(set) var currentPeakPower: Float = -160.0

    // MARK: - Audio Engine

    var audioEngine: AVAudioEngine?
    var mixerNode: AVAudioMixerNode?
    var systemAudioSourceNode: AVAudioSourceNode?

    /// Simple recorder for mic-only recordings. Bypasses AVAudioEngine and its
    /// aggregate device, which can malfunction on macOS with USB microphones.
    private var simpleRecorder: AVAudioRecorder?
    private var simpleMeterTimer: Timer?

    // MARK: - Dependency Injection for Testing

    private var injectedEngine: AVAudioEngine?

    // MARK: - System Audio Integration

    let systemRecorder = SystemAudioRecorder.shared
    /// Non-isolated to allow background threads (SystemAudioRecorder) to enqueue without MainActor hopping
    nonisolated let systemAudioQueue = AudioBufferQueue(capacity: 200)
    /// Tracks partially consumed buffers between render cycles to prevent frame loss
    nonisolated let partialBufferState = PartialBufferState()

    // MARK: - Worker & State

    /// Thread-safe worker that handles file writing and processing off the main actor.
    let worker = AudioRecordingWorker()
    var validationTimer: Timer?
    public var onRecordingError: (@Sendable (Error) -> Void)?

    private let muteController = SystemAudioMuteController.shared
    private var outputMuteSession: SystemAudioMuteController.OutputMuteSession?
    private var outputMuteTask: Task<Void, Never>?
    let deviceManager = AudioDeviceManager()
    var micDiagnosticsTimer: Timer?
    var isMicDiagnosticsTapInstalled = false
    let micDiagnosticsPeakBits = ManagedAtomic<UInt32>(0)
    var micProbeWorker: AudioRecordingWorker?
    var micProbeStopTask: Task<Void, Never>?
    var micRecorderProbe: AVAudioRecorder?
    var micRecorderProbeStopTask: Task<Void, Never>?
    private var fallbackRecorder: AVAudioRecorder?
    private var fallbackMeterTimer: Timer?

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
        systemRecorder.onRecordingError = { [weak self] error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                AppLogger.error(
                    "System audio recorder failed during active session",
                    category: .recordingManager,
                    error: error
                )
                self.error = error
                onRecordingError?(error)

                if isRecording {
                    _ = await stopRecording()
                }
            }
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

        // Reset per-session mute state
        resetOutputMuteState()

        AppLogger.info(
            "Starting recording",
            category: .recordingManager,
            extra: ["path": outputURL.path, "source": source.rawValue]
        )

        // Muting system output must only apply to Dictation/Assistant (mic-only).
        // Meetings (system + mic) must preserve the system output volume.
        //
        // IMPORTANT: Skip mute when the system default output device is the same as the
        // input device (USB mic). AVAudioEngine creates aggregate devices combining
        // input + output; muting the aggregate's output also silences its input.
        let shouldMuteOutput = AppSettingsStore.shared.muteOutputDuringRecording && source == .microphone
        if shouldMuteOutput {
            let defaultOutputID = deviceManager.getDefaultOutputDeviceID()
            let defaultInputID = deviceManager.getDefaultInputDeviceIDRaw()

            if let outID = defaultOutputID, let inID = defaultInputID, outID == inID {
                AppLogger.warning(
                    "Skipping output mute: output device is the same as input device (muting would silence recording)",
                    category: .recordingManager,
                    extra: ["deviceID": outID, "deviceName": deviceManager.getDeviceName(for: outID) ?? "Unknown"]
                )
            } else {
                outputMuteSession = muteController.prepareOutputMuteSession()
            }
        }

        let settings = AppSettingsStore.shared
        let shouldBoostMicInputVolume = settings.autoIncreaseMicrophoneVolume
            && settings.useSystemDefaultInput
            && (source == .microphone || source == .all)
        if shouldBoostMicInputVolume {
            increaseDefaultMicrophoneInputVolumeIfPossible()
        }

        // 1. Check Microphone Permissions first if needed
        if source == .microphone || source == .all, AVCaptureDevice.authorizationStatus(for: .audio) != .authorized {
            AppLogger.error("Microphone permission denied. Cannot start recording.", category: .recordingManager)
            restoreOutputMuteIfNeeded()
            throw AudioRecorderError.permissionDenied
        }

        // 2. Prepare engine
        let engine = injectedEngine ?? AVAudioEngine()
        audioEngine = engine // Retain generic reference

        // 2.5 Validate Output HW Format early
        // AVAudioEngine is driven by the output device. If it has invalid format
        // (0 sample rate / 0 channels), the engine either fails (-10875) or runs
        // with a broken I/O cycle that delivers zero-filled input buffers.
        let outputFormat = engine.outputNode.outputFormat(forBus: 0)
        AppLogger.info(
            "Output node format",
            category: .recordingManager,
            extra: [
                "sampleRate": outputFormat.sampleRate,
                "channels": outputFormat.channelCount,
                "commonFormat": outputFormat.commonFormat.rawValue,
            ]
        )

        if outputFormat.sampleRate <= 0 || outputFormat.channelCount == 0 {
            AppLogger.fault(
                "Output device has invalid hardware format — audio capture will fail",
                category: .recordingManager,
                extra: [
                    "sampleRate": outputFormat.sampleRate,
                    "channels": outputFormat.channelCount,
                ]
            )
        }

        // 3. Determine Hardware Sample Rate
        // Use the input device's nominal sample rate when recording microphone audio.
        // Falling back to the output node rate can cause USB devices to enter a perpetual
        // "reconfig pending" loop when in/out rates differ, producing silence.
        let targetSampleRate = resolveTargetSampleRate(
            engine: engine,
            source: source
        )

        AppLogger.info("Resolved target sample rate: \(targetSampleRate)", category: .recordingManager)

        do {
            // For mic-only recordings, use AVAudioRecorder directly.
            // AVAudioEngine creates an internal aggregate device on macOS when input
            // and output devices differ, which can malfunction with USB microphones
            // (zero-filled buffers, reconfig loops). AVAudioRecorder uses a simple
            // I/O path without aggregate devices — proven to capture audio correctly.
            if source == .microphone {
                try await startSimpleMicRecording(to: outputURL)
                return
            }

            try await setupGraphAndStart(
                engine: engine,
                writingTo: outputURL,
                source: source,
                retryCount: retryCount,
                sampleRate: targetSampleRate
            )

            // Start ScreenCaptureKit after AVAudioEngine is stable.
            // This avoids a race where SCStream activation can transiently invalidate
            // output hardware format during engine initialization (-10875/-10877).
            if source == .system || source == .all {
                AppLogger.debug("Starting system recorder...", category: .recordingManager)
                try await systemRecorder.startRecording(to: outputURL, sampleRate: targetSampleRate)
            } else {
                AppLogger.debug("Skipping system recorder start (source: \(source.rawValue))", category: .recordingManager)
            }

            scheduleOutputMuteIfNeeded()
        } catch {
            await cleanupAfterFailedStart()
            if shouldRetryStartup(after: error, source: source, retryCount: retryCount) {
                let code = startupErrorCode(from: error) ?? 0
                AppLogger.warning(
                    "Retrying recording start after transient engine failure",
                    category: .recordingManager,
                    extra: ["code": code, "attempt": retryCount + 1, "max": Constants.maxRetries]
                )
                try await Task.sleep(nanoseconds: Constants.retryDelay)
                try await startRecording(to: outputURL, source: source, retryCount: retryCount + 1)
                return
            }
            throw error
        }
    }

    private func increaseDefaultMicrophoneInputVolumeIfPossible() {
        guard deviceManager.setDefaultInputVolumeToMaximum() else {
            AppLogger.debug(
                "Unable to set default microphone input volume to maximum (property not available or not settable).",
                category: .recordingManager
            )
            return
        }

        AppLogger.info(
            "Default microphone input volume set to maximum at recording start.",
            category: .recordingManager
        )
    }

    /// Resolves the target sample rate for the recording session.
    ///
    /// When recording microphone audio, the input device's native (nominal) sample rate
    /// is preferred. Using the output node rate instead can cause USB audio devices to
    /// enter a perpetual "reconfig pending" loop when in/out rates differ, producing silence.
    private func resolveTargetSampleRate(
        engine: AVAudioEngine,
        source: RecordingSource
    ) -> Double {
        // Try the input device's nominal sample rate first (most reliable for USB mics)
        if source.requiresMicrophonePermission,
           let inputUnit = engine.inputNode.audioUnit
        {
            var deviceID: AudioObjectID = 0
            var size = UInt32(MemoryLayout<AudioObjectID>.size)
            let status = AudioUnitGetProperty(
                inputUnit,
                kAudioOutputUnitProperty_CurrentDevice,
                kAudioUnitScope_Global,
                0,
                &deviceID,
                &size
            )

            if status == noErr, deviceID != AudioObjectID(kAudioObjectUnknown),
               let nominalRate = deviceManager.getDeviceNominalSampleRate(for: deviceID),
               nominalRate > 0
            {
                AppLogger.info(
                    "Using input device nominal sample rate",
                    category: .recordingManager,
                    extra: [
                        "deviceID": deviceID,
                        "deviceName": deviceManager.getDeviceName(for: deviceID) ?? "Unknown",
                        "nominalRate": nominalRate,
                    ]
                )
                return nominalRate
            }
        }

        // Fallback: engine output node (hardware output rate)
        let outputRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        if outputRate > 0 {
            AppLogger.info(
                "Falling back to output node sample rate",
                category: .recordingManager,
                extra: ["outputRate": outputRate]
            )
            return outputRate
        }

        // Last resort: default constant
        AppLogger.warning(
            "Using default sample rate constant as last resort",
            category: .recordingManager,
            extra: ["defaultRate": Constants.outputSampleRate]
        )
        return Constants.outputSampleRate
    }

    private func setupGraphAndStart(
        engine: AVAudioEngine,
        writingTo outputURL: URL,
        source: RecordingSource,
        retryCount: Int,
        sampleRate: Double
    ) async throws {
        AppLogger.debug("Setting up Audio Engine...", category: .recordingManager)

        let mixer = AVAudioMixerNode()
        engine.attach(mixer)

        mixerNode = mixer

        if source.requiresMicrophonePermission {
            // Only manually set the input device when the user has a custom device priority.
            // When useSystemDefaultInput is true, AVAudioEngine automatically creates the
            // correct aggregate device combining the system default input + output.
            // Calling AudioUnitSetProperty(kAudioOutputUnitProperty_CurrentDevice) on the
            // inputNode corrupts the engine's internal I/O unit, changing BOTH input and
            // output to the same device (e.g. USB mic with no speakers), breaking the
            // render cycle and producing zero-filled input buffers.
            if !AppSettingsStore.shared.useSystemDefaultInput {
                AppLogger.debug("Selecting preferred input device (custom priority)...", category: .recordingManager)
                await selectPreferredInputDevice(engine: engine)
            } else {
                AppLogger.debug("Using engine-managed default input device", category: .recordingManager)
            }
        }

        AppLogger.debug("Configuring inputs...", category: .recordingManager)
        try configureInputs(engine: engine, mixer: mixer, source: source, sampleRate: sampleRate)

        // Log current input device for debugging (read-only, no AudioUnitSetProperty)
        if let inputUnit = engine.inputNode.audioUnit {
            var deviceID: AudioObjectID = 0
            var size = UInt32(MemoryLayout<AudioObjectID>.size)
            let status = AudioUnitGetProperty(
                inputUnit,
                kAudioOutputUnitProperty_CurrentDevice,
                kAudioUnitScope_Global,
                0,
                &deviceID,
                &size
            )

            if status == noErr {
                let deviceName = deviceManager.getDeviceName(for: deviceID) ?? "Unknown"
                let usable = deviceManager.isUsableInputDeviceID(deviceID)
                AppLogger.info(
                    "Current input device after graph setup",
                    category: .recordingManager,
                    extra: ["deviceID": deviceID, "name": deviceName, "usable": usable]
                )
            }
        }

        AppLogger.debug("Configuring worker...", category: .recordingManager)
        try await configureWorker(writingTo: outputURL, mixer: mixer)

        // Increase maximum frames per slice to avoid kAudioUnitErr_TooManyFramesToProcess (-10874)
        // when hardware or drivers send buffers larger than the default 512 frames.
        // Using 2048 to reduce HALC overload risk while still handling most buffer sizes.
        let safeMaxFrames: AVAudioFrameCount = 2_048
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
        dumpAudioDiagnostics(engine: engine, source: source)
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
            // This should already be caught by the check in startRecording, but just in case:
            throw AudioRecorderError.permissionDenied
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
                "Microphone input format is not Float32 (\(inputFormat.commonFormat.rawValue)). Switching to conversion.",
                category: .recordingManager
            )
            // Instead of skipping, we should let AVAudioEngine handle it or log it clearly
            engine.connect(inputNode, to: mixer, format: inputFormat)
            return
        }

        AppLogger.debug("Connecting Microphone with format: \(inputFormat)", category: .recordingManager)
        engine.connect(inputNode, to: mixer, format: inputFormat)

        if Constants.micDiagnosticsEnabled {
            startMicDiagnostics(for: inputNode)
        }
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
                try await Task.sleep(nanoseconds: Constants.engineStartTimeout)
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

    // MARK: - Simple Mic Recording (AVAudioRecorder)

    /// Start a mic-only recording using AVAudioRecorder directly.
    /// This bypasses AVAudioEngine and avoids the internal aggregate device
    /// that malfunctions on macOS with USB microphones.
    private func startSimpleMicRecording(to outputURL: URL) async throws {
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]

        let recorder = try AVAudioRecorder(url: outputURL, settings: settings)
        recorder.isMeteringEnabled = true

        guard recorder.record() else {
            throw AudioRecorderError.failedToStartEngine(NSError(
                domain: "AudioRecorder",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "AVAudioRecorder failed to start"]
            ))
        }

        simpleRecorder = recorder
        currentRecordingURL = outputURL
        isRecording = true

        // Periodic metering for UI power updates
        simpleMeterTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let rec = simpleRecorder else { return }
            rec.updateMeters()
            currentAveragePower = rec.averagePower(forChannel: 0)
            currentPeakPower = rec.peakPower(forChannel: 0)
        }

        AppLogger.info(
            "Simple mic recording started (AVAudioRecorder)",
            category: .recordingManager,
            extra: ["path": outputURL.path]
        )
    }

    private func stopSimpleMicRecording() -> URL? {
        simpleMeterTimer?.invalidate()
        simpleMeterTimer = nil

        guard let recorder = simpleRecorder else { return nil }
        simpleRecorder = nil

        recorder.stop()

        let url = recorder.url
        AppLogger.info(
            "Simple mic recording stopped",
            category: .recordingManager,
            extra: ["path": url.path, "duration": recorder.currentTime]
        )
        return url
    }

    /// Stop recording and finalize the audio file.
    @discardableResult
    public func stopRecording() async -> URL? {
        guard isRecording else {
            if hasPendingStartupResources {
                await cleanupAfterFailedStart()
            }
            return currentRecordingURL
        }

        AppLogger.info("Stopping recording...", category: .recordingManager)

        // Cancel validation timer
        validationTimer?.invalidate()
        validationTimer = nil

        if simpleRecorder != nil {
            _ = stopSimpleMicRecording()
            restoreOutputMuteIfNeeded()
            isRecording = false
            currentAveragePower = -160.0
            currentPeakPower = -160.0
            return currentRecordingURL
        }

        if let recorder = fallbackRecorder {
            stopFallbackRecorder(recorder)
            restoreOutputMuteIfNeeded()
            isRecording = false
            currentAveragePower = -160.0
            currentPeakPower = -160.0
            return currentRecordingURL
        }

        // Stop Engine & System Capture
        _ = await systemRecorder.stopRecording()
        cleanupEngine()

        // Restore audio output if we muted it
        restoreOutputMuteIfNeeded()

        // Finalize worker - wait for all buffers to be processed
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

    private func restoreOutputMuteIfNeeded() {
        outputMuteTask?.cancel()
        outputMuteTask = nil

        guard let session = outputMuteSession else { return }
        outputMuteSession = nil
        muteController.restoreOutputState(from: session)
    }

    private func resetOutputMuteState() {
        outputMuteTask?.cancel()
        outputMuteTask = nil
        outputMuteSession = nil
    }

    private func scheduleOutputMuteIfNeeded() {
        guard outputMuteSession != nil else { return }

        outputMuteTask?.cancel()
        outputMuteTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: Constants.outputMuteDelayAfterStart)
            guard let self, isRecording else { return }
            guard var session = outputMuteSession else { return }

            do {
                try muteController.applyMute(to: &session)
                outputMuteSession = session
            } catch {
                AppLogger.warning(
                    "Failed to mute system audio output",
                    category: .recordingManager,
                    extra: ["error": error.localizedDescription]
                )
            }
        }
    }

    private func cleanupEngine() {
        if let mixer = mixerNode {
            mixer.removeTap(onBus: 0)
        }

        mixerNode = nil
        systemAudioSourceNode = nil

        if let engine = audioEngine {
            stopMicDiagnostics(for: engine.inputNode)
            if engine.isRunning {
                engine.stop()
            }
            engine.reset()

            audioEngine = nil
        }
    }

    private var hasPendingStartupResources: Bool {
        audioEngine != nil
            || mixerNode != nil
            || systemAudioSourceNode != nil
            || currentRecordingURL != nil
            || fallbackRecorder != nil
    }

    private func cleanupAfterFailedStart() async {
        validationTimer?.invalidate()
        validationTimer = nil

        if let recorder = fallbackRecorder {
            stopFallbackRecorder(recorder)
        }

        _ = await systemRecorder.stopRecording()
        cleanupEngine()
        _ = await worker.stop()
        systemAudioQueue.clear()
        partialBufferState.clear()

        restoreOutputMuteIfNeeded()
        isRecording = false
        currentRecordingURL = nil
        currentAveragePower = -160.0
        currentPeakPower = -160.0
    }

    private func startupErrorCode(from error: Error) -> Int? {
        if case let AudioRecorderError.failedToStartEngine(innerError) = error {
            return (innerError as NSError).code
        }

        return (error as NSError).code
    }

    private func shouldRetryStartup(after error: Error, source _: RecordingSource, retryCount: Int) -> Bool {
        guard retryCount < Constants.maxRetries else { return false }
        guard let code = startupErrorCode(from: error) else { return false }
        return Constants.retriableEngineStartErrorCodes.contains(code)
    }

    func startFallbackRecorder(to outputURL: URL) throws {
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: Constants.fallbackSampleRate,
            AVNumberOfChannelsKey: Constants.fallbackChannels,
            AVEncoderBitRateKey: Constants.fallbackBitRate,
        ]

        let recorder = try AVAudioRecorder(url: outputURL, settings: settings)
        recorder.isMeteringEnabled = true
        recorder.record()
        fallbackRecorder = recorder
        isRecording = true

        fallbackMeterTimer?.invalidate()
        fallbackMeterTimer = Timer.scheduledTimer(withTimeInterval: Constants.fallbackMeterUpdateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateFallbackMeters()
            }
        }
        fallbackMeterTimer?.tolerance = Constants.fallbackMeterUpdateInterval * Constants.fallbackMeterTimerToleranceRatio

        AppLogger.info("Fallback mic recorder started", category: .recordingManager, extra: ["path": outputURL.path])
    }

    private func stopFallbackRecorder(_ recorder: AVAudioRecorder) {
        fallbackMeterTimer?.invalidate()
        fallbackMeterTimer = nil

        recorder.stop()
        fallbackRecorder = nil

        AppLogger.info("Fallback mic recorder stopped", category: .recordingManager, extra: ["path": recorder.url.path])
    }

    @MainActor
    private func updateFallbackMeters() {
        guard let recorder = fallbackRecorder else { return }
        recorder.updateMeters()
        currentAveragePower = recorder.averagePower(forChannel: 0)
        currentPeakPower = recorder.peakPower(forChannel: 0)
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

    // MARK: - Private Helpers (Issue #35)

    private func selectPreferredInputDevice(engine: AVAudioEngine) async {
        let inputNode = engine.inputNode
        guard let inputUnit = inputNode.audioUnit else {
            AppLogger.warning("Failed to resolve input audio unit for device selection", category: .recordingManager)
            return
        }

        if AppSettingsStore.shared.useSystemDefaultInput {
            let resolvedDeviceID: AudioObjectID
            if let defaultDeviceID = deviceManager.getDefaultInputDeviceID() {
                resolvedDeviceID = defaultDeviceID
            } else if let rawDeviceID = deviceManager.getDefaultInputDeviceIDRaw() {
                // Fallback: use raw device ID without usability validation.
                // This prevents silent failures when isUsableInputDeviceID is too strict.
                AppLogger.warning(
                    "Validated default input device unavailable; falling back to raw system default",
                    category: .recordingManager,
                    extra: ["rawDeviceID": rawDeviceID]
                )
                resolvedDeviceID = rawDeviceID
            } else {
                AppLogger.fault(
                    "No system default input device found at all — microphone capture will produce silence",
                    category: .recordingManager
                )
                return
            }

            var deviceIDToSet = resolvedDeviceID
            let size = UInt32(MemoryLayout<AudioObjectID>.size)
            let status = AudioUnitSetProperty(
                inputUnit,
                kAudioOutputUnitProperty_CurrentDevice,
                kAudioUnitScope_Global,
                0,
                &deviceIDToSet,
                size
            )

            if status != noErr {
                AppLogger.warning(
                    "Failed to set system default input device",
                    category: .recordingManager,
                    extra: ["status": status, "deviceID": resolvedDeviceID]
                )
            } else {
                AppLogger.info(
                    "Using system default input device",
                    category: .recordingManager,
                    extra: ["deviceID": resolvedDeviceID]
                )
            }
            logDeviceDiagnostics(for: resolvedDeviceID, label: "systemDefault")
            return
        }
        let priorityList = AppSettingsStore.shared.audioDevicePriority
        guard !priorityList.isEmpty else { return }

        // Find the first available device from the priority list
        var deviceID: AudioObjectID?
        for uid in priorityList {
            if let id = deviceManager.getAudioDeviceID(for: uid), deviceManager.isUsableInputDeviceID(id) {
                deviceID = id
                break
            }
        }

        guard let id = deviceID else {
            AppLogger.debug("No preferred input device from priority list is available. Using system default.", category: .recordingManager)
            return
        }

        // Apply device to the input node
        var deviceIDToSet = id
        let size = UInt32(MemoryLayout<AudioObjectID>.size)

        let status = AudioUnitSetProperty(
            inputUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceIDToSet,
            size
        )

        if status != noErr {
            AppLogger.warning("Failed to set preferred input device", category: .recordingManager, extra: ["status": status, "deviceID": id])
            applySystemDefaultInputDevice(to: inputUnit, reason: "priority_device_set_failed")
        } else {
            AppLogger.info("Set preferred input device", category: .recordingManager, extra: ["deviceID": id])
        }
        logDeviceDiagnostics(for: id, label: "priority")
    }

    private func applySystemDefaultInputDevice(to inputUnit: AudioUnit, reason: String) {
        guard let defaultDeviceID = deviceManager.getDefaultInputDeviceID() else {
            AppLogger.warning(
                "Fallback to system default input device failed: no valid default device",
                category: .recordingManager,
                extra: ["reason": reason]
            )
            return
        }

        var deviceIDToSet = defaultDeviceID
        let size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioUnitSetProperty(
            inputUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceIDToSet,
            size
        )

        if status == noErr {
            AppLogger.info(
                "Applied fallback to system default input device",
                category: .recordingManager,
                extra: ["reason": reason, "deviceID": defaultDeviceID]
            )
            logDeviceDiagnostics(for: defaultDeviceID, label: "fallbackSystemDefault")
        } else {
            AppLogger.warning(
                "Failed to apply fallback system default input device",
                category: .recordingManager,
                extra: ["reason": reason, "status": status, "deviceID": defaultDeviceID]
            )
        }
    }

    /// Restore the output device to the system default output after input device selection.
    ///
    /// `selectPreferredInputDevice` uses `kAudioOutputUnitProperty_CurrentDevice` which
    /// changes the device for the entire I/O unit (including output). This can redirect
    /// audio output to a USB microphone that has no speakers, breaking the engine's
    /// render cycle and producing zero-filled input buffers.
    private func restoreOutputDevice(engine: AVAudioEngine) {
        guard let outputUnit = engine.outputNode.audioUnit else { return }

        guard let defaultOutputID = deviceManager.getDefaultOutputDeviceID() else {
            AppLogger.warning(
                "No system default output device found; cannot restore output device",
                category: .recordingManager
            )
            return
        }

        // Check if output is already correct
        var currentOutputID: AudioObjectID = 0
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let getStatus = AudioUnitGetProperty(
            outputUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &currentOutputID,
            &size
        )

        if getStatus == noErr, currentOutputID == defaultOutputID {
            return // Output device is already the system default
        }

        // Restore to system default output
        var deviceIDToSet = defaultOutputID
        let setStatus = AudioUnitSetProperty(
            outputUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceIDToSet,
            size
        )

        let deviceName = deviceManager.getDeviceName(for: defaultOutputID) ?? "Unknown"
        if setStatus == noErr {
            AppLogger.info(
                "Restored output device to system default",
                category: .recordingManager,
                extra: [
                    "outputDeviceID": defaultOutputID,
                    "outputDeviceName": deviceName,
                    "previousOutputDeviceID": currentOutputID,
                ]
            )
        } else {
            AppLogger.warning(
                "Failed to restore output device to system default",
                category: .recordingManager,
                extra: ["status": setStatus, "targetDeviceID": defaultOutputID]
            )
        }
    }

    // MARK: - Audio Diagnostics

    private func dumpAudioDiagnostics(engine: AVAudioEngine, source: RecordingSource) {
        let inputNode = engine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: Constants.tapBusNumber)

        var diagnostics: [String: Any] = [
            "engineRunning": engine.isRunning,
            "source": source.rawValue,
            "inputSampleRate": inputFormat.sampleRate,
            "inputChannels": inputFormat.channelCount,
            "inputCommonFormat": inputFormat.commonFormat.rawValue,
        ]

        // Resolve input device identity from audio unit
        if let inputUnit = inputNode.audioUnit {
            var deviceID: AudioObjectID = 0
            var size = UInt32(MemoryLayout<AudioObjectID>.size)
            let status = AudioUnitGetProperty(
                inputUnit,
                kAudioOutputUnitProperty_CurrentDevice,
                kAudioUnitScope_Global,
                0,
                &deviceID,
                &size
            )

            if status == noErr {
                diagnostics["inputDeviceID"] = deviceID
                diagnostics["inputDeviceName"] = deviceManager.getDeviceName(for: deviceID) ?? "Unknown"
                diagnostics["inputDeviceUID"] = deviceManager.getDeviceUID(for: deviceID) ?? "Unknown"
                diagnostics["inputDeviceVolume"] = deviceManager.getInputVolume(for: deviceID) as Any
                diagnostics["inputDeviceMuted"] = deviceManager.getInputMute(for: deviceID) as Any
                diagnostics["inputDeviceChannels"] = deviceManager.getInputChannelCount(for: deviceID) as Any
                diagnostics["inputDeviceUsable"] = deviceManager.isUsableInputDeviceID(deviceID)
            } else {
                diagnostics["inputDeviceError"] = "Failed to query (status: \(status))"
            }
        } else {
            diagnostics["inputUnit"] = "nil"
        }

        // System default device for comparison
        if let defaultID = deviceManager.getDefaultInputDeviceIDRaw() {
            diagnostics["systemDefaultDeviceID"] = defaultID
            diagnostics["systemDefaultDeviceName"] = deviceManager.getDeviceName(for: defaultID) ?? "Unknown"
        }

        // Output device info (critical — engine is driven by the output device)
        let outputFormat = engine.outputNode.outputFormat(forBus: 0)
        diagnostics["outputSampleRate"] = outputFormat.sampleRate
        diagnostics["outputChannels"] = outputFormat.channelCount

        if let outputUnit = engine.outputNode.audioUnit {
            var outputDeviceID: AudioObjectID = 0
            var outSize = UInt32(MemoryLayout<AudioObjectID>.size)
            let outStatus = AudioUnitGetProperty(
                outputUnit,
                kAudioOutputUnitProperty_CurrentDevice,
                kAudioUnitScope_Global,
                0,
                &outputDeviceID,
                &outSize
            )
            if outStatus == noErr {
                diagnostics["outputDeviceID"] = outputDeviceID
                diagnostics["outputDeviceName"] = deviceManager.getDeviceName(for: outputDeviceID) ?? "Unknown"
                if let nominalRate = deviceManager.getDeviceNominalSampleRate(for: outputDeviceID) {
                    diagnostics["outputDeviceNominalRate"] = nominalRate
                }
            }
        }

        AppLogger.info(
            "Recording audio diagnostic dump",
            category: .recordingManager,
            extra: diagnostics
        )
    }
}
