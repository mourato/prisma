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

    let audioDeviceManager = AudioDeviceManager()

    // MARK: - Published State

    @Published public var isRecording = false
    @Published public var isStartingRecording = false
    @Published public var isTranscribing = false
    @Published public var meetingState: MeetingState = .idle
    @Published public var currentMeeting: Meeting?
    @Published public var lastError: Error?
    @Published public var hasRequiredPermissions = false
    @Published public var recordingSource: RecordingSource = .microphone
    @Published public var dictationSessionOutputLanguageOverride: DictationOutputLanguage?
    @Published public var postProcessingReadinessWarningIssue: EnhancementsInferenceReadinessIssue?
    @Published public var postProcessingReadinessWarningMode: IntelligenceKernelMode?

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

    let micRecorder: any AudioRecordingService
    let systemRecorder: any AudioRecordingService
    let audioMerger: AudioMerger
    let meetingDetector: MeetingDetector
    let transcriptionClient: any TranscriptionService
    let postProcessingService: any PostProcessingServiceProtocol
    let storage: any StorageService
    let notificationService: NotificationService
    let contextAwarenessService: any ContextAwarenessServiceProtocol
    let textContextProvider: any TextContextProvider
    let textContextGuardrails: TextContextGuardrails
    let textContextPolicy: TextContextPolicy
    let transcribeAudioUseCase: TranscribeAudioUseCase
    let transcriptPreprocessor = TranscriptIntelligencePreprocessor()
    let activeAppContextProvider: any ActiveAppContextProvider
    let apiKeyExists: (AIProvider) -> Bool
    var browserProviders: [String: BrowserActiveTabURLProviding] = BrowserProviderRegistry.defaultProviders()

    var cancellables = Set<AnyCancellable>()
    var statusCheckTask: Task<Void, Never>?
    var isStartOperationInFlight = false
    var postStartContextCaptureTask: Task<Void, Never>?
    var activeStartTelemetry: RecordingStartTelemetry?
    var postProcessingContext: String?
    var postProcessingContextItems: [TranscriptionContextItem] = []
    var activePostProcessingKernelMode: IntelligenceKernelMode?
    var dictationStartBundleIdentifier: String?
    var dictationStartURL: URL?

    struct RecordingStartTelemetry {
        let traceID = UUID().uuidString
        let triggerLabel: String
        let source: RecordingSource
        let requestedAt: Date
        let managerEntryAt: Date
        var recorderStartedAt: Date?
        var indicatorShownAt: Date?
    }

    // MARK: - Constants

    enum Constants {
        static let processingProgress: Double = 10.0
        static let postProcessingProgress: Double = 90.0
        static let aiProcessingProgress: Double = 92.0
        static let statusResetDelay: Int = 3
        static let startContextCaptureTimeout: UInt64 = 1_500_000_000
    }

    private static func defaultTextContextProvider() -> any TextContextProvider {
        AXTextContextProvider(
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
        )
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

    // MARK: - Initialization

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
        textContextProvider: (any TextContextProvider)? = nil,
        textContextGuardrails: TextContextGuardrails = TextContextGuardrails(),
        textContextPolicy: TextContextPolicy = .default,
        activeAppContextProvider: any ActiveAppContextProvider = NSWorkspaceActiveAppContextProvider(),
        apiKeyExists: @escaping (AIProvider) -> Bool = { provider in
            KeychainManager.existsAPIKey(for: provider)
        }
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
        self.textContextProvider = textContextProvider ?? Self.defaultTextContextProvider()
        self.textContextGuardrails = textContextGuardrails
        self.textContextPolicy = textContextPolicy
        self.activeAppContextProvider = activeAppContextProvider
        self.apiKeyExists = apiKeyExists

        // Initialize UseCase with Adapters
        transcribeAudioUseCase = TranscribeAudioUseCase(
            transcriptionRepository: TranscriptionRepositoryAdapter(transcriptionService: transcriptionClient),
            transcriptionStorageRepository: CoreDataTranscriptionStorageRepository(stack: .shared),
            postProcessingRepository: PostProcessingRepositoryAdapter(postProcessingService: postProcessingService)
        )

        setupBindings()
        setupRecorderErrorForwarding()
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

// MARK: - Permissions

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
}

// MARK: - Recording Control

public extension RecordingManager {
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
        activePostProcessingKernelMode = source == .microphone ? .dictation : .meeting
        dictationSessionOutputLanguageOverride = nil
        refreshPostProcessingReadinessWarning(for: source == .microphone ? .dictation : .meeting)

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

