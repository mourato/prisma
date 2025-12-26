import Foundation
import Combine
import os.log
import UserNotifications
import AVFoundation

/// Central manager coordinating recording, meeting detection, and transcription.
/// Orchestrates microphone and system audio recording with post-processing merge.
@MainActor
public class RecordingManager: ObservableObject {
    public static let shared = RecordingManager()
    
    private let logger = Logger(subsystem: "MeetingAssistant", category: "RecordingManager")
    
    // MARK: - Published State
    
    @Published public private(set) var isRecording = false
    @Published public private(set) var isTranscribing = false
    @Published public private(set) var currentMeeting: Meeting?
    @Published public private(set) var lastError: Error?
    @Published public private(set) var hasRequiredPermissions = false
    
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
    
    private var cancellables = Set<AnyCancellable>()
    private var statusCheckTask: Task<Void, Never>?
    
    // MARK: - Recording URLs
    
    private var micAudioURL: URL?
    private var systemAudioURL: URL?
    private var mergedAudioURL: URL?
    
    // MARK: - Storage
    
    private var recordingsDirectory: URL {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            logger.error("Failed to find Application Support directory")
            fatalError("Critical: Could not access Application Support directory.")
        }
        let recordings = appSupport.appendingPathComponent("MeetingAssistant/recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: recordings, withIntermediateDirectories: true)
        return recordings
    }
    
    public init(
        micRecorder: any AudioRecordingService = AudioRecorder.shared,
        systemRecorder: any AudioRecordingService = SystemAudioRecorder.shared,
        transcriptionClient: any TranscriptionService = TranscriptionClient.shared,
        postProcessingService: any PostProcessingServiceProtocol = PostProcessingService.shared,
        audioMerger: AudioMerger = AudioMerger(),
        meetingDetector: MeetingDetector = MeetingDetector.shared,
        storage: any StorageService = FileSystemStorageService.shared
    ) {
        self.micRecorder = micRecorder
        self.systemRecorder = systemRecorder
        self.transcriptionClient = transcriptionClient
        self.postProcessingService = postProcessingService
        self.audioMerger = audioMerger
        self.meetingDetector = meetingDetector
        self.storage = storage
        
        setupBindings()
        requestNotificationAuthorization()
        Task { [weak self] in
            await self?.checkPermission()
            await self?.startStatusMonitoring()
        }
    }
    
    // ...
    
