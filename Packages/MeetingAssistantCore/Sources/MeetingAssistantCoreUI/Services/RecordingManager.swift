import AVFoundation
import Combine
import Foundation
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import os.log
import UserNotifications

/// Central manager coordinating recording, meeting detection, and transcription.
/// Orchestrates microphone and system audio recording with post-processing merge.
@MainActor
public class RecordingManager: ObservableObject, RecordingServiceProtocol {
    public static let shared = RecordingManager()

    // MARK: - Recording Actor

    private let recordingActor = RecordingActor()

    // MARK: - Input Device

    private let audioDeviceManager = AudioDeviceManager()

    // MARK: - Published State

    @Published public private(set) var isRecording = false
    @Published public private(set) var isStartingRecording = false
    @Published public private(set) var isTranscribing = false
    @Published public private(set) var meetingState: MeetingState = .idle
    @Published public private(set) var currentMeeting: Meeting?
    @Published public private(set) var lastError: Error?
    @Published public private(set) var hasRequiredPermissions = false
    @Published public private(set) var recordingSource: RecordingSource = .microphone
    @Published public private(set) var dictationSessionOutputLanguageOverride: DictationOutputLanguage?

    // MARK: - Protocol Publishers

    public var meetingStatePublisher: AnyPublisher<MeetingState, Never> {
        $meetingState.eraseToAnyPublisher()
    }

    public var isRecordingPublisher: AnyPublisher<Bool, Never> {
        $isRecording.eraseToAnyPublisher()
    }

    public var isTranscribingPublisher: AnyPublisher<Bool, Never> {
        $isTranscribing.eraseToAnyPublisher()
    }

    public var isStartingPublisher: AnyPublisher<Bool, Never> {
        $isStartingRecording.eraseToAnyPublisher()
    }

    public var currentMeetingPublisher: AnyPublisher<Meeting?, Never> {
        $currentMeeting.eraseToAnyPublisher()
    }

    /// Detailed transcription service status for UI feedback.
    public let transcriptionStatus = TranscriptionStatus()

    /// Individual permission status tracking for UI display.
    public let permissionStatus = PermissionStatusManager()

    // MARK: - Services

    private let micRecorder: any AudioRecordingService
    private let systemRecorder: any AudioRecordingService
    private let audioMerger: AudioMerger
    private let meetingDetector: MeetingDetector
    private let transcriptionClient: any TranscriptionService
    private let postProcessingService: any PostProcessingServiceProtocol
    private let storage: any StorageService
    private let notificationService: NotificationService
    private let contextAwarenessService: any ContextAwarenessServiceProtocol
    private let textContextProvider: any TextContextProvider
    private let textContextGuardrails: TextContextGuardrails
    private let textContextPolicy: TextContextPolicy
    private let transcribeAudioUseCase: TranscribeAudioUseCase
    private let transcriptPreprocessor = TranscriptIntelligencePreprocessor()
    private let activeAppContextProvider: any ActiveAppContextProvider
    private var browserProviders: [String: BrowserActiveTabURLProviding] = BrowserProviderRegistry.defaultProviders()

    private var cancellables = Set<AnyCancellable>()
    private var statusCheckTask: Task<Void, Never>?
    private var isStartOperationInFlight = false
    private var postStartContextCaptureTask: Task<Void, Never>?
    private var activeStartTelemetry: RecordingStartTelemetry?
    private var postProcessingContext: String?
    private var postProcessingContextItems: [TranscriptionContextItem] = []
    private var dictationStartBundleIdentifier: String?
    private var dictationStartURL: URL?

    private struct RecordingStartTelemetry {
        let traceID = UUID().uuidString
        let triggerLabel: String
        let source: RecordingSource
        let requestedAt: Date
        let managerEntryAt: Date
        var recorderStartedAt: Date?
        var indicatorShownAt: Date?
    }

    // MARK: - Computed Properties for Actor State

    private func getMicAudioURL() async -> URL? {
        await recordingActor.micAudioURLState
    }

    private func getSystemAudioURL() async -> URL? {
        await recordingActor.systemAudioURLState
    }

    private func getMergedAudioURL() async -> URL? {
        await recordingActor.mergedAudioURLState
    }

    private func setMicAudioURL(_ url: URL?) {
        Task { await self.recordingActor.setMicAudioURL(url) }
    }

    private func setSystemAudioURL(_ url: URL?) {
        Task { await self.recordingActor.setSystemAudioURL(url) }
    }

    private func setMergedAudioURL(_ url: URL?) {
        Task { await self.recordingActor.setMergedAudioURL(url) }
    }

    // MARK: - Storage

    public init(
        micRecorder: any AudioRecordingService = AudioRecorder.shared,
        systemRecorder: any AudioRecordingService = SystemAudioRecorder.shared,
        transcriptionClient: any TranscriptionService = TranscriptionClient.shared,
        postProcessingService: any PostProcessingServiceProtocol = PostProcessingService.shared,
        audioMerger: AudioMerger = AudioMerger(),
        meetingDetector: MeetingDetector = MeetingDetector.shared,
        storage: any StorageService = FileSystemStorageService.shared,
        notificationService: NotificationService = .shared,
        contextAwarenessService: any ContextAwarenessServiceProtocol = ContextAwarenessService.shared,
        textContextProvider: any TextContextProvider = AXTextContextProvider(
            exclusionPolicyProvider: {
                let settings = AppSettingsStore.shared
                return settings.contextAwarenessProtectSensitiveApps
                    ? TextContextExclusionPolicy()
                    : TextContextExclusionPolicy(baseExcludedBundleIDs: [])
            },
            customExcludedBundleIDsProvider: {
                let settings = AppSettingsStore.shared
                return settings.contextAwarenessProtectSensitiveApps
                    ? settings.contextAwarenessExcludedBundleIDs
                    : []
            }
        ),
        textContextGuardrails: TextContextGuardrails = TextContextGuardrails(),
        textContextPolicy: TextContextPolicy = .default,
        activeAppContextProvider: any ActiveAppContextProvider = NSWorkspaceActiveAppContextProvider()
    ) {
        self.micRecorder = micRecorder
        self.systemRecorder = systemRecorder
        self.transcriptionClient = transcriptionClient
        self.postProcessingService = postProcessingService
        self.audioMerger = audioMerger
        self.meetingDetector = meetingDetector
        self.storage = storage
        self.notificationService = notificationService
        self.contextAwarenessService = contextAwarenessService
        self.textContextProvider = textContextProvider
        self.textContextGuardrails = textContextGuardrails
        self.textContextPolicy = textContextPolicy
        self.activeAppContextProvider = activeAppContextProvider

        // Initialize UseCase with Adapters
        transcribeAudioUseCase = TranscribeAudioUseCase(
            transcriptionRepository: TranscriptionRepositoryAdapter(transcriptionService: transcriptionClient),
            transcriptionStorageRepository: CoreDataTranscriptionStorageRepository(stack: .shared),
            postProcessingRepository: PostProcessingRepositoryAdapter(postProcessingService: postProcessingService)
        )

        setupBindings()
        if isRunningAsAppBundle {
            meetingDetector.startMonitoring()
        }
        notificationService.requestAuthorization()
        Task { @Sendable [weak self] in
            await self?.checkPermission()
            if self?.isRunningAsAppBundle == true {
                await self?.startStatusMonitoring()
            }
            await self?.syncStateFromActor()
        }
    }

    deinit {
        AppLogger.debug("RecordingManager deinitialized", category: .recordingManager)
    }

    /// Sync local state from the recording actor (used on initialization).
    private func syncStateFromActor() async {
        isRecording = await recordingActor.recordingState
        isTranscribing = await recordingActor.transcribingState
        currentMeeting = await recordingActor.currentMeetingState
        lastError = await recordingActor.lastErrorState
        hasRequiredPermissions = await recordingActor.permissionsState
    }

    /// Check if running as a proper app bundle (required for UNUserNotificationCenter).
    private var isRunningAsAppBundle: Bool {
        guard let bundleId = Bundle.main.bundleIdentifier else { return false }
        return !bundleId.lowercased().contains("xctest")
    }

}

public extension RecordingManager {

    func checkPermission() async {
        await checkPermission(for: recordingSource)
    }

    func checkPermission(for source: RecordingSource) async {
        let micPermission = await micRecorder.hasPermission()
        let screenPermission = await systemRecorder.hasPermission()
        let accessibilityState = AccessibilityPermissionService.currentState()

        // Update individual permission states using detailed state methods
        let micState = micRecorder.getPermissionState()
        let screenState = systemRecorder.getPermissionState()

        permissionStatus.updateMicrophoneState(micState)
        permissionStatus.updateScreenRecordingState(screenState)
        permissionStatus.updateAccessibilityState(accessibilityState)

        let hasPermissions = source.requiredPermissionsGranted(
            microphone: micPermission,
            screenRecording: screenPermission
        )

        await recordingActor.setPermissions(hasPermissions)
        hasRequiredPermissions = await recordingActor.permissionsState
    }

    /// Request permissions required for the provided source.
    func requestPermission() async {
        await requestPermission(for: recordingSource)
    }

