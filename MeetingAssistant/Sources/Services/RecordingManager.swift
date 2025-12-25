import Foundation
import Combine
import os.log

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
    
    // MARK: - Services
    
    private let audioRecorder = AudioRecorder.shared
    private let meetingDetector = MeetingDetector.shared
    private let transcriptionClient = TranscriptionClient.shared
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Storage
    
    private var recordingsDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let recordings = appSupport.appendingPathComponent("MeetingAssistant/recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: recordings, withIntermediateDirectories: true)
        return recordings
    }
    
    private init() {
        setupBindings()
        Task {
            await checkPermission()
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
        return "\(meeting.app.rawValue)_\(timestamp).wav"
    }
    
    private func transcribeRecording(audioURL: URL, meeting: Meeting) async {
        isTranscribing = true
        
        do {
            // Check service health
            let isHealthy = try await transcriptionClient.healthCheck()
            guard isHealthy else {
                throw TranscriptionError.serviceUnavailable
            }
            
            // Transcribe
            let response = try await transcriptionClient.transcribe(audioURL: audioURL)
            
            // Create transcription record
            let transcription = Transcription(
                meeting: meeting,
                text: response.text,
                language: response.language,
                modelName: response.model
            )
            
            // TODO: Save transcription to storage
            logger.info("Transcription saved: \(transcription.wordCount) words")
            
            // Notify user
            sendNotification(
                title: "Transcrição Concluída",
                body: "\(meeting.appName): \(transcription.wordCount) palavras transcritas"
            )
            
        } catch {
            logger.error("Transcription failed: \(error.localizedDescription)")
            lastError = error
            
            sendNotification(
                title: "Falha na Transcrição",
                body: error.localizedDescription
            )
        }
        
        isTranscribing = false
        currentMeeting = nil
    }
    
    private func sendNotification(title: String, body: String) {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = body
        notification.soundName = NSUserNotificationDefaultSoundName
        
        NSUserNotificationCenter.default.deliver(notification)
    }
}
