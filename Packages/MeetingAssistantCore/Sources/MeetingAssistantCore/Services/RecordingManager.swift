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

    // MARK: - Published State

    @Published public private(set) var isRecording = false
    @Published public private(set) var isTranscribing = false
    @Published public private(set) var currentMeeting: Meeting?
    @Published public private(set) var lastError: Error?
    @Published public private(set) var hasRequiredPermissions = false

    // MARK: - Protocol Publishers

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

    private var cancellables = Set<AnyCancellable>()
    private var statusCheckTask: Task<Void, Never>?

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

        setupBindings()
        notificationService.requestAuthorization()
        Task { @Sendable [weak self] in
            await self?.checkPermission()
            await self?.startStatusMonitoring()
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
        let micPermission = await micRecorder.hasPermission()
        let screenPermission = await systemRecorder.hasPermission()

        // Update individual permission states using detailed state methods
        let micState = micRecorder.getPermissionState()
        let screenState = systemRecorder.getPermissionState()

        permissionStatus.updateMicrophoneState(micState)
        permissionStatus.updateScreenRecordingState(screenState)

        await recordingActor.setPermissions(micPermission && screenPermission)
        hasRequiredPermissions = await recordingActor.permissionsState
    }

    /// Request permissions (Screen Recording + Microphone).
    public func requestPermission() async {
        await micRecorder.requestPermission()
        await systemRecorder.requestPermission()
        await checkPermission()
    }

    /// Open System Preferences to Screen Recording settings.
    public func openPermissionSettings() {
        systemRecorder.openSettings()
    }

    /// Open System Preferences to Microphone settings.
    public func openMicrophoneSettings() {
        micRecorder.openSettings()
    }

    // MARK: - Public API

    /// Start recording audio for a meeting.
    /// - Parameter source: The audio source to record.
    public func startRecording(source: RecordingSource = .all) async {
        guard !isRecording else {
            AppLogger.info("Attempted to start recording but already recording", category: .recordingManager)
            return
        }

        do {
            let meeting = createMeeting()
            currentMeeting = meeting

            // We only need one output URL because AudioRecorder handles mixing
            let audioURL = storage.createRecordingURL(for: meeting, type: .merged)
            setMergedAudioURL(audioURL)
            let outputURL = audioURL

            // guard let outputURL = audioURL else {
            //    throw RecordingManagerError.noOutputPath
            // }

            try await startRecorder(to: outputURL, source: source)

            isRecording = true
            currentMeeting?.audioFilePath = outputURL.path

            AppLogger.info("Recording started successfully", category: .recordingManager, extra: [
                "app": meeting.app.displayName,
                "url": outputURL.lastPathComponent,
                "source": source.rawValue,
            ])

        } catch {
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

    private func createMeeting() -> Meeting {
        let app = meetingDetector.detectedMeeting ?? .unknown
        return Meeting(app: app)
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
            isRecording = false

            AppLogger.info("Recording stopped", category: .recordingManager, extra: [
                "micURL": micURL?.lastPathComponent ?? "nil",
                "sysURL": sysURL?.lastPathComponent ?? "nil",
            ])

            let finalURL = try await processRecordedAudio(micURL: micURL, sysURL: sysURL)

            // Transcribe if requested
            if transcribe, let meeting = currentMeeting {
                await transcribeRecording(audioURL: finalURL, meeting: meeting)
            }

        } catch {
            AppLogger.error("Failed to stop recording cleanly", category: .recordingManager, error: error)
            lastError = error
            isRecording = false
        }
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
                        await self?.startRecording()
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
            AppLogger.info("Merging audio files...", category: .recordingManager)
            var inputURLs: [URL] = []
            if let micURL { inputURLs.append(micURL) }
            if let sysURL { inputURLs.append(sysURL) }

            let finalURL = try await audioMerger.mergeAudioFiles(
                inputURLs: inputURLs,
                to: outputURL,
                format: settings.audioFormat
            )

            await cleanupTemporaryFiles()
            AppLogger.info(
                "Audio merge complete",
                category: .recordingManager,
                extra: ["finalURL": finalURL.lastPathComponent]
            )
            return finalURL
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
        isTranscribing = true
        let audioDuration = await getAudioDuration(from: audioURL)
        transcriptionStatus.beginTranscription(audioDuration: audioDuration)

        do {
            try await performHealthCheck()

            let response = try await performTranscription(audioURL: audioURL)
            let (processedContent, promptId, promptTitle) = await applyPostProcessing(
                rawText: response.text)

            let transcription = try await createAndSaveTranscription(
                meeting: meeting,
                response: response,
                processedContent: processedContent,
                promptId: promptId,
                promptTitle: promptTitle
            )

            transcriptionStatus.completeTranscription(success: true)
            notifySuccess(for: transcription)
            scheduleStatusReset()

        } catch {
            handleTranscriptionError(error)
        }

        isTranscribing = false
        currentMeeting = nil
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

    private func applyPostProcessing(rawText: String) async -> (String?, UUID?, String?) {
        transcriptionStatus.updateProgress(
            phase: .postProcessing, percentage: Constants.postProcessingProgress
        )

        let settings = AppSettingsStore.shared
        guard settings.postProcessingEnabled,
              settings.aiConfiguration.isValid,
              let prompt = settings.selectedPrompt
        else {
            return (nil, nil, nil)
        }

        transcriptionStatus.updateProgress(
            phase: .postProcessing, percentage: Constants.aiProcessingProgress
        )

        do {
            let processed = try await postProcessingService.processTranscription(
                rawText, with: prompt
            )
            AppLogger.info("Post-processing complete", category: .recordingManager, extra: ["prompt": prompt.title])
            return (processed, prompt.id, prompt.title)
        } catch {
            AppLogger.error(
                "Post-processing failed, using raw transcription",
                category: .recordingManager,
                error: error
            )
            return (nil, nil, nil)
        }
    }

    private func createAndSaveTranscription(
        meeting: Meeting,
        response: TranscriptionResponse,
        processedContent: String?,
        promptId: UUID?,
        promptTitle: String?
    ) async throws -> Transcription {
        let transcription = Transcription(
            meeting: meeting,
            text: processedContent ?? response.text,
            rawText: response.text,
            processedContent: processedContent,
            postProcessingPromptId: promptId,
            postProcessingPromptTitle: promptTitle,
            language: response.language,
            modelName: response.model
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
        return transcription
    }

    private func notifySuccess(for transcription: Transcription) {
        let suffix =
            transcription.isPostProcessed
                ? "(\(transcription.postProcessingPromptTitle ?? "processado"))" : "transcritas"
        let body = "\(transcription.meeting.appName): \(transcription.wordCount) palavras \(suffix)"

        notificationService.sendNotification(title: "Transcrição Concluída", body: body)
    }

    private func handleTranscriptionError(_ error: Error) {
        AppLogger.error("Transcription failed", category: .recordingManager, error: error)
        lastError = error

        transcriptionStatus.recordError(.transcriptionFailed(error.localizedDescription))
        transcriptionStatus.completeTranscription(success: false)

        notificationService.sendNotification(
            title: "Falha na Transcrição", body: error.localizedDescription
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