    func requestPermission(for source: RecordingSource) async {
        if source.requiresMicrophonePermission {
            await micRecorder.requestPermission()
        }
        if source.requiresScreenRecordingPermission {
            await systemRecorder.requestPermission()
        }
        await checkPermission(for: source)
    }

    /// Open System Preferences to Screen Recording settings.
    func openPermissionSettings() {
        systemRecorder.openSettings()
    }

    /// Open System Preferences to Microphone settings.
    func openMicrophoneSettings() {
        micRecorder.openSettings()
    }

    func requestAccessibilityPermission() {
        AccessibilityPermissionService.requestPermission()
        permissionStatus.updateAccessibilityState(AccessibilityPermissionService.currentState())
    }

    func openAccessibilitySettings() {
        AccessibilityPermissionService.openSystemSettings()
    }

    // MARK: - Public API

    /// Start recording audio for a meeting.
    /// - Parameters:
    ///   - source: The audio source to record.
    func startRecording(source: RecordingSource = .microphone) async {
        await startRecording(
            source: source,
            requestedAt: Date(),
            triggerLabel: "recording.start.default"
        )
    }

    func startRecording(
        source: RecordingSource,
        requestedAt: Date,
        triggerLabel: String
    ) async {
        guard !isRecording else {
            AppLogger.info("Attempted to start recording but already recording", category: .recordingManager)
            return
        }

        guard await RecordingExclusivityCoordinator.shared.beginRecording() else {
            AppLogger.info("Recording start blocked by exclusivity coordinator", category: .recordingManager)
            return
        }

        recordingSource = source
        dictationSessionOutputLanguageOverride = nil

        // Prevent re-entrancy during async setup
        guard !isStartOperationInFlight else { return }
        isStartOperationInFlight = true
        defer { isStartOperationInFlight = false }

        let managerEntryAt = Date()
        activeStartTelemetry = RecordingStartTelemetry(
            triggerLabel: triggerLabel,
            source: source,
            requestedAt: requestedAt,
            managerEntryAt: managerEntryAt
        )
        isStartingRecording = true
        await Task.yield()
        SoundFeedbackService.shared.playRecordingStartSound()
        await Task.yield()

        do {
            let meeting = createMeeting(type: resolveMeetingType())
            dictationStartBundleIdentifier = nil
            dictationStartURL = nil
            currentMeeting = meeting
            postProcessingContext = nil
            postProcessingContextItems = []

            // We only need one output URL because AudioRecorder handles mixing
            let audioURL = storage.createRecordingURL(for: meeting, type: .merged)
            setMergedAudioURL(audioURL)
            let outputURL = audioURL
            try await startRecorder(to: outputURL, source: source)

            let recorderStartAt = Date()
            markRecorderStartedAt(recorderStartAt)

            isRecording = true
            isStartingRecording = false
            meetingState = .recording // Sync state
            currentMeeting?.state = .recording // Sync entity state
            currentMeeting?.audioFilePath = outputURL.path

            startContextCaptureAfterRecordingStart(meetingID: meeting.id, source: source)

            AppLogger.info("Recording started successfully", category: .recordingManager, extra: [
                "app": meeting.appName,
                "url": outputURL.lastPathComponent,
                "source": source.rawValue,
            ])

        } catch {
            isStartingRecording = false
            await RecordingExclusivityCoordinator.shared.endRecording()
            postStartContextCaptureTask?.cancel()
            postStartContextCaptureTask = nil
            postProcessingContext = nil
            postProcessingContextItems = []
            activeStartTelemetry = nil
            await handleStartRecordingError(error)
        }
    }

    func noteIndicatorShownForStartIfNeeded() {
        guard var telemetry = activeStartTelemetry else { return }
        guard telemetry.indicatorShownAt == nil else { return }

        let now = Date()
        telemetry.indicatorShownAt = now
        activeStartTelemetry = telemetry

        let requestedToIndicatorMs = now.timeIntervalSince(telemetry.requestedAt) * 1000
        PerformanceMonitor.shared.reportMetric(
            name: "recording_start_requested_to_indicator_ms",
            value: requestedToIndicatorMs,
            unit: "ms"
        )

        if let recorderStartedAt = telemetry.recorderStartedAt {
            let recorderToIndicatorMs = now.timeIntervalSince(recorderStartedAt) * 1000
            PerformanceMonitor.shared.reportMetric(
                name: "recording_start_recorder_to_indicator_ms",
                value: recorderToIndicatorMs,
                unit: "ms"
            )
        }

        AppLogger.debug(
            "Recording startup indicator is visible",
            category: .performance,
            extra: [
                "trace": telemetry.traceID,
                "trigger": telemetry.triggerLabel,
                "source": telemetry.source.rawValue,
            ]
        )
    }

    private func resolveMeetingType() -> MeetingType {
        let settings = AppSettingsStore.shared
        return settings.meetingTypeAutoDetectEnabled ? .autodetect : .general
    }

    func overrideCurrentMeetingType(_ type: MeetingType) {
        guard isRecording, var meeting = currentMeeting else { return }
        meeting.type = type
        currentMeeting = meeting
    }

    private func startRecorder(to url: URL, source: RecordingSource) async throws {
        // Start recorder with source preference
        // We assume micRecorder is capable of handling the source logic (AudioRecorder)
        AppLogger.debug(
            "Starting recorder",
            category: .recordingManager,
            extra: ["url": url.path, "source": source.rawValue]
        )

        // Use specific overload if available, or fallback
        if let recorder = micRecorder as? AudioRecorder {
            try await recorder.startRecording(to: url, source: source, retryCount: 0)
        } else {
            // Fallback for mocks or generic services
            try await micRecorder.startRecording(to: url, retryCount: 0)
        }
    }

    private func createMeeting(type: MeetingType) -> Meeting {
        let app = meetingDetector.detectedMeeting ?? .unknown
        return Meeting(app: app, type: type, state: .recording)
    }

    private func applyStartAppContext(
        _ meeting: Meeting,
        source: RecordingSource,
        activeContext: ActiveAppContext?
    ) -> Meeting {
        let resolvedApp: MeetingApp = source == .microphone ? .unknown : meeting.app
        let appBundleIdentifier = activeContext?.bundleIdentifier
        let trimmedName = activeContext?.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let appDisplayName = (trimmedName?.isEmpty == false) ? trimmedName : nil

        return Meeting(
            id: meeting.id,
            app: resolvedApp,
            appBundleIdentifier: appBundleIdentifier,
            appDisplayName: appDisplayName,
            type: meeting.type,
            state: meeting.state,
            startTime: meeting.startTime,
            endTime: meeting.endTime,
            audioFilePath: meeting.audioFilePath
        )
    }

    private func generateRecordingPaths(for meeting: Meeting) async throws -> (URL, URL) {
        setMicAudioURL(storage.createRecordingURL(for: meeting, type: .microphone))
        setSystemAudioURL(storage.createRecordingURL(for: meeting, type: .system))
        setMergedAudioURL(storage.createRecordingURL(for: meeting, type: .merged))

        guard let micURL = await getMicAudioURL(), let systemURL = await getSystemAudioURL() else {
            throw RecordingManagerError.noOutputPath
        }
        return (micURL, systemURL)
    }

    private func startRecorders(micURL: URL, systemURL: URL) async throws {
        // Start microphone recording
        AppLogger.debug("Starting microphone recording", category: .recordingManager, extra: ["url": micURL.path])
        try await micRecorder.startRecording(to: micURL, retryCount: 0)

        // Start system audio recording
        AppLogger.debug("Starting system audio recording", category: .recordingManager, extra: ["url": systemURL.path])
        try await systemRecorder.startRecording(to: systemURL, retryCount: 0)
    }

    private func handleStartRecordingError(_ error: Error) async {
        AppLogger.fault(
            "CRITICAL: Failed to start recording",
            category: .recordingManager,
            error: error,
            extra: ["state": "start_failed"]
        )
        isStartingRecording = false
        lastError = error
        postStartContextCaptureTask?.cancel()
        postStartContextCaptureTask = nil

        // Cleanup partial starts
        _ = await micRecorder.stopRecording()
        _ = await systemRecorder.stopRecording()

        currentMeeting = nil
        activeStartTelemetry = nil
    }

    /// Stop recording and optionally transcribe.
    func stopRecording() async {
        await stopRecording(transcribe: true)
    }