    /// Check if running as a proper app bundle (required for UNUserNotificationCenter).
    private var isRunningAsAppBundle: Bool {
        guard let id = Bundle.main.bundleIdentifier else { return false }
        return !id.lowercased().contains("xctest")
    }
    public func checkPermission() async {
        let micPermission = await micRecorder.hasPermission()
        let screenPermission = await systemRecorder.hasPermission()
        
        // Update individual permission states using detailed state methods
        let micState = micRecorder.getPermissionState()
        let screenState = systemRecorder.getPermissionState()
        
        permissionStatus.updateMicrophoneState(micState)
        permissionStatus.updateScreenRecordingState(screenState)
        
        hasRequiredPermissions = micPermission && screenPermission
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
    
    /// Start recording audio for a meeting (both microphone and system audio).
    public func startRecording() async {
        guard !isRecording else {
            logger.warning("Already recording")
            return
        }
        
        do {
            // Determine meeting app (if detected)
            let app = meetingDetector.detectedMeeting ?? .unknown
            
            // Create meeting record
            let meeting = Meeting(app: app)
            currentMeeting = meeting
            
            // Generate output file paths using StorageService
            micAudioURL = storage.createRecordingURL(for: meeting, type: .microphone)
            systemAudioURL = storage.createRecordingURL(for: meeting, type: .system)
            mergedAudioURL = storage.createRecordingURL(for: meeting, type: .merged)
            
            // Start microphone recording
            try await micRecorder.startRecording(to: micAudioURL!, retryCount: 0)
            
            // Start system audio recording (async)
            try await systemRecorder.startRecording(to: systemAudioURL!, retryCount: 0)
            
            isRecording = true
            currentMeeting?.audioFilePath = mergedAudioURL?.path
            
            logger.info("Recording started for \(app.displayName) (mic + system)")
            
        } catch {
            logger.error("Failed to start recording: \(error.localizedDescription)")
            lastError = error
            
            // Cleanup partial starts
            _ = await micRecorder.stopRecording()
            _ = await systemRecorder.stopRecording()
            
            currentMeeting = nil
        }
    }
    
    /// Stop recording and optionally transcribe.
    public func stopRecording(transcribe: Bool = true) async {
        guard isRecording else {
            logger.warning("Not recording")
            return
        }
        
        do {
            // Stop both recorders
            let micURL = await micRecorder.stopRecording()
            let sysURL = await systemRecorder.stopRecording()
            
            // Update meeting
            currentMeeting?.endTime = Date()
            isRecording = false
            
            logger.info("Recording stopped, merging audio files...")
            
            // Merge audio files
            var inputURLs: [URL] = []
            if let micURL = micURL { inputURLs.append(micURL) }
            if let sysURL = sysURL { inputURLs.append(sysURL) }
            
            guard let outputURL = mergedAudioURL else {
                throw RecordingManagerError.noOutputPath
            }
            
            let finalURL = try await audioMerger.mergeAudioFiles(inputURLs: inputURLs, to: outputURL)
            
            // Clean up temporary files
            cleanupTemporaryFiles()
            
            logger.info("Audio merge complete: \(finalURL.lastPathComponent)")
            
            // Transcribe if requested
            if transcribe, let meeting = currentMeeting {
                await transcribeRecording(audioURL: finalURL, meeting: meeting)
            }
            
        } catch {
            logger.error("Failed to stop recording: \(error.localizedDescription)")
            lastError = error
            isRecording = false
        }
    }
    
    /// Enable automatic recording when meetings are detected.
    func enableAutoRecording() {
        meetingDetector.startMonitoring()
        
        // Watch for detected meetings
        meetingDetector.$detectedMeeting
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] detected in
                Task { @MainActor in
                    if detected != nil && !(self?.isRecording ?? false) {
                        await self?.startRecording()
                    } else if detected == nil && (self?.isRecording ?? false) {
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
    
    private func cleanupTemporaryFiles() {
        var urlsToDelete: [URL] = []
        if let micURL = micAudioURL { urlsToDelete.append(micURL) }
        if let sysURL = systemAudioURL { urlsToDelete.append(sysURL) }
        
        storage.cleanupTemporaryFiles(urls: urlsToDelete)
        
        micAudioURL = nil
        systemAudioURL = nil
    }
    
    private enum Constants {
        static let processingProgress: Double = 10.0
        static let postProcessingProgress: Double = 90.0
        static let aiProcessingProgress: Double = 92.0
        static let statusResetDelay: Int = 3
    }
    
    private func transcribeRecording(audioURL: URL, meeting: Meeting) async {
        isTranscribing = true
        let audioDuration = getAudioDuration(from: audioURL)
        transcriptionStatus.beginTranscription(audioDuration: audioDuration)
        
        do {
            try await performHealthCheck()
            
            let response = try await performTranscription(audioURL: audioURL)
            let (processedContent, promptId, promptTitle) = await applyPostProcessing(rawText: response.text)
            
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
        transcriptionStatus.updateProgress(phase: .processing, percentage: Constants.processingProgress)
        return try await transcriptionClient.transcribe(audioURL: audioURL)
    }
    
    private func applyPostProcessing(rawText: String) async -> (String?, UUID?, String?) {
        transcriptionStatus.updateProgress(phase: .postProcessing, percentage: Constants.postProcessingProgress)
        
        let settings = AppSettingsStore.shared
        guard settings.postProcessingEnabled,
              settings.aiConfiguration.isValid,
              let prompt = settings.selectedPrompt else {
            return (nil, nil, nil)
        }
        
        transcriptionStatus.updateProgress(phase: .postProcessing, percentage: Constants.aiProcessingProgress)
        
        do {
            let processed = try await postProcessingService.processTranscription(rawText, with: prompt)
            logger.info("Post-processing complete using prompt: \(prompt.title)")
            return (processed, prompt.id, prompt.title)
        } catch {
            logger.warning("Post-processing failed, using raw transcription: \(error.localizedDescription)")
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
        
        let logMessageSuffix = transcription.isPostProcessed ? "(post-processed with '\(promptTitle ?? "unknown")')" : "(raw)"
        logger.info("Transcription created: \(transcription.wordCount) words \(logMessageSuffix)")
        
        try await storage.saveTranscription(transcription)
        return transcription
    }
    
    private func notifySuccess(for transcription: Transcription) {
        let suffix = transcription.isPostProcessed ? "(\(transcription.postProcessingPromptTitle ?? "processado"))" : "transcritas"
        let body = "\(transcription.meeting.appName): \(transcription.wordCount) palavras \(suffix)"
        
        sendNotification(title: "Transcrição Concluída", body: body)
    }
    
    private func handleTranscriptionError(_ error: Error) {
        logger.error("Transcription failed: \(error.localizedDescription)")
        lastError = error
        
        transcriptionStatus.recordError(.transcriptionFailed(error.localizedDescription))
        transcriptionStatus.completeTranscription(success: false)
        
        sendNotification(title: "Falha na Transcrição", body: error.localizedDescription)
    }
    
    private func scheduleStatusReset() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Constants.statusResetDelay))
            transcriptionStatus.resetToIdle()
        }
    }
    
    /// Get audio duration from file for progress estimation.
    private func getAudioDuration(from url: URL) -> Double? {
        // Implementation placeholder (could be added to AudioMerger or utility)
        return nil
    }
    
    /// Start periodic status monitoring.
    private func startStatusMonitoring() async {
        statusCheckTask?.cancel()
        
        statusCheckTask = Task { @MainActor [weak self] in
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
    

    
    /// Request notification authorization from the user.
    private func requestNotificationAuthorization() {
        guard isRunningAsAppBundle else {
            logger.info("Running as CLI tool, skipping UNUserNotificationCenter authorization")
            return
        }
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, error in
            if let error = error {
                self?.logger.error("Notification authorization failed: \(error.localizedDescription)")
            } else if !granted {
                self?.logger.warning("Notification authorization denied by user")
            }
        }
    }
    
    /// Send a local notification to the user.
    private func sendNotification(title: String, body: String) {
        if isRunningAsAppBundle {
            sendNotificationViaUserNotifications(title: title, body: body)
        } else {
            sendNotificationViaAppleScript(title: title, body: body)
        }
    }
    
    /// Send notification using UserNotifications framework.
    private func sendNotificationViaUserNotifications(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error = error {
                self?.logger.error("Failed to deliver notification: \(error.localizedDescription)")
            }
        }
    }
    
    /// Send notification using osascript as fallback.
    private func sendNotificationViaAppleScript(title: String, body: String) {
        let sanitizedTitle = sanitizeForAppleScript(title)
        let sanitizedBody = sanitizeForAppleScript(body)
        
        let script = "display notification \"\(sanitizedBody)\" with title \"\(sanitizedTitle)\" sound name \"default\""
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        
        do {
            try process.run()
        } catch {
            logger.error("Failed to send notification via osascript: \(error.localizedDescription)")
        }
    }
    
    /// Sanitize a string for safe use in AppleScript.
    private func sanitizeForAppleScript(_ input: String) -> String {
        var result = input.replacingOccurrences(of: "\\", with: "\\\\")
        result = result.replacingOccurrences(of: "\"", with: "\\\"")
        
        let dangerousPatterns: [(pattern: String, replacement: String)] = [
            ("`", "'"),
            ("$", ""),
            ("\n", " "),
            ("\r", " "),
            ("\t", " "),
            ("«", ""),
            ("»", ""),
        ]
        
        for (pattern, replacement) in dangerousPatterns {
            result = result.replacingOccurrences(of: pattern, with: replacement)
        }
        
        let maxLength = 200
        if result.count > maxLength {
            result = String(result.prefix(maxLength)) + "..."
        }
        
        return result
    }
}

// MARK: - Errors

public enum RecordingManagerError: LocalizedError {
    case noOutputPath
    case mergeFailed(Error)
    
    public var errorDescription: String? {
        switch self {
        case .noOutputPath:
            return "No output path specified for merged audio"
        case .mergeFailed(let error):
            return "Audio merge failed: \(error.localizedDescription)"
        }
    }
}
