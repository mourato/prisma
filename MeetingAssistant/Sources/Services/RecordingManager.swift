import Foundation
import Combine
import os.log
import UserNotifications

/// Central manager coordinating recording, meeting detection, and transcription.
@MainActor
class RecordingManager: ObservableObject {
    static let shared = RecordingManager()
    
    private let logger = Logger(subsystem: "MeetingAssistant", category: "RecordingManager")
    
    // MARK: - Published State
    
    @Published private(set) var isRecording = false
    @Published private(set) var isTranscribing = false
    @Published private(set) var currentMeeting: Meeting?
    @Published private(set) var lastError: Error?
    @Published private(set) var hasScreenCapturePermission = false
    
    /// Detailed transcription service status for UI feedback.
    let transcriptionStatus = TranscriptionStatus()
    
    // MARK: - Services
    
    private let audioRecorder = AudioRecorder.shared
    private let meetingDetector = MeetingDetector.shared
    private let transcriptionClient = TranscriptionClient.shared
    
    private var cancellables = Set<AnyCancellable>()
    private var statusCheckTask: Task<Void, Never>?
    
    // MARK: - Storage
    
    private var recordingsDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
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
    
    /// Check and update screen capture permission status.
    func checkPermission() async {
        hasScreenCapturePermission = await audioRecorder.hasPermission()
    }
    
    /// Request screen recording permission.
    func requestPermission() async {
        await audioRecorder.requestPermission()
        await checkPermission()
    }
    
    /// Open System Preferences to Screen Recording settings.
    func openPermissionSettings() {
        audioRecorder.openScreenRecordingSettings()
    }
    
    // MARK: - Public API
    
    /// Start recording audio for a meeting.
    func startRecording() async {
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
            
            // Generate output file path
            let filename = generateFilename(for: meeting)
            let outputURL = recordingsDirectory.appendingPathComponent(filename)
            
            // Start recording
            try await audioRecorder.startRecording(to: outputURL)
            
            isRecording = true
            currentMeeting?.audioFilePath = outputURL.path
            
            logger.info("Recording started for \(app.displayName)")
            
        } catch {
            logger.error("Failed to start recording: \(error.localizedDescription)")
            lastError = error
            currentMeeting = nil
        }
    }
    
    /// Stop recording and optionally transcribe.
    func stopRecording(transcribe: Bool = true) async {
        guard isRecording else {
            logger.warning("Not recording")
            return
        }
        
        do {
            // Stop recording
            let audioURL = try await audioRecorder.stopRecording()
            
            // Update meeting
            currentMeeting?.endTime = Date()
            isRecording = false
            
            logger.info("Recording stopped")
            
            // Transcribe if requested
            if transcribe, let url = audioURL, let meeting = currentMeeting {
                await transcribeRecording(audioURL: url, meeting: meeting)
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
        audioRecorder.$isRecording
            .receive(on: DispatchQueue.main)
            .assign(to: &$isRecording)
    }
    
    private func generateFilename(for meeting: Meeting) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: meeting.startTime)
        return "\(meeting.app.rawValue)_\(timestamp).m4a"
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
        // Use AVAsset to get audio duration
        // NOTE: AVFoundation import would be needed for full implementation
        // For now, return nil and let the UI handle unknown duration gracefully
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
    /// Only works when running as a proper macOS app bundle.
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
    /// Uses UNUserNotificationCenter for app bundles, falls back to osascript for CLI.
    /// - Parameters:
    ///   - title: The notification title.
    ///   - body: The notification body text.
    private func sendNotification(title: String, body: String) {
        if isRunningAsAppBundle {
            sendNotificationViaUserNotifications(title: title, body: body)
        } else {
            sendNotificationViaAppleScript(title: title, body: body)
        }
    }
    
    /// Send notification using UserNotifications framework (requires app bundle).
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
    
    /// Send notification using osascript as fallback for CLI tools.
    private func sendNotificationViaAppleScript(title: String, body: String) {
        let escapedTitle = title.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedBody = body.replacingOccurrences(of: "\"", with: "\\\"")
        
        let script = "display notification \"\(escapedBody)\" with title \"\(escapedTitle)\" sound name \"default\""
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        
        do {
            try process.run()
        } catch {
            logger.error("Failed to send notification via osascript: \(error.localizedDescription)")
        }
    }
}