    func stopRecording(transcribe: Bool = true) async {
        guard isRecording else {
            AppLogger.info("Attempted to stop recording but not recording", category: .recordingManager)
            return
        }

        postStartContextCaptureTask?.cancel()
        postStartContextCaptureTask = nil
        isStartingRecording = false

        do {
            // Stop both recorders
            let micURL = await micRecorder.stopRecording()
            let sysURL = await systemRecorder.stopRecording()

            // Update meeting
            currentMeeting?.endTime = Date()

            // Issue #2: Start transcribing state BEFORE stopping recording state
            // to prevent the UI from hiding the indicator during audio merging gap.
            if transcribe {
                isTranscribing = true
                meetingState = .processing(.transcribing) // Sync state
                currentMeeting?.state = .processing(.transcribing) // Sync entity state
            } else {
                meetingState = .idle
                currentMeeting?.state = .completed
            }

            isRecording = false
            await RecordingExclusivityCoordinator.shared.endRecording()

            // Play stop recording sound feedback
            SoundFeedbackService.shared.playRecordingStopSound()

            AppLogger.info("Recording stopped", category: .recordingManager, extra: [
                "micURL": micURL?.lastPathComponent ?? "nil",
                "sysURL": sysURL?.lastPathComponent ?? "nil",
            ])

            let finalURL = try await processRecordedAudio(micURL: micURL, sysURL: sysURL)

            // Transcribe if requested
            if transcribe, let meeting = currentMeeting {
                await transcribeRecording(audioURL: finalURL, meeting: meeting)
            } else {
                postProcessingContext = nil
                postProcessingContextItems = []
                dictationSessionOutputLanguageOverride = nil
                currentMeeting = nil // Clear current meeting if done
                activeStartTelemetry = nil
            }

        } catch {
            AppLogger.error("Failed to stop recording cleanly", category: .recordingManager, error: error)
            lastError = error
            isRecording = false
            isTranscribing = false
            meetingState = .failed(error.localizedDescription) // Sync state
            currentMeeting?.state = .failed(error.localizedDescription) // Sync entity state
            await RecordingExclusivityCoordinator.shared.endRecording()
            postProcessingContext = nil
            postProcessingContextItems = []
            isStartingRecording = false
            dictationSessionOutputLanguageOverride = nil
            activeStartTelemetry = nil
        }
    }

    /// Cancel recording and discard audio files.
    func cancelRecording() async {
        guard isRecording || isStartingRecording else { return }

        if !isRecording {
            AppLogger.info("Cancelling recording during startup...", category: .recordingManager)
            _ = await micRecorder.stopRecording()
            _ = await systemRecorder.stopRecording()
            postStartContextCaptureTask?.cancel()
            postStartContextCaptureTask = nil
            isStartingRecording = false
            currentMeeting = nil
            postProcessingContext = nil
            postProcessingContextItems = []
            dictationSessionOutputLanguageOverride = nil
            activeStartTelemetry = nil
            await RecordingExclusivityCoordinator.shared.endRecording()
            SoundFeedbackService.shared.playRecordingCancelledSound()
            AppLogger.info("Recording startup cancelled", category: .recordingManager)
            return
        }

        AppLogger.info("Cancelling recording...", category: .recordingManager)

        // Stop recorders
        _ = await micRecorder.stopRecording()
        _ = await systemRecorder.stopRecording()
        postStartContextCaptureTask?.cancel()
        postStartContextCaptureTask = nil

        // Cleanup temporary files
        await cleanupTemporaryFiles()

        // Also cleanup merged file if it exists
        if let mergedURL = await getMergedAudioURL() {
            try? FileManager.default.removeItem(at: mergedURL)
            setMergedAudioURL(nil)
        }

        // Reset state
        isRecording = false
        isStartingRecording = false
        currentMeeting = nil
        postProcessingContext = nil
        postProcessingContextItems = []
        dictationSessionOutputLanguageOverride = nil
        activeStartTelemetry = nil
        await RecordingExclusivityCoordinator.shared.endRecording()
        SoundFeedbackService.shared.playRecordingCancelledSound()

        AppLogger.info("Recording cancelled and files discarded", category: .recordingManager)
    }

    /// Transcribe an externally recorded audio file.
    /// - Parameter audioURL: Path to the audio file (m4a, mp3, wav).
    func transcribeExternalAudio(from audioURL: URL) async {
        guard !isTranscribing else {
            AppLogger.info("Already transcribing", category: .recordingManager)
            return
        }

        // Validate file exists
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            AppLogger.error(
                "Audio file not found for import",
                category: .recordingManager,
                extra: ["path": audioURL.path]
            )
            lastError = AudioImportError.fileNotFound
            return
        }

        // Validate file extension
        let validExtensions = ["m4a", "mp3", "wav"]
        guard validExtensions.contains(audioURL.pathExtension.lowercased()) else {
            AppLogger.error(
                "Unsupported audio format for import",
                category: .recordingManager,
                extra: ["extension": audioURL.pathExtension]
            )
            lastError = AudioImportError.unsupportedFormat
            return
        }

        // Create meeting record for imported file
        let meeting = Meeting(
            app: .importedFile,
            audioFilePath: audioURL.path
        )
        currentMeeting = meeting

        AppLogger.info(
            "Starting transcription for imported file",
            category: .recordingManager,
            extra: ["filename": audioURL.lastPathComponent]
        )
        await transcribeRecording(audioURL: audioURL, meeting: meeting)
    }

    /// Enable automatic recording when meetings are detected.
    internal func enableAutoRecording() {
        meetingDetector.startMonitoring()

        // Watch for detected meetings
        meetingDetector.$detectedMeeting
            .dropFirst()
            .removeDuplicates()
            .sink { @Sendable [weak self] detected in
                Task { @MainActor in
                    let isCurrentlyRecording = self?.isRecording ?? false
                    if detected != nil, !isCurrentlyRecording {
                        await self?.startRecording(source: .all)
                    } else if detected == nil, isCurrentlyRecording {
                        await self?.stopRecording()
                    }
                }
            }
            .store(in: &cancellables)
    }

}

extension RecordingManager {
    public var effectiveDictationOutputLanguageForCurrentRecording: DictationOutputLanguage {
        if let override = dictationSessionOutputLanguageOverride {
            return override
        }

        let settings = AppSettingsStore.shared
        return matchingDictationAppRule(settings: settings)?.outputLanguage ?? .original
    }

    public func setDictationSessionOutputLanguageOverride(_ language: DictationOutputLanguage?) {
        dictationSessionOutputLanguageOverride = language
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // Sync with audio recorder state
        micRecorder.isRecordingPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRecording in
                guard let self else { return }
                self.isRecording = isRecording
                if isRecording {
                    self.isStartingRecording = false
                }
            }
            .store(in: &cancellables)
    }

    private func cleanupTemporaryFiles() async {
        var urlsToDelete: [URL] = []
        if let micURL = await getMicAudioURL() { urlsToDelete.append(micURL) }
        if let sysURL = await getSystemAudioURL() { urlsToDelete.append(sysURL) }

        storage.cleanupTemporaryFiles(urls: urlsToDelete)

        setMicAudioURL(nil)
        setSystemAudioURL(nil)
    }

    private func markRecorderStartedAt(_ recorderStartedAt: Date) {
        guard var telemetry = activeStartTelemetry else { return }
        telemetry.recorderStartedAt = recorderStartedAt
        activeStartTelemetry = telemetry

        AppLogger.debug(
            "Recording startup reached recorder",
            category: .performance,
            extra: [
                "trace": telemetry.traceID,
                "trigger": telemetry.triggerLabel,
                "source": telemetry.source.rawValue,
            ]
        )

        PerformanceMonitor.shared.reportMetric(
            name: "recording_start_requested_to_recorder_ms",
            value: recorderStartedAt.timeIntervalSince(telemetry.requestedAt) * 1000,
            unit: "ms"
        )
        PerformanceMonitor.shared.reportMetric(
            name: "recording_start_entry_to_recorder_ms",
            value: recorderStartedAt.timeIntervalSince(telemetry.managerEntryAt) * 1000,
            unit: "ms"
        )
    }

    private func startContextCaptureAfterRecordingStart(meetingID: UUID, source: RecordingSource) {
        postStartContextCaptureTask?.cancel()
        postStartContextCaptureTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let contextCaptureStartAt = Date()

            let activeContext = try? await self.activeAppContextProvider.fetchActiveAppContext()
            guard !Task.isCancelled else { return }
            guard var meeting = self.currentMeeting, meeting.id == meetingID else { return }

            if source == .microphone {
                self.dictationStartBundleIdentifier = activeContext?.bundleIdentifier
                self.dictationStartURL = self.activeBrowserURL(for: activeContext?.bundleIdentifier)
            } else {
                self.dictationStartBundleIdentifier = nil
                self.dictationStartURL = nil
            }

            meeting = self.applyStartAppContext(meeting, source: source, activeContext: activeContext)
            self.currentMeeting = meeting

            let captureResult = await self.capturePostProcessingContextWithTimeout(for: meeting)
            guard !Task.isCancelled else { return }
            guard self.currentMeeting?.id == meetingID else { return }

            self.postProcessingContext = captureResult.context
            self.postProcessingContextItems = captureResult.items

            if captureResult.didTimeout {
                AppLogger.warning(
                    "Context capture timed out after recording start",
                    category: .recordingManager
                )
            }

            PerformanceMonitor.shared.reportMetric(
                name: "recording_start_context_capture_ms",
                value: Date().timeIntervalSince(contextCaptureStartAt) * 1000,
                unit: "ms"
            )
        }
    }

    private func capturePostProcessingContextWithTimeout(
        for meeting: Meeting
    ) async -> (context: String?, items: [TranscriptionContextItem], didTimeout: Bool) {
        await withTaskGroup(
            of: (context: String?, items: [TranscriptionContextItem], didTimeout: Bool).self,
            returning: (context: String?, items: [TranscriptionContextItem], didTimeout: Bool).self
        ) { group in
            group.addTask { [weak self] in
                guard let self else {
                    return (nil, [], false)
                }
                let capture = await self.capturePostProcessingContext(for: meeting)
                return (capture.context, capture.items, false)
            }

            group.addTask {
                try? await Task.sleep(nanoseconds: Constants.startContextCaptureTimeout)
                return (nil, [], true)
            }

            let firstResult = await group.next() ?? (nil, [], true)
            group.cancelAll()
            return firstResult
        }
    }

    private enum Constants {
        static let processingProgress: Double = 10.0
        static let postProcessingProgress: Double = 90.0
        static let aiProcessingProgress: Double = 92.0
        static let statusResetDelay: Int = 3
        static let startContextCaptureTimeout: UInt64 = 1_500_000_000
    }

    private func processRecordedAudio(micURL: URL?, sysURL: URL?) async throws -> URL {
        guard let outputURL = await getMergedAudioURL() else {
            throw RecordingManagerError.noOutputPath
        }

        let settings = AppSettingsStore.shared

        if settings.shouldMergeAudioFiles {
            var inputURLs: [URL] = []
            if let micURL { inputURLs.append(micURL) }
            if let sysURL { inputURLs.append(sysURL) }

            // If we have 2 files, we definitely need to merge (mix them)
            // If we have 1 file, we only need to "merge" (export) if it's not already at the output URL OR if we want to ensure format compliance
            if inputURLs.count >= 2 {
                AppLogger.info("Merging \(inputURLs.count) audio files...", category: .recordingManager)
                let finalURL = try await audioMerger.mergeAudioFiles(
                    inputURLs: inputURLs,
                    to: outputURL,
                    format: settings.audioFormat
                )
                await cleanupTemporaryFiles()
                return finalURL
            } else if let singleURL = inputURLs.first {
                AppLogger.info("Single audio source recorded. Skipping merge and using: \(singleURL.lastPathComponent)", category: .recordingManager)

                // If the single file is already our output URL, we are done
                if singleURL == outputURL {
                    await cleanupTemporaryFiles()
                    return outputURL
                }

                // Otherwise move it to output location
                if FileManager.default.fileExists(atPath: outputURL.path) {
                    try FileManager.default.removeItem(at: outputURL)
                }
                try FileManager.default.moveItem(at: singleURL, to: outputURL)
                await cleanupTemporaryFiles()
                return outputURL
            } else {
                throw RecordingManagerError.noInputFiles
            }
        } else {
            AppLogger.info(
                "Audio merge disabled. Using microphone recording as primary.",
                category: .recordingManager
            )

            guard let sourceURL = micURL else {
                throw RecordingManagerError.noInputFiles
            }

            if sourceURL != outputURL {
                if FileManager.default.fileExists(atPath: outputURL.path) {
                    try FileManager.default.removeItem(at: outputURL)
                }
                try FileManager.default.moveItem(at: sourceURL, to: outputURL)
            }

            await cleanupTemporaryFiles()
            return outputURL
        }
    }

}

