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
    @Published public internal(set) var currentBarPowerLevels: [Float] = []

    // MARK: - Audio Engine

    var audioEngine: AVAudioEngine?
    var mixerNode: AVAudioMixerNode?
    var systemAudioSourceNode: AVAudioSourceNode?
    var microphoneMixingDestination: AVAudioMixingDestination?

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
    let microphoneInputSelectionResolver: MicrophoneInputSelectionResolver
    var micDiagnosticsTimer: Timer?
    var isMicDiagnosticsTapInstalled = false
    let micDiagnosticsPeakBits = ManagedAtomic<UInt32>(0)
    var micProbeWorker: AudioRecordingWorker?
    var micProbeStopTask: Task<Void, Never>?
    var micRecorderProbe: AVAudioRecorder?
    var micRecorderProbeStopTask: Task<Void, Never>?
    private var fallbackRecorder: AVAudioRecorder?
    private var fallbackMeterTimer: Timer?
    private var settingsSubscriptions = Set<AnyCancellable>()

    init() {
        microphoneInputSelectionResolver = MicrophoneInputSelectionResolver(deviceManager: deviceManager)

        // Setup worker callbacks to bridge back to MainActor
        worker.setOnPowerUpdate { [weak self] avg, peak, barPowerLevels in
            Task { @MainActor [weak self] in
                self?.currentAveragePower = avg
                self?.currentPeakPower = peak
                self?.currentBarPowerLevels = barPowerLevels
            }
        }

        worker.setOnError { [weak self] error in
            Task { @MainActor [weak self] in
                self?.handleWorkerError(error)
            }
        }

        AppSettingsStore.shared.$recordingIndicatorStyle
            .removeDuplicates()
            .sink { [weak self] style in
                self?.worker.setMeteringBarCount(Self.waveformBarCount(for: style))
            }
            .store(in: &settingsSubscriptions)

        worker.setMeteringBarCount(Self.waveformBarCount(for: AppSettingsStore.shared.recordingIndicatorStyle))

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
        currentBarPowerLevels = []

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
        setMeetingMicrophoneEnabled(true)
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
                scheduleOutputMuteIfNeeded()
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

    public func setMeetingMicrophoneEnabled(_ isEnabled: Bool) {
        microphoneMixingDestination?.volume = isEnabled ? 1.0 : 0.0
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
            Task { @MainActor [weak self] in
                guard let self, let rec = simpleRecorder else { return }
                rec.updateMeters()
                currentAveragePower = rec.averagePower(forChannel: 0)
                currentPeakPower = rec.peakPower(forChannel: 0)
                currentBarPowerLevels = [currentAveragePower]
            }
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
            currentBarPowerLevels = []
            return currentRecordingURL
        }

        if let recorder = fallbackRecorder {
            stopFallbackRecorder(recorder)
            restoreOutputMuteIfNeeded()
            isRecording = false
            currentAveragePower = -160.0
            currentPeakPower = -160.0
            currentBarPowerLevels = []
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
        currentBarPowerLevels = []

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
            applyOutputMuteIfNeeded()
        }
    }

    private func applyOutputMuteIfNeeded() {
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

    private func cleanupEngine() {
        if let mixer = mixerNode {
            mixer.removeTap(onBus: 0)
        }

        mixerNode = nil
        systemAudioSourceNode = nil
        microphoneMixingDestination = nil

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
        currentBarPowerLevels = []
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
        currentBarPowerLevels = [currentAveragePower]
    }

    private static func waveformBarCount(for style: RecordingIndicatorStyle) -> Int {
        switch style {
        case .classic:
            18
        case .mini:
            9
        case .none:
            0
        }
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

}