        let requestedToIndicatorMs = now.timeIntervalSince(telemetry.requestedAt) * 1_000
        PerformanceMonitor.shared.reportMetric(
            name: "recording_start_requested_to_indicator_ms",
            value: requestedToIndicatorMs,
            unit: "ms"
        )

        if let recorderStartedAt = telemetry.recorderStartedAt {
            let recorderToIndicatorMs = now.timeIntervalSince(recorderStartedAt) * 1_000
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
        AppLogger.debug(
            "Starting recorder",
            category: .recordingManager,
            extra: ["url": url.path, "source": source.rawValue]
        )

        if let recorder = micRecorder as? AudioRecorder {
            try await recorder.startRecording(to: url, source: source, retryCount: 0)
        } else {
            try await micRecorder.startRecording(to: url, retryCount: 0)
        }
    }

    private func createMeeting(type: MeetingType) -> Meeting {
        let app = meetingDetector.detectedMeeting ?? .unknown
        return Meeting(app: app, type: type, state: .recording)
    }

    func applyStartAppContext(
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
        clearPostProcessingReadinessWarning()
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
                clearPostProcessingReadinessWarning()
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
            clearPostProcessingReadinessWarning()
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
            clearPostProcessingReadinessWarning()
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
        clearPostProcessingReadinessWarning()
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
        activePostProcessingKernelMode = .meeting
        refreshPostProcessingReadinessWarning(for: .meeting)

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

// MARK: - Dictation Language

public extension RecordingManager {
    var effectiveDictationOutputLanguageForCurrentRecording: DictationOutputLanguage {
        if let override = dictationSessionOutputLanguageOverride {
            return override
        }

        let settings = AppSettingsStore.shared
        return matchingDictationAppRule(settings: settings)?.outputLanguage ?? .original
    }

    func setDictationSessionOutputLanguageOverride(_ language: DictationOutputLanguage?) {
        dictationSessionOutputLanguageOverride = language
    }
}

// MARK: - Private Helpers

extension RecordingManager {
    private func setupRecorderErrorForwarding() {
        guard let recorder = micRecorder as? AudioRecorder else { return }

        recorder.onRecordingError = { [weak self] error in
            Task { @MainActor [weak self] in
                await self?.handleUnexpectedRecorderFailure(error)
            }
        }
    }

    private func handleUnexpectedRecorderFailure(_ error: Error) async {
        guard isRecording || isStartingRecording else { return }

        AppLogger.error(
            "Recorder reported an unexpected runtime failure",
            category: .recordingManager,
            error: error
        )

        postStartContextCaptureTask?.cancel()
        postStartContextCaptureTask = nil
        isRecording = false
        isStartingRecording = false
        isTranscribing = false
        meetingState = .failed(error.localizedDescription)
        currentMeeting?.state = .failed(error.localizedDescription)
        currentMeeting = nil
        postProcessingContext = nil
        postProcessingContextItems = []
        dictationSessionOutputLanguageOverride = nil
        activeStartTelemetry = nil
        clearPostProcessingReadinessWarning()
        lastError = error
        await RecordingExclusivityCoordinator.shared.endRecording()
    }

    private func setupBindings() {
        // Sync with audio recorder state
        micRecorder.isRecordingPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRecording in
                guard let self else { return }
                self.isRecording = isRecording
                if isRecording {
                    isStartingRecording = false
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
            value: recorderStartedAt.timeIntervalSince(telemetry.requestedAt) * 1_000,
            unit: "ms"
        )
        PerformanceMonitor.shared.reportMetric(
            name: "recording_start_entry_to_recorder_ms",
            value: recorderStartedAt.timeIntervalSince(telemetry.managerEntryAt) * 1_000,
            unit: "ms"
        )
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

                if singleURL == outputURL {
                    await cleanupTemporaryFiles()
                    return outputURL
                }

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

// MARK: - Status Monitoring

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
        clearPostProcessingReadinessWarning()
    }
}

// MARK: - Menu Helpers

public extension RecordingManager {
    var dictationMenuKey: String {
        (isRecording && recordingSource == .microphone) ? "menubar.stop_dictation" : "menubar.dictate"
    }

    var meetingMenuKey: String {
        (isRecording && (recordingSource == .system || recordingSource == .all)) ? "menubar.stop_recording" : "menubar.record_meeting"
    }
}