extension RecordingManager {
    private func transcribeRecording(audioURL: URL, meeting: Meeting) async {
        beginTranscriptionUIStateIfNeeded()

        let audioDuration = await getAudioDuration(from: audioURL)
        transcriptionStatus.beginTranscription(audioDuration: audioDuration)

        do {
            try await performHealthCheck()

            let settings = AppSettingsStore.shared
            let transcriptionStart = Date()
            let meetingEntity = makeMeetingEntity(meeting: meeting, audioDuration: audioDuration)
            let config = makeUseCaseConfig(meeting: meeting, settings: settings)

            meetingState = .processing(.transcribing)

            let transcriptionEntity = try await transcribeAudioUseCase.execute(
                audioURL: audioURL,
                meeting: meetingEntity,
                inputSource: resolveInputSourceLabel(for: meeting),
                contextItems: config.postProcessingContextItems,
                vocabularyReplacementRules: settings.vocabularyReplacementRules,
                applyPostProcessing: config.applyPostProcessing,
                postProcessingPrompt: config.postProcessingPrompt,
                defaultPostProcessingPrompt: config.defaultPostProcessingPrompt,
                postProcessingModel: config.postProcessingModel,
                autoDetectMeetingType: config.autoDetectMeetingType,
                availablePrompts: config.availablePrompts,
                postProcessingContext: config.postProcessingContext
            )

            let transcription = convertToModel(transcriptionEntity, audioDuration: audioDuration, transcriptionStart: transcriptionStart)

            meetingState = .processing(.generatingOutput)
            currentMeeting?.state = .completed

            TranscriptionDeliveryService.deliver(
                transcription: transcription,
                recordingSource: recordingSource
            )

            transcriptionStatus.completeTranscription(success: true)
            notifySuccess(for: transcription)
            scheduleStatusReset()

            if settings.autoExportSummaries {
                await exportSummary(transcription: transcription)
            }
        } catch {
            handleTranscriptionError(error)
            meetingState = .failed(error.localizedDescription)
            currentMeeting?.state = .failed(error.localizedDescription)
        }

        isTranscribing = false
        isStartingRecording = false
        meetingState = .idle
        currentMeeting = nil
        postProcessingContext = nil
        postProcessingContextItems = []
        dictationSessionOutputLanguageOverride = nil
        activeStartTelemetry = nil
        postStartContextCaptureTask = nil
    }

    private func beginTranscriptionUIStateIfNeeded() {
        // stopRecording() may have already set `isTranscribing` to bridge the UI gap.
        guard !isTranscribing else { return }
        isTranscribing = true
        meetingState = .processing(.transcribing)
        currentMeeting?.state = .processing(.transcribing)
    }

    private struct UseCaseConfig {
        let applyPostProcessing: Bool
        let postProcessingPrompt: DomainPostProcessingPrompt?
        let defaultPostProcessingPrompt: DomainPostProcessingPrompt?
        let postProcessingModel: String?
        let autoDetectMeetingType: Bool
        let availablePrompts: [DomainPostProcessingPrompt]
        let postProcessingContext: String?
        let postProcessingContextItems: [TranscriptionContextItem]
    }

    private func makeMeetingEntity(meeting: Meeting, audioDuration: Double?) -> MeetingEntity {
        var entity = MeetingEntity(
            id: meeting.id,
            app: DomainMeetingApp(rawValue: meeting.app.rawValue) ?? .unknown,
            appBundleIdentifier: meeting.appBundleIdentifier,
            appDisplayName: meeting.appDisplayName,
            startTime: meeting.startTime,
            endTime: meeting.endTime,
            audioFilePath: meeting.audioFilePath
        )

        if entity.endTime == nil, let audioDuration {
            entity.endTime = entity.startTime.addingTimeInterval(audioDuration)
        }

        return entity
    }

    private func makeUseCaseConfig(meeting: Meeting, settings: AppSettingsStore) -> UseCaseConfig {
        let applyPostProcessing = settings.postProcessingEnabled && settings.aiConfiguration.isValid
        let isDictation = isDictationMode(for: meeting)

        let disabledForRecording = isDictation
            ? settings.isDictationPostProcessingDisabled
            : settings.isMeetingPostProcessingDisabled
        let shouldApplyPostProcessing = applyPostProcessing && !disabledForRecording

        guard shouldApplyPostProcessing else {
            return UseCaseConfig(
                applyPostProcessing: false,
                postProcessingPrompt: nil,
                defaultPostProcessingPrompt: nil,
                postProcessingModel: nil,
                autoDetectMeetingType: false,
                availablePrompts: [],
                postProcessingContext: nil,
                postProcessingContextItems: postProcessingContextItems
            )
        }

        let availablePrompts = makeAvailablePrompts(isDictation: isDictation, settings: settings)
        let defaultMeetingPrompt = makeDefaultMeetingPrompt(isDictation: isDictation, settings: settings)
        let prompt = resolvePostProcessingPromptForUseCase(
            meeting: meeting,
            isDictation: isDictation,
            settings: settings,
            defaultMeetingPrompt: defaultMeetingPrompt
        )

        let autoDetectMeetingType = !isDictation && meeting.type == .autodetect

        return UseCaseConfig(
            applyPostProcessing: true,
            postProcessingPrompt: prompt,
            defaultPostProcessingPrompt: autoDetectMeetingType ? defaultMeetingPrompt : nil,
            postProcessingModel: settings.aiConfiguration.selectedModel,
            autoDetectMeetingType: autoDetectMeetingType,
            availablePrompts: availablePrompts,
            postProcessingContext: postProcessingContext,
            postProcessingContextItems: postProcessingContextItems
        )
    }

