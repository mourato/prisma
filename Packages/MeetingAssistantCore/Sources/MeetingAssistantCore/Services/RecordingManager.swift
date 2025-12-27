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

    // private let logger = Logger(subsystem: "MeetingAssistant", category: "RecordingManager") // Replaced by AppLogger

    // MARK: - Published State

    @Published public private(set) var isRecording = false
    @Published public private(set) var isTranscribing = false
    @Published public private(set) var currentMeeting: Meeting?
    @Published public private(set) var lastError: Error?
    @Published public private(set) var hasRequiredPermissions = false

    // MARK: - Protocol Publishers

    public var isRecordingPublisher: AnyPublisher<Bool, Never> {
        self.$isRecording.eraseToAnyPublisher()
    }

    public var isTranscribingPublisher: AnyPublisher<Bool, Never> {
        self.$isTranscribing.eraseToAnyPublisher()
    }

    public var currentMeetingPublisher: AnyPublisher<Meeting?, Never> {
        self.$currentMeeting.eraseToAnyPublisher()
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

    // MARK: - Recording URLs

    private var micAudioURL: URL?
    private var systemAudioURL: URL?
    private var mergedAudioURL: URL?

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

        self.setupBindings()
        notificationService.requestAuthorization()
        Task { [weak self] in
            await self?.checkPermission()
            await self?.startStatusMonitoring()
        }
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
        let micState = self.micRecorder.getPermissionState()
        let screenState = self.systemRecorder.getPermissionState()

        self.permissionStatus.updateMicrophoneState(micState)
        self.permissionStatus.updateScreenRecordingState(screenState)

        self.hasRequiredPermissions = micPermission && screenPermission
    }

    /// Request permissions (Screen Recording + Microphone).
    public func requestPermission() async {
        await self.micRecorder.requestPermission()
        await self.systemRecorder.requestPermission()
        await self.checkPermission()
    }

    /// Open System Preferences to Screen Recording settings.
    public func openPermissionSettings() {
        self.systemRecorder.openSettings()
    }

    /// Open System Preferences to Microphone settings.
    public func openMicrophoneSettings() {
        self.micRecorder.openSettings()
    }

    // MARK: - Public API

    /// Start recording audio for a meeting (both microphone and system audio).
    public func startRecording() async {
        guard !self.isRecording else {
            AppLogger.info("Attempted to start recording but already recording", category: .recordingManager)
            return
        }

        do {
            let meeting = self.createMeeting()
            self.currentMeeting = meeting

            let (micURL, systemURL) = try self.generateRecordingPaths(for: meeting)

            try await self.startRecorders(micURL: micURL, systemURL: systemURL)

            self.isRecording = true
            self.currentMeeting?.audioFilePath = self.mergedAudioURL?.path

            AppLogger.info("Recording started successfully", category: .recordingManager, extra: [
                "app": meeting.app.displayName,
                "micURL": micURL.lastPathComponent,
                "systemURL": systemURL.lastPathComponent,
            ])

        } catch {
            await self.handleStartRecordingError(error)
        }
    }

    private func createMeeting() -> Meeting {
        let app = self.meetingDetector.detectedMeeting ?? .unknown
        return Meeting(app: app)
    }

    private func generateRecordingPaths(for meeting: Meeting) throws -> (URL, URL) {
        self.micAudioURL = self.storage.createRecordingURL(for: meeting, type: .microphone)
        self.systemAudioURL = self.storage.createRecordingURL(for: meeting, type: .system)
        self.mergedAudioURL = self.storage.createRecordingURL(for: meeting, type: .merged)

        guard let micURL = micAudioURL, let systemURL = systemAudioURL else {
            throw RecordingManagerError.noOutputPath
        }
        return (micURL, systemURL)
    }

    private func startRecorders(micURL: URL, systemURL: URL) async throws {
        // Start microphone recording
        AppLogger.debug("Starting microphone recording", category: .recordingManager, extra: ["url": micURL.path])
        try await self.micRecorder.startRecording(to: micURL, retryCount: 0)

        // Start system audio recording
        AppLogger.debug("Starting system audio recording", category: .recordingManager, extra: ["url": systemURL.path])
        try await self.systemRecorder.startRecording(to: systemURL, retryCount: 0)
    }

    private func handleStartRecordingError(_ error: Error) async {
        AppLogger.fault("CRITICAL: Failed to start recording", category: .recordingManager, error: error, extra: ["state": "start_failed"])
        self.lastError = error

        // Cleanup partial starts
        _ = await self.micRecorder.stopRecording()
        _ = await self.systemRecorder.stopRecording()

        self.currentMeeting = nil
    }

    /// Stop recording and optionally transcribe.
    public func stopRecording() async {
        await self.stopRecording(transcribe: true)
    }

    public func stopRecording(transcribe: Bool = true) async {
        guard self.isRecording else {
            AppLogger.info("Attempted to stop recording but not recording", category: .recordingManager)
            return
        }

        do {
            // Stop both recorders
            let micURL = await micRecorder.stopRecording()
            let sysURL = await systemRecorder.stopRecording()

            // Update meeting
            self.currentMeeting?.endTime = Date()
            self.isRecording = false

            AppLogger.info("Recording stopped, merging audio files...", category: .recordingManager, extra: [
                "micURL": micURL?.lastPathComponent ?? "nil",
                "sysURL": sysURL?.lastPathComponent ?? "nil",
            ])

            // Merge audio files
            var inputURLs: [URL] = []
            if let micURL { inputURLs.append(micURL) }
            if let sysURL { inputURLs.append(sysURL) }

            guard let outputURL = mergedAudioURL else {
                throw RecordingManagerError.noOutputPath
            }

            let finalURL = try await audioMerger.mergeAudioFiles(
                inputURLs: inputURLs, to: outputURL
            )

            // Clean up temporary files
            self.cleanupTemporaryFiles()

            AppLogger.info("Audio merge complete", category: .recordingManager, extra: ["finalURL": finalURL.lastPathComponent])

            // Transcribe if requested
            if transcribe, let meeting = currentMeeting {
                await self.transcribeRecording(audioURL: finalURL, meeting: meeting)
            }

        } catch {
            AppLogger.error("Failed to stop recording cleanly", category: .recordingManager, error: error)
            self.lastError = error
            self.isRecording = false
        }
    }

    /// Transcribe an externally recorded audio file.
    /// - Parameter audioURL: Path to the audio file (m4a, mp3, wav).
    public func transcribeExternalAudio(from audioURL: URL) async {
        guard !self.isTranscribing else {
            AppLogger.info("Already transcribing", category: .recordingManager)
            return
        }

        // Validate file exists
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            AppLogger.error("Audio file not found for import", category: .recordingManager, extra: ["path": audioURL.path])
            self.lastError = AudioImportError.fileNotFound
            return
        }

        // Validate file extension
        let validExtensions = ["m4a", "mp3", "wav"]
        guard validExtensions.contains(audioURL.pathExtension.lowercased()) else {
            AppLogger.error("Unsupported audio format for import", category: .recordingManager, extra: ["extension": audioURL.pathExtension])
            self.lastError = AudioImportError.unsupportedFormat
            return
        }

        // Create meeting record for imported file
        let meeting = Meeting(
            app: .importedFile,
            audioFilePath: audioURL.path
        )
        self.currentMeeting = meeting

        AppLogger.info("Starting transcription for imported file", category: .recordingManager, extra: ["filename": audioURL.lastPathComponent])
        await self.transcribeRecording(audioURL: audioURL, meeting: meeting)
    }

    /// Enable automatic recording when meetings are detected.
    func enableAutoRecording() {
        self.meetingDetector.startMonitoring()

        // Watch for detected meetings
        self.meetingDetector.$detectedMeeting
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] detected in
                Task { @MainActor in
                    let isCurrentlyRecording = self?.isRecording ?? false
                    if detected != nil, !isCurrentlyRecording {
                        await self?.startRecording()
                    } else if detected == nil, isCurrentlyRecording {
                        await self?.stopRecording()
                    }
                }
            }
            .store(in: &self.cancellables)
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // Sync with audio recorder state
        self.micRecorder.isRecordingPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &self.$isRecording)
    }

    private func cleanupTemporaryFiles() {
        var urlsToDelete: [URL] = []
        if let micURL = micAudioURL { urlsToDelete.append(micURL) }
        if let sysURL = systemAudioURL { urlsToDelete.append(sysURL) }

        self.storage.cleanupTemporaryFiles(urls: urlsToDelete)

        self.micAudioURL = nil
        self.systemAudioURL = nil
    }

    private enum Constants {
        static let processingProgress: Double = 10.0
        static let postProcessingProgress: Double = 90.0
        static let aiProcessingProgress: Double = 92.0
        static let statusResetDelay: Int = 3
    }

    private func transcribeRecording(audioURL: URL, meeting: Meeting) async {
        self.isTranscribing = true
        let audioDuration = await getAudioDuration(from: audioURL)
        self.transcriptionStatus.beginTranscription(audioDuration: audioDuration)

        do {
            try await self.performHealthCheck()

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

            self.transcriptionStatus.completeTranscription(success: true)
            self.notifySuccess(for: transcription)
            self.scheduleStatusReset()

        } catch {
            self.handleTranscriptionError(error)
        }

        self.isTranscribing = false
        self.currentMeeting = nil
    }

    // MARK: - Helper Methods

    private func performHealthCheck() async throws {
        self.transcriptionStatus.updateProgress(phase: .preparing)
        let isHealthy = try await transcriptionClient.healthCheck()
        guard isHealthy else {
            throw TranscriptionError.serviceUnavailable
        }
    }

    private func performTranscription(audioURL: URL) async throws -> TranscriptionResponse {
        self.transcriptionStatus.updateProgress(
            phase: .processing, percentage: Constants.processingProgress
        )
        return try await self.transcriptionClient.transcribe(audioURL: audioURL)
    }

    private func applyPostProcessing(rawText: String) async -> (String?, UUID?, String?) {
        self.transcriptionStatus.updateProgress(
            phase: .postProcessing, percentage: Constants.postProcessingProgress
        )

        let settings = AppSettingsStore.shared
        guard settings.postProcessingEnabled,
              settings.aiConfiguration.isValid,
              let prompt = settings.selectedPrompt
        else {
            return (nil, nil, nil)
        }

        self.transcriptionStatus.updateProgress(
            phase: .postProcessing, percentage: Constants.aiProcessingProgress
        )

        do {
            let processed = try await postProcessingService.processTranscription(
                rawText, with: prompt
            )
            AppLogger.info("Post-processing complete", category: .recordingManager, extra: ["prompt": prompt.title])
            return (processed, prompt.id, prompt.title)
        } catch {
            AppLogger.error("Post-processing failed, using raw transcription", category: .recordingManager, error: error)
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
        AppLogger.info("Transcription created", category: .recordingManager, extra: ["words": transcription.wordCount, "type": logMessageSuffix])

        try await self.storage.saveTranscription(transcription)
        return transcription
    }

    private func notifySuccess(for transcription: Transcription) {
        let suffix =
            transcription.isPostProcessed
                ? "(\(transcription.postProcessingPromptTitle ?? "processado"))" : "transcritas"
        let body = "\(transcription.meeting.appName): \(transcription.wordCount) palavras \(suffix)"

        self.notificationService.sendNotification(title: "Transcrição Concluída", body: body)
    }

    private func handleTranscriptionError(_ error: Error) {
        AppLogger.error("Transcription failed", category: .recordingManager, error: error)
        self.lastError = error

        self.transcriptionStatus.recordError(.transcriptionFailed(error.localizedDescription))
        self.transcriptionStatus.completeTranscription(success: false)

        self.notificationService.sendNotification(
            title: "Falha na Transcrição", body: error.localizedDescription
        )
    }

    private func scheduleStatusReset() {
        Task { @MainActor in
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
        self.statusCheckTask?.cancel()

        self.statusCheckTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                await self?.checkServiceStatus()
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    /// Check and update service status.
    private func checkServiceStatus() async {
        self.transcriptionStatus.updateServiceState(.connecting)

        do {
            let status = try await transcriptionClient.fetchServiceStatus()
            self.transcriptionStatus.updateServiceState(.connected)
            self.transcriptionStatus.updateModelState(status.modelStateEnum, device: status.device)
        } catch {
            self.transcriptionStatus.updateServiceState(.disconnected)
            self.transcriptionStatus.recordError(.connectionFailed(error.localizedDescription))
        }
    }

    /// Manually refresh service status.
    func refreshServiceStatus() async {
        await self.checkServiceStatus()
    }
}

// MARK: - Errors

public enum RecordingManagerError: LocalizedError {
    case noOutputPath
    case mergeFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .noOutputPath:
            "No output path specified for merged audio"
        case let .mergeFailed(error):
            "Audio merge failed: \(error.localizedDescription)"
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
