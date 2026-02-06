import AVFoundation
import Combine
import Foundation
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
    @Published public private(set) var isTranscribing = false
    @Published public private(set) var meetingState: MeetingState = .idle
    @Published public private(set) var currentMeeting: Meeting?
    @Published public private(set) var lastError: Error?
    @Published public private(set) var hasRequiredPermissions = false
    @Published public private(set) var recordingSource: RecordingSource = .microphone

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
    private let transcribeAudioUseCase: TranscribeAudioUseCase

    private var cancellables = Set<AnyCancellable>()
    private var statusCheckTask: Task<Void, Never>?
    private var isStarting = false

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
        notificationService: NotificationService = .shared
    ) {
        self.micRecorder = micRecorder
        self.systemRecorder = systemRecorder
        self.transcriptionClient = transcriptionClient
        self.postProcessingService = postProcessingService
        self.audioMerger = audioMerger
        self.meetingDetector = meetingDetector
        self.storage = storage
        self.notificationService = notificationService
        
        // Initialize UseCase with Adapters
        self.transcribeAudioUseCase = TranscribeAudioUseCase(
            transcriptionRepository: TranscriptionRepositoryAdapter(transcriptionService: transcriptionClient),
            transcriptionStorageRepository: TranscriptionStorageRepositoryAdapter(storageService: storage),
            postProcessingRepository: PostProcessingRepositoryAdapter(postProcessingService: postProcessingService)
        )

        setupBindings()
        notificationService.requestAuthorization()
        Task { @Sendable [weak self] in
            await self?.checkPermission()
            if self?.isRunningAsAppBundle == true {
                await self?.startStatusMonitoring()
            }
            await self?.syncStateFromActor()
        }
    }

    /// Sincroniza o estado local com o estado do actor (para inicialização).
    private func syncStateFromActor() async {
        isRecording = await recordingActor.recordingState
        isTranscribing = await recordingActor.transcribingState
        currentMeeting = await recordingActor.currentMeetingState
        lastError = await recordingActor.lastErrorState
        hasRequiredPermissions = await recordingActor.permissionsState
    }

    // ...

    /// Check if running as a proper app bundle (required for UNUserNotificationCenter).
    private var isRunningAsAppBundle: Bool {
        guard let bundleId = Bundle.main.bundleIdentifier else { return false }
        return !bundleId.lowercased().contains("xctest")
    }

    public func checkPermission() async {
        await checkPermission(for: recordingSource)
    }

    public func checkPermission(for source: RecordingSource) async {
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
    public func requestPermission() async {
        await requestPermission(for: recordingSource)
    }

    public func requestPermission(for source: RecordingSource) async {
        if source.requiresMicrophonePermission {
            await micRecorder.requestPermission()
        }
        if source.requiresScreenRecordingPermission {
            await systemRecorder.requestPermission()
        }
        await checkPermission(for: source)
    }

    /// Open System Preferences to Screen Recording settings.
    public func openPermissionSettings() {
        systemRecorder.openSettings()
    }

    /// Open System Preferences to Microphone settings.
    public func openMicrophoneSettings() {
        micRecorder.openSettings()
    }

    public func requestAccessibilityPermission() {
        AccessibilityPermissionService.requestPermission()
        permissionStatus.updateAccessibilityState(AccessibilityPermissionService.currentState())
    }

    public func openAccessibilitySettings() {
        AccessibilityPermissionService.openSystemSettings()
    }

    // MARK: - Public API

    /// Start recording audio for a meeting.
    /// - Parameters:
    ///   - source: The audio source to record.
    ///   - type: The type of meeting (defaults to .general for backward compatibility).
    public func startRecording(source: RecordingSource = .microphone, type: MeetingType = .general) async {
        guard !isRecording else {
            AppLogger.info("Attempted to start recording but already recording", category: .recordingManager)
            return
        }

        guard await RecordingExclusivityCoordinator.shared.beginRecording() else {
            AppLogger.info("Recording start blocked by exclusivity coordinator", category: .recordingManager)
            return
        }

        recordingSource = source

        // Prevent re-entrancy during async setup
        guard !isStarting else { return }
        isStarting = true
        defer { isStarting = false }

        do {
            let meeting = createMeeting(type: type)
            currentMeeting = meeting

            // We only need one output URL because AudioRecorder handles mixing
            let audioURL = storage.createRecordingURL(for: meeting, type: .merged)
            setMergedAudioURL(audioURL)
            let outputURL = audioURL
            try await startRecorder(to: outputURL, source: source)

            isRecording = true
            meetingState = .recording // Sync state
            currentMeeting?.state = .recording // Sync entity state
            currentMeeting?.audioFilePath = outputURL.path

            // Play start recording sound feedback
            SoundFeedbackService.shared.playRecordingStartSound()

            AppLogger.info("Recording started successfully", category: .recordingManager, extra: [
                "app": meeting.app.displayName,
                "url": outputURL.lastPathComponent,
                "source": source.rawValue,
            ])

        } catch {
            await RecordingExclusivityCoordinator.shared.endRecording()
            await handleStartRecordingError(error)
        }
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
        lastError = error

        // Cleanup partial starts
        _ = await micRecorder.stopRecording()
        _ = await systemRecorder.stopRecording()

        currentMeeting = nil
    }

    /// Stop recording and optionally transcribe.
    public func stopRecording() async {
        await stopRecording(transcribe: true)
    }

    public func stopRecording(transcribe: Bool = true) async {
        guard isRecording else {
            AppLogger.info("Attempted to stop recording but not recording", category: .recordingManager)
            return
        }

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
                currentMeeting = nil // Clear current meeting if done
            }

        } catch {
            AppLogger.error("Failed to stop recording cleanly", category: .recordingManager, error: error)
            lastError = error
            isRecording = false
            isTranscribing = false
            meetingState = .failed(error.localizedDescription) // Sync state
            currentMeeting?.state = .failed(error.localizedDescription) // Sync entity state
            await RecordingExclusivityCoordinator.shared.endRecording()
        }
    }

    /// Cancel recording and discard audio files.
    public func cancelRecording() async {
        guard isRecording else { return }

        AppLogger.info("Cancelling recording...", category: .recordingManager)

        // Stop recorders
        _ = await micRecorder.stopRecording()
        _ = await systemRecorder.stopRecording()

        // Cleanup temporary files
        await cleanupTemporaryFiles()

        // Also cleanup merged file if it exists
        if let mergedURL = await getMergedAudioURL() {
            try? FileManager.default.removeItem(at: mergedURL)
            setMergedAudioURL(nil)
        }

        // Reset state
        isRecording = false
        currentMeeting = nil
        await RecordingExclusivityCoordinator.shared.endRecording()

        AppLogger.info("Recording cancelled and files discarded", category: .recordingManager)
    }

    /// Transcribe an externally recorded audio file.
    /// - Parameter audioURL: Path to the audio file (m4a, mp3, wav).
    public func transcribeExternalAudio(from audioURL: URL) async {
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
    func enableAutoRecording() {
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

    // MARK: - Private Methods

    private func setupBindings() {
        // Sync with audio recorder state
        micRecorder.isRecordingPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$isRecording)
    }

    private func cleanupTemporaryFiles() async {
        var urlsToDelete: [URL] = []
        if let micURL = await getMicAudioURL() { urlsToDelete.append(micURL) }
        if let sysURL = await getSystemAudioURL() { urlsToDelete.append(sysURL) }

        storage.cleanupTemporaryFiles(urls: urlsToDelete)

        setMicAudioURL(nil)
        setSystemAudioURL(nil)
    }

    private enum Constants {
        static let processingProgress: Double = 10.0
        static let postProcessingProgress: Double = 90.0
        static let aiProcessingProgress: Double = 92.0
        static let statusResetDelay: Int = 3
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

    private func transcribeRecording(audioURL: URL, meeting: Meeting) async {
        // isTranscribing is already set by stopRecording to bridge the UI gap
        if !isTranscribing {
            isTranscribing = true
            meetingState = .processing(.transcribing)
            currentMeeting?.state = .processing(.transcribing)
        }

        let audioDuration = await getAudioDuration(from: audioURL)
        transcriptionStatus.beginTranscription(audioDuration: audioDuration)

        do {
            try await performHealthCheck()

            let transcriptionStart = Date()
            
            // Prepare UseCase arguments
            let settings = AppSettingsStore.shared
            var meetingEntity = MeetingEntity(
                id: meeting.id,
                app: DomainMeetingApp(rawValue: meeting.app.rawValue) ?? .unknown,
                startTime: meeting.startTime,
                endTime: meeting.endTime,
                audioFilePath: meeting.audioFilePath
            )
            // Ensure endTime is set if missing (sanity logic from legacy)
            if meetingEntity.endTime == nil, let duration = audioDuration {
                meetingEntity.endTime = meetingEntity.startTime.addingTimeInterval(duration)
            }
            
            let applyPostProcessing = settings.postProcessingEnabled && settings.aiConfiguration.isValid
            let isDictation = meeting.isDictation || recordingSource == .microphone
            
            // Prepare Prompts
            let builtInMeetingPrompts: [PostProcessingPrompt] = [
                .standup,
                .presentation,
                .designReview,
                .oneOnOne,
                .planning,
            ]

            let availablePrompts: [DomainPostProcessingPrompt] = {
                guard !isDictation else { return [] }

                return (builtInMeetingPrompts + settings.meetingPrompts).map { prompt in
                    DomainPostProcessingPrompt(
                        id: prompt.id,
                        title: prompt.title,
                        content: prompt.promptText,
                        isDefault: false
                    )
                }
            }()

            func domainPrompt(from prompt: PostProcessingPrompt) -> DomainPostProcessingPrompt {
                DomainPostProcessingPrompt(
                    id: prompt.id,
                    title: prompt.title,
                    content: prompt.promptText,
                    isDefault: false
                )
            }

            let promptToUse: DomainPostProcessingPrompt? = {
                guard applyPostProcessing else { return nil }

                // Dictation: always use the dictation prompt set.
                if isDictation {
                    let prompt = settings.selectedDictationPrompt ?? .cleanTranscription
                    return domainPrompt(from: prompt)
                }

                // Meetings:
                // - If the meeting type is explicitly `.autodetect`, do NOT pass a fixed prompt so the UseCase can classify.
                // - If a concrete meeting type was chosen, use the built-in type prompt.
                // - Otherwise (general), respect the user's selected meeting prompt when present.
                switch meeting.type {
                case .autodetect:
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
                    if let selected = settings.selectedPrompt {
                        return domainPrompt(from: selected)
                    }
                    return nil
                }
            }()
            
            meetingState = .processing(.transcribing)
            
            // Execute UseCase
            let transcriptionEntity = try await transcribeAudioUseCase.execute(
                audioURL: audioURL,
                meeting: meetingEntity,
                inputSource: resolveInputSourceLabel(for: meeting),
                applyPostProcessing: applyPostProcessing,
                postProcessingPrompt: promptToUse,
                postProcessingModel: applyPostProcessing ? settings.aiConfiguration.selectedModel : nil,
                availablePrompts: availablePrompts
            )
            
            // Convert to Model (Transcription) for Legacy UI/Notification
            // (We could improve this mapping later or move UI to use Entities)
            let transcription = convertToModel(transcriptionEntity, audioDuration: audioDuration, transcriptionStart: transcriptionStart)
            
            // Update State
            meetingState = .processing(.generatingOutput)
            currentMeeting?.state = .completed
            
            // Handling UI status updates during "execute" is skipped for now (0->100 jump),
            // but we update success here.
            
            // Deliver
            TranscriptionDeliveryService.deliver(transcription: transcription)

            transcriptionStatus.completeTranscription(success: true)
            notifySuccess(for: transcription)
            scheduleStatusReset()
            
            // Export Summary if enabled
            if settings.autoExportSummaries {
                 await exportSummary(transcription: transcription)
            }

        } catch {
            handleTranscriptionError(error)
            meetingState = .failed(error.localizedDescription)
            currentMeeting?.state = .failed(error.localizedDescription)
        }

        isTranscribing = false
        meetingState = .idle
        currentMeeting = nil
    }
    
    private func exportSummary(transcription: Transcription) async {
        let settings = AppSettingsStore.shared
        guard let folder = settings.summaryExportFolder else { return }

        let template = settings.summaryTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !template.isEmpty else { return }

        let isAccessing = folder.startAccessingSecurityScopedResource()
        guard isAccessing else {
            AppLogger.error("Failed to access export folder security-scoped resource", category: .recordingManager)
            return
        }
        defer { folder.stopAccessingSecurityScopedResource() }

        let renderer = MarkdownRenderer()
        let content = renderer.renderWithTemplate(template, meeting: transcription.meeting, transcription: transcription)

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = .current
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFormatter.string(from: transcription.meeting.startTime)

        let meetingTitle: String = {
            let raw = transcription.meeting.type.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            if let range = raw.range(of: " (") {
                return String(raw[..<range.lowerBound])
            }
            return raw
        }()

        let safeTitle = meetingTitle
            .components(separatedBy: CharacterSet(charactersIn: "/\\?%*|\"<>:"))
            .joined(separator: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")

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
         return Transcription(
             id: entity.id,
             meeting: Meeting(
                 id: entity.meeting.id,
                 app: MeetingApp(rawValue: entity.meeting.app.rawValue) ?? .unknown,
                 type: MeetingType(rawValue: entity.meetingType ?? "") ?? .general, // Map back
                 startTime: entity.meeting.startTime,
                 endTime: entity.meeting.endTime,
                 audioFilePath: entity.meeting.audioFilePath
             ),
             segments: entity.segments.map { Transcription.Segment(id: $0.id, speaker: $0.speaker, text: $0.text, startTime: $0.startTime, endTime: $0.endTime) },
             text: entity.text,
             rawText: entity.rawText,
             processedContent: entity.processedContent,
             postProcessingPromptId: entity.postProcessingPromptId,
             postProcessingPromptTitle: entity.postProcessingPromptTitle,
             language: entity.language,
             createdAt: entity.createdAt,
             modelName: entity.modelName,
             inputSource: entity.inputSource, // Entity might not have inputSource? check config
             transcriptionDuration: entity.transcriptionDuration, // Entity has it?
             postProcessingDuration: entity.postProcessingDuration,
             postProcessingModel: entity.postProcessingModel
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
        transcriptionStatus.updateProgress(
            phase: .processing, percentage: Constants.processingProgress
        )
        return try await transcriptionClient.transcribe(
            audioURL: audioURL,
            onProgress: { [weak self] percentage in
                Task { @MainActor in
                    self?.transcriptionStatus.updateProgress(
                        phase: .processing,
                        percentage: percentage
                    )
                }
            }
        )
    }

    private struct PostProcessingResult {
        let processedContent: String?
        let promptId: UUID?
        let promptTitle: String?
        let duration: Double
        let model: String?
    }

    private func applyPostProcessing(rawText: String, meeting: Meeting?) async -> PostProcessingResult {
        transcriptionStatus.updateProgress(
            phase: .postProcessing, percentage: Constants.postProcessingProgress
        )

        let settings = AppSettingsStore.shared
        guard settings.postProcessingEnabled,
              settings.aiConfiguration.isValid
        else {
            return PostProcessingResult(
                processedContent: nil,
                promptId: nil,
                promptTitle: nil,
                duration: 0,
                model: nil
            )
        }

        // Context-Aware Prompt Selection
        // We prioritize the strategy for the specific meeting type.
        // If the type is general, we fall back to the user's selected prompt in settings,
        // or the default strategy if none is selected.
        let type = meeting?.type ?? currentMeeting?.type ?? .general
        let prompt: PostProcessingPrompt

        if meeting?.isDictation == true || recordingSource == .microphone {
            prompt = settings.selectedDictationPrompt ?? .cleanTranscription
        } else if type != .general, type != .autodetect {
            let strategy = PromptService.shared.strategy(for: type)
            prompt = strategy.promptObject()
            AppLogger.info("Using context-aware prompt for type: \(type.displayName)", category: .transcriptionEngine)
        } else {
            prompt = settings.selectedPrompt ?? PromptService.shared.strategy(for: .general).promptObject()
        }

        transcriptionStatus.updateProgress(
            phase: .postProcessing, percentage: Constants.aiProcessingProgress
        )

        do {
            let startTime = Date()
            let processed = try await postProcessingService.processTranscription(
                rawText, with: prompt
            )
            let duration = Date().timeIntervalSince(startTime)
            let model = settings.aiConfiguration.selectedModel
            AppLogger.info("Post-processing complete", category: .recordingManager, extra: ["prompt": prompt.title])
            return PostProcessingResult(
                processedContent: processed,
                promptId: prompt.id,
                promptTitle: prompt.title,
                duration: duration,
                model: model
            )
        } catch {
            AppLogger.error(
                "Post-processing failed, using raw transcription",
                category: .recordingManager,
                error: error
            )
            return PostProcessingResult(
                processedContent: nil,
                promptId: nil,
                promptTitle: nil,
                duration: 0,
                model: nil
            )
        }
    }

    private func createAndSaveTranscription(
        meeting: Meeting,
        response: TranscriptionResponse,
        inputSource: String,
        transcriptionDuration: Double,
        postProcessing: PostProcessingResult
    ) async throws -> Transcription {
        let transcription = Transcription(
            meeting: meeting,
            text: postProcessing.processedContent ?? response.text,
            rawText: response.text,
            processedContent: postProcessing.processedContent,
            postProcessingPromptId: postProcessing.promptId,
            postProcessingPromptTitle: postProcessing.promptTitle,
            language: response.language,
            modelName: response.model,
            inputSource: inputSource,
            transcriptionDuration: transcriptionDuration,
            postProcessingDuration: postProcessing.duration,
            postProcessingModel: postProcessing.model
        )

        let logMessageSuffix =
            transcription.isPostProcessed
                ? "post-processed" : "raw"
        AppLogger.info(
            "Transcription created",
            category: .recordingManager,
            extra: ["words": transcription.wordCount, "type": logMessageSuffix]
        )

        try await storage.saveTranscription(transcription)
        NotificationCenter.default.post(
            name: .meetingAssistantTranscriptionSaved,
            object: nil,
            userInfo: [AppNotifications.UserInfoKey.transcriptionId: transcription.id]
        )
        return transcription
    }

    private func notifySuccess(for transcription: Transcription) {
        let suffix =
            transcription.isPostProcessed
                ? NSLocalizedString("notification.transcription_processed", bundle: .safeModule, comment: "")
                : NSLocalizedString("notification.transcription_transcribed", bundle: .safeModule, comment: "")
        let body = String(
            format: NSLocalizedString("notification.transcription_body", bundle: .safeModule, comment: ""),
            transcription.meeting.appName,
            transcription.wordCount,
            suffix
        )

        notificationService.sendNotification(
            title: NSLocalizedString("notification.transcription_completed", bundle: .safeModule, comment: ""),
            body: body
        )
    }

    private func handleTranscriptionError(_ error: Error) {
        AppLogger.error("Transcription failed", category: .recordingManager, error: error)
        lastError = error

        transcriptionStatus.recordError(.transcriptionFailed(error.localizedDescription))
        transcriptionStatus.completeTranscription(success: false)

        notificationService.sendNotification(
            title: NSLocalizedString("notification.transcription_failed", bundle: .safeModule, comment: ""),
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

    /// Start periodic status monitoring.
    private func startStatusMonitoring() async {
        statusCheckTask?.cancel()

        statusCheckTask = Task { @Sendable @MainActor [weak self] in
            while !Task.isCancelled {
                await self?.checkServiceStatus()
                try? await Task.sleep(for: .seconds(5))
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
        await recordingActor.reset()
        isRecording = false
        isTranscribing = false
        currentMeeting = nil
        lastError = nil
    }

    deinit {
        AppLogger.debug("RecordingManager deinitialized", category: .recordingManager)
    }
}

// MARK: - Errors

public enum RecordingManagerError: LocalizedError {
    case noOutputPath
    case mergeFailed(Error)
    case noInputFiles

    public var errorDescription: String? {
        switch self {
        case .noOutputPath:
            "No output path specified for merged audio"
        case let .mergeFailed(error):
            "Audio merge failed: \(error.localizedDescription)"
        case .noInputFiles:
            "No audio files recorded"
        }
    }
}

public enum AudioImportError: LocalizedError {
    case fileNotFound
    case unsupportedFormat

    public var errorDescription: String? {
        switch self {
        case .fileNotFound:
            "Audio file not found"
        case .unsupportedFormat:
            "Unsupported audio format. Supported formats: m4a, mp3, wav"
        }
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
            AppLogger.error(
                "Audio file missing for retry",
                category: .recordingManager,
                extra: ["id": transcription.id.uuidString]
            )
            lastError = AudioImportError.fileNotFound
            return nil
        }

        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            AppLogger.error(
                "Audio file not found for retry",
                category: .recordingManager,
                extra: ["path": audioURL.path]
            )
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

        let meeting = updatedMeeting(for: transcription.meeting, audioDuration: audioDuration)
        let postProcessing = await applyPostProcessing(rawText: response.text, meeting: meeting)

        return Transcription(
            id: transcription.id,
            meeting: meeting,
            segments: response.segments,
            text: postProcessing.processedContent ?? response.text,
            rawText: response.text,
            processedContent: postProcessing.processedContent,
            postProcessingPromptId: postProcessing.promptId,
            postProcessingPromptTitle: postProcessing.promptTitle,
            language: response.language,
            createdAt: transcription.createdAt,
            modelName: response.model,
            inputSource: transcription.inputSource,
            transcriptionDuration: transcriptionProcessingDuration,
            postProcessingDuration: postProcessing.duration,
            postProcessingModel: postProcessing.model
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
            return NSLocalizedString("meeting.app.imported", bundle: .safeModule, comment: "Imported File")
        }

        switch recordingSource {
        case .microphone:
            return resolveMicrophoneDeviceName() ?? NSLocalizedString("recording.source.microphone", bundle: .safeModule, comment: "Microphone")
        case .system:
            return NSLocalizedString("recording.source.system", bundle: .safeModule, comment: "System Audio")
        case .all:
            let system = NSLocalizedString("recording.source.system", bundle: .safeModule, comment: "System Audio")
            let mic = resolveMicrophoneDeviceName()
            if let mic {
                return "\(system) + \(mic)"
            }
            let microphone = NSLocalizedString("recording.source.microphone", bundle: .safeModule, comment: "Microphone")
            return "\(system) + \(microphone)"
        }
    }

    private func resolveMicrophoneDeviceName() -> String? {
        let settings = AppSettingsStore.shared

        if settings.useSystemDefaultInput {
            return resolveSystemDefaultMicrophoneDeviceName()
        }

        for uid in settings.audioDevicePriority {
            guard audioDeviceManager.isDeviceAvailable(uid) else { continue }
            guard let id = audioDeviceManager.getAudioDeviceID(for: uid) else { continue }
            if let name = audioDeviceManager.getDeviceName(for: id) {
                return name
            }
        }

        return resolveSystemDefaultMicrophoneDeviceName()
    }

    private func resolveSystemDefaultMicrophoneDeviceName() -> String? {
        if let id = audioDeviceManager.getDefaultInputDeviceID(),
           let name = audioDeviceManager.getDeviceName(for: id) {
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