    private func capturePostProcessingContext(for meeting: Meeting) async -> (context: String?, items: [TranscriptionContextItem]) {
        let settings = AppSettingsStore.shared
        let activeTabURL = activeBrowserURL(for: meeting.appBundleIdentifier)?.absoluteString

        guard settings.contextAwarenessEnabled else {
            AppLogger.debug(
                "Context awareness disabled, skipping context capture",
                category: .recordingManager,
                extra: ["reasonCode": "context.disabled"]
            )

            guard let activeTabURL else {
                return (nil, [])
            }

            return (
                nil,
                [TranscriptionContextItem(source: .activeTabURL, text: activeTabURL)]
            )
        }

        let snapshot = await contextAwarenessService.captureSnapshot(
            options: .init(
                includeActiveApp: true,
                includeClipboard: settings.contextAwarenessIncludeClipboard,
                includeWindowOCR: settings.contextAwarenessIncludeWindowOCR,
                includeAccessibilityText: settings.contextAwarenessIncludeAccessibilityText,
                protectSensitiveApps: settings.contextAwarenessProtectSensitiveApps,
                redactSensitiveData: settings.contextAwarenessRedactSensitiveData,
                excludedBundleIDs: settings.contextAwarenessExcludedBundleIDs
            )
        )

        var context = contextAwarenessService.makePostProcessingContext(from: snapshot)
        var items = makeContextItems(from: snapshot)

        if let activeTabURL {
            items.append(TranscriptionContextItem(source: .activeTabURL, text: activeTabURL))

            let activeTabURLBlock = "- Active tab URL: \(activeTabURL)"
            if let existingContext = context,
               !existingContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            {
                context = "\(existingContext)\n\(activeTabURLBlock)"
            } else {
                context = """
                CONTEXT_METADATA
                \(activeTabURLBlock)
                """
            }
        }

        if isDictationMode(for: meeting),
           settings.contextAwarenessIncludeAccessibilityText,
           snapshot.activeAccessibilityText == nil,
           let focusedText = await captureFocusedTextContext(settings: settings),
           !items.contains(where: { $0.source == .focusedText && $0.text == focusedText })
        {
            items.append(TranscriptionContextItem(source: .focusedText, text: focusedText))

            let focusedTextBlock = """
            - Focused text:
            \(focusedText)
            """

            if let existingContext = context,
               !existingContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            {
                context = "\(existingContext)\n\(focusedTextBlock)"
            } else {
                context = """
                CONTEXT_METADATA
                \(focusedTextBlock)
                """
            }
        }

        if settings.contextAwarenessIncludeWindowOCR, snapshot.activeWindowOCRText == nil {
            AppLogger.debug(
                "Context capture finished without OCR text",
                category: .recordingManager,
                extra: ["reasonCode": "context.ocr_missing"]
            )
        }

        if items.isEmpty {
            AppLogger.info(
                "Context capture finished with no context items",
                category: .recordingManager,
                extra: ["reasonCode": "context.empty"]
            )
        } else {
            AppLogger.debug(
                "Context capture finished",
                category: .recordingManager,
                extra: [
                    "reasonCode": "context.captured",
                    "itemCount": items.count,
                    "sources": items.map(\ .source.rawValue).joined(separator: ",")
                ]
            )
        }

        return (context, items)
    }

    private func captureFocusedTextContext(settings: AppSettingsStore) async -> String? {
        guard settings.contextAwarenessIncludeAccessibilityText else { return nil }

        guard AccessibilityPermissionService.isTrusted() else {
            AppLogger.warning(
                "Focused text capture skipped: accessibility permission not granted",
                category: .recordingManager,
                extra: ["reasonCode": "focused_text.permission_denied"]
            )
            AccessibilityPermissionService.requestPermission()
            return nil
        }

        do {
            let snapshot = try await textContextProvider.fetchTextContext()
            let guarded = textContextGuardrails.apply(to: snapshot.text, policy: textContextPolicy)
            var normalized = guarded.trimmingCharacters(in: .whitespacesAndNewlines)

            if settings.contextAwarenessRedactSensitiveData {
                normalized = ContextAwarenessPrivacy.redactSensitiveText(normalized) ?? ""
            }

            return normalized.isEmpty ? nil : normalized
        } catch {
            AppLogger.warning(
                "Focused text capture failed",
                category: .recordingManager,
                extra: [
                    "reasonCode": "focused_text.provider_failed",
                    "error": error.localizedDescription,
                ]
            )
            return nil
        }
    }

    private func makeContextItems(from snapshot: ContextAwarenessSnapshot) -> [TranscriptionContextItem] {
        var items: [TranscriptionContextItem] = []

        if let activeAppName = snapshot.activeAppName {
            items.append(TranscriptionContextItem(source: .activeApp, text: activeAppName))
        }

        if let activeWindowTitle = snapshot.activeWindowTitle {
            items.append(TranscriptionContextItem(source: .windowTitle, text: activeWindowTitle))
        }

        if let accessibilityText = snapshot.activeAccessibilityText {
            items.append(TranscriptionContextItem(source: .accessibilityText, text: accessibilityText))
        }

        if let clipboardText = snapshot.clipboardText {
            items.append(TranscriptionContextItem(source: .clipboard, text: clipboardText))
        }

        if let ocrText = snapshot.activeWindowOCRText {
            items.append(TranscriptionContextItem(source: .windowOCR, text: ocrText))
        }

        return items
    }

    private func makeAvailablePrompts(isDictation: Bool, settings: AppSettingsStore) -> [DomainPostProcessingPrompt] {
        guard !isDictation else { return [] }

        let builtIn: [PostProcessingPrompt] = [.standup, .presentation, .designReview, .oneOnOne, .planning]
        return (builtIn + settings.meetingPrompts).map(domainPrompt(from:))
    }

    private func makeDefaultMeetingPrompt(
        isDictation: Bool,
        settings: AppSettingsStore
    ) -> DomainPostProcessingPrompt? {
        guard !isDictation else { return nil }

        if let selected = settings.selectedPrompt {
            return domainPrompt(from: selected)
        }

        return domainPrompt(from: PromptService.shared.strategy(for: .general).promptObject())
    }

    private func resolvePostProcessingPromptForUseCase(
        meeting: Meeting,
        isDictation: Bool,
        settings: AppSettingsStore,
        defaultMeetingPrompt: DomainPostProcessingPrompt?
    ) -> DomainPostProcessingPrompt? {
        if isDictation {
            let basePrompt = settings.selectedDictationPrompt ?? .cleanTranscription
            let resolvedPrompt = promptWithDictationRuleOverrides(prompt: basePrompt, settings: settings)
            return domainPrompt(from: resolvedPrompt)
        }

        switch meeting.type {
        case .autodetect:
            // Let the UseCase classify and pick a concrete prompt.
            return nil
        case .standup:
            return domainPrompt(from: .standup)
        case .presentation:
            return domainPrompt(from: .presentation)
        case .designReview:
            return domainPrompt(from: .designReview)
        case .oneOnOne:
            return domainPrompt(from: .oneOnOne)
        case .planning:
            return domainPrompt(from: .planning)
        case .general:
            return defaultMeetingPrompt
        }
    }

    private func domainPrompt(from prompt: PostProcessingPrompt) -> DomainPostProcessingPrompt {
        DomainPostProcessingPrompt(id: prompt.id, title: prompt.title, content: prompt.promptText, isDefault: false)
    }

    private func promptWithDictationRuleOverrides(
        prompt: PostProcessingPrompt,
        settings: AppSettingsStore
    ) -> PostProcessingPrompt {
        var appliedInstructions: [String] = []

        if shouldForceMarkdownForDictation(settings: settings) {
            appliedInstructions.append(Self.markdownFormatInstruction)
        }

        let outputLanguage = outputLanguageForDictation(settings: settings)
        if outputLanguage != .original {
            appliedInstructions.append(Self.translationInstruction(for: outputLanguage))
        }

        if let customInstructions = effectiveCustomPromptInstructionsForDictation(settings: settings) {
            appliedInstructions.append(Self.siteOrAppPriorityInstructionBlock(customInstructions))
        }

        guard !appliedInstructions.isEmpty else { return prompt }

        let augmentedText = ([prompt.promptText] + appliedInstructions).joined(separator: "\n\n")

        return PostProcessingPrompt(
            id: prompt.id,
            title: prompt.title,
            promptText: augmentedText,
            isActive: prompt.isActive,
            icon: prompt.icon,
            description: prompt.description,
            isPredefined: prompt.isPredefined
        )
    }

    private func effectiveCustomPromptInstructionsForDictation(settings: AppSettingsStore) -> String? {
        if let websiteTarget = matchingWebContextTargetForDictation(settings: settings),
           let instructions = websiteTarget.customPromptInstructions?.trimmingCharacters(in: .whitespacesAndNewlines),
           !instructions.isEmpty
        {
            return instructions
        }

        if let appRule = matchingDictationAppRule(settings: settings),
           let instructions = appRule.customPromptInstructions?.trimmingCharacters(in: .whitespacesAndNewlines),
           !instructions.isEmpty
        {
            return instructions
        }

        return nil
    }

    private func matchingDictationAppRule(settings: AppSettingsStore) -> DictationAppRule? {
        guard let bundleIdentifier = dictationStartBundleIdentifier else { return nil }
        let normalized = WebTargetDetection.normalizeBundleIdentifier(bundleIdentifier)

        return settings.dictationAppRules.first {
            WebTargetDetection.normalizeBundleIdentifier($0.bundleIdentifier) == normalized
        }
    }

