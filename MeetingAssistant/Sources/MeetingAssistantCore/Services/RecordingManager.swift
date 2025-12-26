import Foundation
import Combine
import os.log
import UserNotifications

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
    
    // MARK: - Services
    
    private let micRecorder = AudioRecorder.shared
    private let systemRecorder = SystemAudioRecorder.shared
    private let audioMerger = AudioMerger()
    private let meetingDetector = MeetingDetector.shared
    private let transcriptionClient = TranscriptionClient.shared
    
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
    
    private init() {
        setupBindings()
        requestNotificationAuthorization()
        Task {
            await checkPermission()
            await startStatusMonitoring()
        }
    }
    
    // MARK: - Permission Handling
    
    /// Check and update permission status (Screen Recording + Microphone).
    public func checkPermission() async {
        let micPermission = await micRecorder.hasPermission()
        let screenPermission = await systemRecorder.hasPermission()
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
        systemRecorder.openScreenRecordingSettings()
    }
    
    /// Open System Preferences to Microphone settings.
    public func openMicrophoneSettings() {
        micRecorder.openMicrophoneSettings()
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
            
            // Generate output file paths
            let baseFilename = generateFilename(for: meeting)
            let micFilename = baseFilename.replacingOccurrences(of: ".m4a", with: "_mic.wav")
            let sysFilename = baseFilename.replacingOccurrences(of: ".m4a", with: "_sys.wav")
            
            micAudioURL = recordingsDirectory.appendingPathComponent(micFilename)
            systemAudioURL = recordingsDirectory.appendingPathComponent(sysFilename)
            mergedAudioURL = recordingsDirectory.appendingPathComponent(baseFilename)
            
            // Start microphone recording
            try micRecorder.startRecording(to: micAudioURL!, retryCount: 0)
            
            // Start system audio recording (async)
            try await systemRecorder.startRecording(to: systemAudioURL!)
            
            isRecording = true
            currentMeeting?.audioFilePath = mergedAudioURL?.path
            
            logger.info("Recording started for \(app.displayName) (mic + system)")
            
        } catch {
            logger.error("Failed to start recording: \(error.localizedDescription)")
            lastError = error
            
            // Cleanup partial starts
            _ = micRecorder.stopRecording()
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
            let micURL = micRecorder.stopRecording()
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
        micRecorder.$isRecording
            .receive(on: DispatchQueue.main)
            .assign(to: &$isRecording)
    }
    
    private func generateFilename(for meeting: Meeting) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: meeting.startTime)
        return "\(meeting.app.rawValue)_\(timestamp).m4a"
    }
    
    private func cleanupTemporaryFiles() {
        // Remove individual mic and system audio files after merge
        if let micURL = micAudioURL {
            try? FileManager.default.removeItem(at: micURL)
        }
        if let sysURL = systemAudioURL {
            try? FileManager.default.removeItem(at: sysURL)
        }
        micAudioURL = nil
        systemAudioURL = nil
    }
    
    private func transcribeRecording(audioURL: URL, meeting: Meeting) async {
        isTranscribing = true
        
        // Get audio duration for progress estimation
        let audioDuration = getAudioDuration(from: audioURL)
        transcriptionStatus.beginTranscription(audioDuration: audioDuration)
        
        do {
            // Check service health
            transcriptionStatus.updateProgress(phase: .preparing)
            
            let isHealthy = try await transcriptionClient.healthCheck()
            guard isHealthy else {
                throw TranscriptionError.serviceUnavailable
            }
            
            // Update status to processing
            transcriptionStatus.updateProgress(phase: .processing, percentage: 10)
            
            // Transcribe
            let response = try await transcriptionClient.transcribe(audioURL: audioURL)
            
            // Post-processing phase
            transcriptionStatus.updateProgress(phase: .postProcessing, percentage: 90)
            
            // Create transcription record
            let transcription = Transcription(
                meeting: meeting,
                text: response.text,
                language: response.language,
                modelName: response.model
            )
            
            // TODO: Save transcription to storage
            logger.info("Transcription saved: \(transcription.wordCount) words")
            
            // Mark as completed
            transcriptionStatus.completeTranscription(success: true)
            
            // Notify user
            sendNotification(
                title: "Transcrição Concluída",
                body: "\(meeting.appName): \(transcription.wordCount) palavras transcritas"
            )
            
            // Reset to idle after short delay
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(3))
                transcriptionStatus.resetToIdle()
            }
            
        } catch {
            logger.error("Transcription failed: \(error.localizedDescription)")
            lastError = error
            
            // Record error in status
            transcriptionStatus.recordError(
                .transcriptionFailed(error.localizedDescription)
            )
            transcriptionStatus.completeTranscription(success: false)
            
            sendNotification(
                title: "Falha na Transcrição",
                body: error.localizedDescription
            )
        }
        
        isTranscribing = false
        currentMeeting = nil
    }
    
    /// Get audio duration from file for progress estimation.
    private func getAudioDuration(from url: URL) -> Double? {
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
    
    /// Check if running as a proper app bundle (required for UNUserNotificationCenter).
    private var isRunningAsAppBundle: Bool {
        Bundle.main.bundleIdentifier != nil
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