    private func outputLanguageForDictation(settings: AppSettingsStore) -> DictationOutputLanguage {
        if let override = dictationSessionOutputLanguageOverride {
            return override
        }

        if let websiteTarget = matchingWebContextTargetForDictation(settings: settings),
           websiteTarget.outputLanguage != .original
        {
            return websiteTarget.outputLanguage
        }

        guard let rule = matchingDictationAppRule(settings: settings) else { return .original }
        return rule.outputLanguage
    }

    private func shouldForceMarkdownForDictation(settings: AppSettingsStore) -> Bool {
        guard let bundleIdentifier = dictationStartBundleIdentifier else { return false }
        let normalized = WebTargetDetection.normalizeBundleIdentifier(bundleIdentifier)

        if let websiteTarget = matchingWebContextTargetForDictation(settings: settings) {
            return websiteTarget.forceMarkdownOutput
        }

        if let rule = matchingDictationAppRule(settings: settings), rule.forceMarkdownOutput {
            return true
        }

        // Backward compatibility for users that only have the legacy list.
        let appTargets = Set(settings.markdownTargetBundleIdentifiers.map(WebTargetDetection.normalizeBundleIdentifier))
        if appTargets.contains(normalized) {
            return true
        }

        return false
    }

    private func matchingWebContextTargetForDictation(settings: AppSettingsStore) -> WebContextTarget? {
        guard let bundleIdentifier = dictationStartBundleIdentifier else { return nil }
        let normalized = WebTargetDetection.normalizeBundleIdentifier(bundleIdentifier)
        let webTargets = settings.markdownWebTargets
        guard !webTargets.isEmpty else { return nil }

        if let url = dictationStartURL,
           let target = WebTargetDetection.matchTarget(
               for: url,
               bundleIdentifier: normalized,
               targets: webTargets,
               fallbackBrowserBundleIdentifiers: settings.effectiveWebTargetBrowserBundleIdentifiers
           )
        {
            return target
        }

        return WebTargetDetection.matchTargetByWindowTitle(
            bundleIdentifier: normalized,
            targets: webTargets,
            fallbackBrowserBundleIdentifiers: settings.effectiveWebTargetBrowserBundleIdentifiers
        )
    }

    private func activeBrowserURL(for bundleIdentifier: String?) -> URL? {
        guard let bundleIdentifier else { return nil }
        let normalized = WebTargetDetection.normalizeBundleIdentifier(bundleIdentifier)

        if let provider = browserProviders[normalized] {
            return provider.activeTabURL()
        }

        guard let provider = BrowserProviderRegistry.provider(for: bundleIdentifier) else {
            return nil
        }

        browserProviders[normalized] = provider
        return provider.activeTabURL()
    }
    private static let markdownFormatInstruction = """
    <OUTPUT_FORMAT>
    ALWAYS format the output as Markdown. When formatting using Markdown, use traditional formatting conventions for ordered or unordered lists, **bold**, *italics*, and headings as well.
    </OUTPUT_FORMAT>
    """

    private static func translationInstruction(for language: DictationOutputLanguage) -> String {
        """
        <OUTPUT_LANGUAGE>
        Translate the final output to \(language.instructionDisplayName). This requirement overrides any instruction that says to keep the original language.
        </OUTPUT_LANGUAGE>
        """
    }

    private static func siteOrAppPriorityInstructionBlock(_ instructions: String) -> String {
        """
        <\(AIPromptTemplates.siteOrAppPriorityTag)>
        \(instructions)
        </\(AIPromptTemplates.siteOrAppPriorityTag)>
        """
    }

    private func exportSummary(transcription: Transcription) async {
        let settings = AppSettingsStore.shared
        guard let folder = settings.summaryExportFolder else { return }

        let content: String
        if settings.summaryTemplateEnabled {
            let template = settings.summaryTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !template.isEmpty else { return }
            content = MarkdownRenderer().renderWithTemplate(template, meeting: transcription.meeting, transcription: transcription)
        } else {
            let plainContent = transcription.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !plainContent.isEmpty else { return }
            content = plainContent
        }

        guard folder.startAccessingSecurityScopedResource() else {
            AppLogger.error("Failed to access export folder security-scoped resource", category: .recordingManager)
            return
        }
        defer { folder.stopAccessingSecurityScopedResource() }

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = .current
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFormatter.string(from: transcription.meeting.startTime)

        let meetingTitle: String = {
            let raw = transcription.meeting.type.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let range = raw.range(of: " (") else { return raw }
            return String(raw[..<range.lowerBound])
        }()

        let safeTitle = meetingTitle.components(separatedBy: CharacterSet(charactersIn: "/\\?%*|\"<>:")).joined(separator: " ").split(whereSeparator: \.isWhitespace).joined(separator: " ")

        let titleComponent = safeTitle.isEmpty ? transcription.meeting.appName : safeTitle
        let baseName = "\(dateStr) \(titleComponent)"

        var destinationURL = folder.appendingPathComponent("\(baseName).md")
        var attempt = 1
        while FileManager.default.fileExists(atPath: destinationURL.path) {
            attempt += 1
            destinationURL = folder.appendingPathComponent("\(baseName)-\(attempt).md")
        }

        do {
            try content.write(to: destinationURL, atomically: true, encoding: .utf8)
            AppLogger.info("Summary exported to \(destinationURL.path)", category: .recordingManager)
        } catch {
            AppLogger.error("Failed to export summary", category: .recordingManager, error: error)
        }
    }

    private func convertToModel(_ entity: TranscriptionEntity, audioDuration: Double?, transcriptionStart: Date) -> Transcription {
        Transcription(
            id: entity.id,
            meeting: Meeting(
                id: entity.meeting.id,
                app: MeetingApp(rawValue: entity.meeting.app.rawValue) ?? .unknown,
                appBundleIdentifier: entity.meeting.appBundleIdentifier,
                appDisplayName: entity.meeting.appDisplayName,
                type: MeetingType(rawValue: entity.meetingType ?? "") ?? .general, // Map back
                startTime: entity.meeting.startTime,
                endTime: entity.meeting.endTime,
                audioFilePath: entity.meeting.audioFilePath
            ),
            contextItems: entity.contextItems,
            segments: entity.segments.map { Transcription.Segment(id: $0.id, speaker: $0.speaker, text: $0.text, startTime: $0.startTime, endTime: $0.endTime) },
            text: entity.text,
            rawText: entity.rawText,
            processedContent: entity.processedContent,
            canonicalSummary: entity.canonicalSummary,
            qualityProfile: entity.qualityProfile,
            postProcessingPromptId: entity.postProcessingPromptId,
            postProcessingPromptTitle: entity.postProcessingPromptTitle,
            language: entity.language,
            createdAt: entity.createdAt,
            modelName: entity.modelName,
            inputSource: entity.inputSource, // Entity might not have inputSource? check config
            transcriptionDuration: entity.transcriptionDuration, // Entity has it?
            postProcessingDuration: entity.postProcessingDuration,
            postProcessingModel: entity.postProcessingModel,
            meetingType: entity.meetingType
        )
    }

    // MARK: - Helper Methods

    private func performHealthCheck() async throws {
        transcriptionStatus.updateProgress(phase: .preparing)
        let isHealthy = try await transcriptionClient.healthCheck()
        guard isHealthy else {
            throw TranscriptionError.serviceUnavailable
        }
    }

    private func performTranscription(audioURL: URL) async throws -> TranscriptionResponse {
        transcriptionStatus.updateProgress(phase: .processing, percentage: Constants.processingProgress)
        return try await transcriptionClient.transcribe(
            audioURL: audioURL,
            onProgress: { [weak self] percentage in
                Task { @MainActor in
                    self?.transcriptionStatus.updateProgress(phase: .processing, percentage: percentage)
                }
            }
        )
    }

    private struct PostProcessingResult {
        let processedContent: String?
        let canonicalSummary: CanonicalSummary?
        let promptId: UUID?
        let promptTitle: String?
        let duration: Double
        let model: String?

        static let empty = PostProcessingResult(
            processedContent: nil,
            canonicalSummary: nil,
            promptId: nil,
            promptTitle: nil,
            duration: 0,
            model: nil
        )
    }

    private func applyPostProcessing(
        postProcessingInput: String,
        meeting: Meeting?,
        qualityProfile: TranscriptionQualityProfile?
    ) async -> PostProcessingResult {
        transcriptionStatus.updateProgress(phase: .postProcessing, percentage: Constants.postProcessingProgress)

        let settings = AppSettingsStore.shared
        guard settings.postProcessingEnabled, settings.aiConfiguration.isValid else { return .empty }

        let isDictation = isDictationMode(for: meeting)
        guard !isPostProcessingDisabled(isDictation: isDictation, settings: settings) else { return .empty }

        let type = meeting?.type ?? currentMeeting?.type ?? .general
        let prompt = await resolvePostProcessingPrompt(
            rawText: postProcessingInput,
            isDictation: isDictation,
            meetingType: type,
            settings: settings
        )

        transcriptionStatus.updateProgress(phase: .postProcessing, percentage: Constants.aiProcessingProgress)
        return await runPostProcessing(
            postProcessingInput: postProcessingInput,
            prompt: prompt,
            settings: settings,
            qualityProfile: qualityProfile
        )
    }

    private func isDictationMode(for meeting: Meeting?) -> Bool {
        if let meeting, meeting.app == .importedFile {
            return false
        }

        // During active capture/transcription, source is the canonical mode signal.
        if isRecording || isTranscribing {
            return recordingSource == .microphone
        }

        return meeting?.isDictation == true || recordingSource == .microphone
    }

    private func isPostProcessingDisabled(isDictation: Bool, settings: AppSettingsStore) -> Bool {
        if isDictation { return settings.isDictationPostProcessingDisabled }
        return settings.isMeetingPostProcessingDisabled
    }

    private func resolvePostProcessingPrompt(
        rawText: String,
        isDictation: Bool,
        meetingType: MeetingType,
        settings: AppSettingsStore
    ) async -> PostProcessingPrompt {
        if isDictation {
            return settings.selectedDictationPrompt ?? .cleanTranscription
        }

        if meetingType == .autodetect {
            return await resolveAutodetectPrompt(rawText: rawText, settings: settings)
        }

        if meetingType != .general {
            let strategy = PromptService.shared.strategy(for: meetingType)
            let prompt = strategy.promptObject()
            AppLogger.info("Using context-aware prompt for type: \(meetingType.displayName)", category: .transcriptionEngine)
            return prompt
        }

        return settings.selectedPrompt ?? PromptService.shared.strategy(for: .general).promptObject()
    }

    private func resolveAutodetectPrompt(rawText: String, settings: AppSettingsStore) async -> PostProcessingPrompt {
        let fallback = settings.selectedPrompt ?? PromptService.shared.strategy(for: .general).promptObject()
        let classifierPrompt = makeMeetingTypeClassifierPrompt()

        do {
            let jsonString = try await postProcessingService.processTranscription(rawText, with: classifierPrompt)
            guard let detectedType = parseMeetingType(from: jsonString), detectedType != .general else { return fallback }
            return resolveBuiltInMeetingPrompt(for: detectedType, fallbackGeneral: fallback)
        } catch {
            AppLogger.warning("Meeting type autodetect failed; falling back to general prompt", category: .recordingManager, extra: ["error": error.localizedDescription])
            return fallback
        }
    }

    private func makeMeetingTypeClassifierPrompt() -> PostProcessingPrompt {
        PostProcessingPrompt(
            title: "Classifier",
            promptText: """
            Analyze the transcription and classify the meeting type.
            Reply ONLY with JSON in the following format:
            { "type": "VALUE" }
            Allowed values: standup, presentation, design_review, one_on_one, planning, general.
            """,
            icon: "sparkles",
            isPredefined: false
        )
    }

    private func runPostProcessing(
        postProcessingInput: String,
        prompt: PostProcessingPrompt,
        settings: AppSettingsStore,
        qualityProfile: TranscriptionQualityProfile?
    ) async -> PostProcessingResult {
        do {
            let startTime = Date()
            let structuredResult = try await postProcessingService.processTranscriptionStructured(postProcessingInput, with: prompt)
            let duration = Date().timeIntervalSince(startTime)
            let model = settings.aiConfiguration.selectedModel
            let canonicalSummary = qualityProfile.map { profile in
                recalibrateCanonicalSummary(structuredResult.canonicalSummary, with: profile)
            } ?? structuredResult.canonicalSummary
            AppLogger.info(
                "Post-processing complete",
                category: .recordingManager,
                extra: ["prompt": prompt.title, "output_state": structuredResult.outputState.rawValue]
            )
            return PostProcessingResult(
                processedContent: structuredResult.processedText,
                canonicalSummary: canonicalSummary,
                promptId: prompt.id,
                promptTitle: prompt.title,
                duration: duration,
                model: model
            )
        } catch {
            AppLogger.error("Post-processing failed, using raw transcription", category: .recordingManager, error: error)
            return .empty
        }
    }

    private func resolveBuiltInMeetingPrompt(for type: MeetingType, fallbackGeneral: PostProcessingPrompt) -> PostProcessingPrompt {
        switch type {
        case .standup:
            .standup
        case .presentation:
            .presentation
        case .designReview:
            .designReview
        case .oneOnOne:
            .oneOnOne
        case .planning:
            .planning
        case .general:
            fallbackGeneral
        case .autodetect:
            fallbackGeneral
        }
    }

    private func parseMeetingType(from jsonString: String) -> MeetingType? {
        if let type = parseMeetingTypeFromJSON(jsonString) {
            return type
        }

        guard let startIndex = jsonString.firstIndex(of: "{"),
              let endIndex = jsonString.lastIndex(of: "}")
        else {
            return nil
        }

        let candidate = String(jsonString[startIndex...endIndex])
        return parseMeetingTypeFromJSON(candidate)
    }

    private func parseMeetingTypeFromJSON(_ jsonString: String) -> MeetingType? {
        guard let data = jsonString.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rawType = object["type"] as? String
        else {
            return nil
        }

        let trimmed = rawType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let type = MeetingType(rawValue: trimmed) else { return nil }

        let allowed: Set<MeetingType> = [.standup, .presentation, .designReview, .oneOnOne, .planning, .general]
        return allowed.contains(type) ? type : nil
    }

    private func notifySuccess(for transcription: Transcription) {
        let suffix =
            transcription.isPostProcessed
                ? "notification.transcription_processed".localized
                : "notification.transcription_transcribed".localized
        let body = "notification.transcription_body".localized(
            with: transcription.meeting.appName,
            transcription.wordCount,
            suffix
        )

        notificationService.sendNotification(
            title: "notification.transcription_completed".localized,
            body: body
        )

        NotificationCenter.default.post(
            name: .meetingAssistantTranscriptionSaved,
            object: nil,
            userInfo: [AppNotifications.UserInfoKey.transcriptionId: transcription.id.uuidString]
        )
    }

    private func handleTranscriptionError(_ error: Error) {
        AppLogger.error("Transcription failed", category: .recordingManager, error: error)
        lastError = error

        transcriptionStatus.recordError(.transcriptionFailed(error.localizedDescription))
        transcriptionStatus.completeTranscription(success: false)

        notificationService.sendNotification(
            title: "notification.transcription_failed".localized,
            body: error.localizedDescription
        )
    }

    private func scheduleStatusReset() {
        Task { @MainActor in
            // Task.sleep throws only if cancelled, which is not critical for status reset
            try? await Task.sleep(for: .seconds(Constants.statusResetDelay))
            self.transcriptionStatus.resetToIdle()
        }
    }

    /// Get audio duration from file for progress estimation.
    private func getAudioDuration(from url: URL) async -> Double? {
        let asset = AVURLAsset(url: url)
        do {
            let duration = try await asset.load(.duration)
            return duration.seconds
        } catch {
            AppLogger.error("Failed to load audio duration", category: .recordingManager, error: error)
            return nil
        }
    }

}

extension RecordingManager {
    private enum StatusMonitoringConstants {
        static let pollingIntervalSeconds: Double = 30
    }

    /// Start periodic status monitoring.
    private func startStatusMonitoring() async {
        statusCheckTask?.cancel()

        statusCheckTask = Task { @Sendable @MainActor [weak self] in
            while !Task.isCancelled {
                await self?.checkServiceStatus()
                try? await Task.sleep(for: .seconds(StatusMonitoringConstants.pollingIntervalSeconds))
            }
        }
    }

    /// Check and update service status.
    private func checkServiceStatus() async {
        transcriptionStatus.updateServiceState(.connecting)

        do {
            let status = try await transcriptionClient.fetchServiceStatus()
            transcriptionStatus.updateServiceState(.connected)
            transcriptionStatus.updateModelState(status.modelStateEnum, device: status.device)
        } catch {
            transcriptionStatus.updateServiceState(.disconnected)
            transcriptionStatus.recordError(.connectionFailed(error.localizedDescription))
        }
    }

    /// Manually refresh service status.
    func refreshServiceStatus() async {
        await checkServiceStatus()
    }

    /// Resets the manager and actor state to idle.
    public func reset() async {
        postStartContextCaptureTask?.cancel()
        postStartContextCaptureTask = nil
        await recordingActor.reset()
        isRecording = false
        isStartingRecording = false
        isTranscribing = false
        currentMeeting = nil
        lastError = nil
        activeStartTelemetry = nil
    }

}

// MARK: - Retry Transcription

extension RecordingManager {
    /// Retry transcription for an existing entry using the currently active model.
    /// - Parameter transcription: Existing transcription to overwrite with new results.
    public func retryTranscription(for transcription: Transcription) async {
        guard !isTranscribing else {
            AppLogger.info("Already transcribing", category: .recordingManager)
            return
        }

        guard let audioURL = resolveRetryAudioURL(for: transcription) else { return }

        await runRetryTranscription(audioURL: audioURL, transcription: transcription)
    }

    private func resolveRetryAudioURL(for transcription: Transcription) -> URL? {
        guard let audioURL = transcription.audioURL else {
            AppLogger.error("Audio file missing for retry", category: .recordingManager, extra: ["id": transcription.id.uuidString])
            lastError = AudioImportError.fileNotFound
            return nil
        }

        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            AppLogger.error("Audio file not found for retry", category: .recordingManager, extra: ["path": audioURL.path])
            lastError = AudioImportError.fileNotFound
            return nil
        }

        return audioURL
    }

    private func runRetryTranscription(audioURL: URL, transcription: Transcription) async {
        isTranscribing = true
        let audioDuration = await getAudioDuration(from: audioURL)
        transcriptionStatus.beginTranscription(audioDuration: audioDuration)

        do {
            let updated = try await performRetryTranscription(
                audioURL: audioURL,
                transcription: transcription,
                audioDuration: audioDuration
            )
            try await storage.saveTranscription(updated)
            transcriptionStatus.completeTranscription(success: true)
            notifySuccess(for: updated)
            scheduleStatusReset()
        } catch {
            handleTranscriptionError(error)
        }

        isTranscribing = false
    }

    private func performRetryTranscription(
        audioURL: URL,
        transcription: Transcription,
        audioDuration: Double?
    ) async throws -> Transcription {
        try await performHealthCheck()

        let transcriptionStart = Date()
        let response = try await performTranscription(audioURL: audioURL)
        let transcriptionProcessingDuration = Date().timeIntervalSince(transcriptionStart)
        let settings = AppSettingsStore.shared
        let replacedText = applyVocabularyReplacements(
            to: response.text,
            with: settings.vocabularyReplacementRules
        )
        let replacedSegments = applyVocabularyReplacements(
            to: response.segments,
            with: settings.vocabularyReplacementRules
        )
        let qualityProfile = transcriptPreprocessor.preprocess(
            transcriptionText: replacedText,
            segments: replacedSegments.map {
                DomainTranscriptionSegment(
                    id: $0.id,
                    speaker: $0.speaker,
                    text: $0.text,
                    startTime: $0.startTime,
                    endTime: $0.endTime
                )
            },
            asrConfidenceScore: response.confidenceScore
        )
        let postProcessingInput = mergedPostProcessingInput(
            transcriptionText: qualityProfile.normalizedTextForIntelligence,
            qualityProfile: qualityProfile,
            context: postProcessingContext
        )

        let meeting = updatedMeeting(for: transcription.meeting, audioDuration: audioDuration)
        let postProcessing = await applyPostProcessing(
            postProcessingInput: postProcessingInput,
            meeting: meeting,
            qualityProfile: qualityProfile
        )

        return Transcription(
            id: transcription.id,
            meeting: meeting,
            contextItems: transcription.contextItems,
            segments: replacedSegments,
            text: postProcessing.processedContent ?? replacedText,
            rawText: response.text,
            processedContent: postProcessing.processedContent,
            canonicalSummary: postProcessing.canonicalSummary,
            qualityProfile: qualityProfile,
            postProcessingPromptId: postProcessing.promptId,
            postProcessingPromptTitle: postProcessing.promptTitle,
            language: response.language,
            createdAt: transcription.createdAt,
            modelName: response.model,
            inputSource: transcription.inputSource,
            transcriptionDuration: transcriptionProcessingDuration,
            postProcessingDuration: postProcessing.duration,
            postProcessingModel: postProcessing.model,
            meetingType: transcription.meeting.type.rawValue
        )
    }

    private func applyVocabularyReplacements(
        to text: String,
        with rules: [VocabularyReplacementRule]
    ) -> String {
        var output = text

        for rule in rules {
            let find = rule.find.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !find.isEmpty else { continue }

            let escapedFind = NSRegularExpression.escapedPattern(for: find)
            let pattern = "\\b\(escapedFind)\\b"

            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }

            let escapedReplacement = NSRegularExpression.escapedTemplate(for: rule.replace)
            let range = NSRange(output.startIndex..<output.endIndex, in: output)
            output = regex.stringByReplacingMatches(
                in: output,
                options: [],
                range: range,
                withTemplate: escapedReplacement
            )
        }

        return output
    }

    private func applyVocabularyReplacements(
        to segments: [Transcription.Segment],
        with rules: [VocabularyReplacementRule]
    ) -> [Transcription.Segment] {
        segments.map { segment in
            Transcription.Segment(
                id: segment.id,
                speaker: segment.speaker,
                text: applyVocabularyReplacements(to: segment.text, with: rules),
                startTime: segment.startTime,
                endTime: segment.endTime
            )
        }
    }

    private func mergedPostProcessingInput(
        transcriptionText: String,
        qualityProfile: TranscriptionQualityProfile,
        context: String?
    ) -> String {
        var blocks = [transcriptionText]
        blocks.append(qualityMetadataBlock(from: qualityProfile))

        if let context {
            let trimmedContext = context.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedContext.isEmpty {
                blocks.append(
                    """
                    <CONTEXT_METADATA>
                    \(trimmedContext)
                    </CONTEXT_METADATA>
                    """
                )
            }
        }

        return blocks.joined(separator: "\n\n")
    }

    private func qualityMetadataBlock(from qualityProfile: TranscriptionQualityProfile) -> String {
        let markerLines: [String]
        if qualityProfile.markers.isEmpty {
            markerLines = ["none"]
        } else {
            markerLines = qualityProfile.markers.map { marker in
                "- [\(marker.reason.rawValue)] \(marker.snippet) [\(marker.startTime)-\(marker.endTime)]"
            }
        }

        return """
        <TRANSCRIPT_QUALITY>
        normalizationVersion: \(qualityProfile.normalizationVersion)
        overallConfidence: \(qualityProfile.overallConfidence)
        containsUncertainty: \(qualityProfile.containsUncertainty)
        markers:
        \(markerLines.joined(separator: "\n"))
        </TRANSCRIPT_QUALITY>
        """
    }

    private func recalibrateCanonicalSummary(
        _ summary: CanonicalSummary,
        with qualityProfile: TranscriptionQualityProfile
    ) -> CanonicalSummary {
        let trustFlags = CanonicalSummary.TrustFlags(
            isGroundedInTranscript: summary.trustFlags.isGroundedInTranscript,
            containsSpeculation: summary.trustFlags.containsSpeculation || qualityProfile.containsUncertainty,
            isHumanReviewed: summary.trustFlags.isHumanReviewed,
            confidenceScore: min(summary.trustFlags.confidenceScore, qualityProfile.overallConfidence)
        )

        return CanonicalSummary(
            schemaVersion: summary.schemaVersion,
            generatedAt: summary.generatedAt,
            summary: summary.summary,
            keyPoints: summary.keyPoints,
            decisions: summary.decisions,
            actionItems: summary.actionItems,
            openQuestions: summary.openQuestions,
            trustFlags: trustFlags
        )
    }

    private func updatedMeeting(for meeting: Meeting, audioDuration: Double?) -> Meeting {
        guard let audioDuration else { return meeting }
        guard meeting.endTime == nil else { return meeting }

        var updatedMeeting = meeting
        updatedMeeting.endTime = meeting.startTime.addingTimeInterval(audioDuration)
        return updatedMeeting
    }

    private func resolveInputSourceLabel(for meeting: Meeting) -> String? {
        if meeting.app == .importedFile {
            return "meeting.app.imported".localized
        }

        switch recordingSource {
        case .microphone:
            return resolveMicrophoneDeviceName() ?? "recording.source.microphone".localized
        case .system:
            return "recording.source.system".localized
        case .all:
            let system = "recording.source.system".localized
            let mic = resolveMicrophoneDeviceName()
            if let mic {
                return "\(system) + \(mic)"
            }
            let microphone = "recording.source.microphone".localized
            return "\(system) + \(microphone)"
        }
    }

    private func resolveMicrophoneDeviceName() -> String? {
        let settings = AppSettingsStore.shared

        if settings.useSystemDefaultInput {
            return resolveSystemDefaultMicrophoneDeviceName()
        }

        for uid in settings.audioDevicePriority {
            guard let id = audioDeviceManager.getAudioDeviceID(for: uid) else { continue }
            if let name = audioDeviceManager.getDeviceName(for: id) {
                return name
            }
        }

        return resolveSystemDefaultMicrophoneDeviceName()
    }

    private func resolveSystemDefaultMicrophoneDeviceName() -> String? {
        if let id = audioDeviceManager.getDefaultInputDeviceID(),
           let name = audioDeviceManager.getDeviceName(for: id)
        {
            return name
        }

        if let device = audioDeviceManager.availableInputDevices.first(where: { $0.isDefault }) {
            return device.name
        }

        return nil
    }

    // MARK: - Menu Helpers

    public var dictationMenuKey: String {
        (isRecording && recordingSource == .microphone) ? "menubar.stop_dictation" : "menubar.dictate"
    }

    public var meetingMenuKey: String {
        (isRecording && (recordingSource == .system || recordingSource == .all)) ? "menubar.stop_recording" : "menubar.record_meeting"
    }
}
