import Combine
import Foundation
import MeetingAssistantCore

// MARK: - Mock Audio Recording Service

class MockAudioRecorder: AudioRecordingService {
    @Published var isRecording = false
    var isRecordingPublisher: AnyPublisher<Bool, Never> { self.$isRecording.eraseToAnyPublisher() }

    var currentRecordingURL: URL?
    var error: Error?

    var shouldFailStart = false
    var permissionGranted = true
    var permissionState: PermissionState = .granted

    var startRecordingCalled = false
    var stopRecordingCalled = false

    // Call tracking properties
    var startRecordingParams: [(url: URL, retryCount: Int)] = []
    var stopRecordingCalledCount = 0

    func startRecording(to outputURL: URL, retryCount: Int) async throws {
        self.startRecordingParams.append((outputURL, retryCount))

        if self.shouldFailStart {
            throw NSError(domain: "MockRecorder", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock failure"])
        }
        self.startRecordingCalled = true
        self.isRecording = true
        self.currentRecordingURL = outputURL
    }

    func stopRecording() async -> URL? {
        self.stopRecordingCalledCount += 1
        self.stopRecordingCalled = true
        self.isRecording = false
        return self.currentRecordingURL
    }

    func hasPermission() async -> Bool {
        self.permissionGranted
    }

    func requestPermission() async {
        // no-op
    }

    func getPermissionState() -> PermissionState {
        self.permissionState
    }

    func openSettings() {
        // no-op
    }
}

// MARK: - Mock Transcription Service

class MockTranscriptionClient: TranscriptionService {
    @Published var isTranscribing = false

    var shouldFailHealthCheck = false
    var shouldFailTranscription = false

    // Call tracking properties
    var healthCheckCallCount = 0
    var fetchServiceStatusCallCount = 0
    var transcribeCallCount = 0
    var lastTranscribeAudioURL: URL?

    func healthCheck() async throws -> Bool {
        self.healthCheckCallCount += 1
        if self.shouldFailHealthCheck { return false }
        return true
    }

    func fetchServiceStatus() async throws -> ServiceStatusResponse {
        self.fetchServiceStatusCallCount += 1
        return ServiceStatusResponse(
            status: "ready",
            modelState: "loaded",
            modelLoaded: true,
            device: "cpu",
            modelName: "mock-model",
            uptimeSeconds: 100,
            lastTranscriptionTime: nil,
            totalTranscriptions: 0,
            totalAudioProcessedSeconds: 0
        )
    }

    func transcribe(audioURL: URL) async throws -> TranscriptionResponse {
        self.transcribeCallCount += 1
        self.lastTranscribeAudioURL = audioURL

        if self.shouldFailTranscription {
            throw NSError(domain: "MockTranscription", code: 2, userInfo: [NSLocalizedDescriptionKey: "Transcription failed"])
        }
        return TranscriptionResponse(
            text: "Mock transcription text",
            language: "pt",
            durationSeconds: 10.0,
            model: "mock-model",
            processedAt: Date().ISO8601Format()
        )
    }
}

// MARK: - Mock Post Processing Service

@MainActor
class MockPostProcessingService: PostProcessingServiceProtocol {
    @Published var isProcessing = false
    var isProcessingPublisher: AnyPublisher<Bool, Never> { self.$isProcessing.eraseToAnyPublisher() }

    var lastError: PostProcessingError?

    var shouldFail = false
    var processTranscriptionCallCount = 0
    var lastProcessText: String?

    func processTranscription(_ text: String, with prompt: PostProcessingPrompt) async throws -> String {
        self.processTranscriptionCallCount += 1
        self.lastProcessText = text

        if self.shouldFail {
            throw PostProcessingError.apiError("Mock failure")
        }
        return "Processed: \(text)"
    }

    func processTranscription(_ text: String) async throws -> String {
        try await self.processTranscription(text, with: PostProcessingPrompt(
            id: UUID(),
            title: "Default",
            promptText: "Fix this: {{TRANSCRIPTION}}",
            isActive: true
        ))
    }
}

// MARK: - Mock Storage Service

class MockStorageService: StorageService, @unchecked Sendable {
    var recordingsDirectory: URL = .init(fileURLWithPath: "/tmp/mock/recordings")

    var createRecordingURLCalled = false
    var cleanupTemporaryFilesCalled = false
    var saveTranscriptionCalled = false

    // Call tracking properties
    var createRecordingURLParams: [(meeting: Meeting, type: RecordingType)] = []
    var loadTranscriptionsCallCount = 0

    // Mock data for testing
    var mockTranscriptions: [Transcription] = []

    func createRecordingURL(for meeting: Meeting, type: RecordingType) -> URL {
        self.createRecordingURLParams.append((meeting, type))
        self.createRecordingURLCalled = true
        return self.recordingsDirectory.appendingPathComponent("mock_\(type.rawValue).wav")
    }

    func cleanupTemporaryFiles(urls: [URL]) {
        self.cleanupTemporaryFilesCalled = true
    }

    func saveTranscription(_ transcription: Transcription) async throws {
        self.saveTranscriptionCalled = true
    }

    func loadTranscriptions() async throws -> [Transcription] {
        self.loadTranscriptionsCallCount += 1
        return self.mockTranscriptions
    }

    func loadAllMetadata() async throws -> [TranscriptionMetadata] {
        self.mockTranscriptions.map { transcription in
            TranscriptionMetadata(
                id: transcription.id,
                meetingId: transcription.meeting.id,
                appName: transcription.meeting.appName,
                appRawValue: transcription.meeting.app.rawValue,
                startTime: transcription.meeting.startTime,
                createdAt: transcription.createdAt,
                previewText: transcription.preview,
                language: transcription.language,
                isPostProcessed: transcription.isPostProcessed,
                duration: transcription.meeting.duration
            )
        }
    }

    func loadTranscription(by id: UUID) async throws -> Transcription? {
        self.mockTranscriptions.first(where: { $0.id == id })
    }
}

// MARK: - Mock Notification Service

class MockNotificationService: NotificationServiceProtocol {
    var requestAuthorizationCalled = false
    var showRecordingStartedCalled = false
    var showRecordingStoppedCalled = false
    var showTranscriptionCompletedCalled = false
    var showTranscriptionFailedCalled = false

    var pendingNotifications: [String] = []
    var sentNotifications: [(title: String, body: String)] = []

    func requestAuthorization() {
        self.requestAuthorizationCalled = true
    }

    func showRecordingStarted() {
        self.showRecordingStartedCalled = true
        self.pendingNotifications.append("recordingStarted")
    }

    func showRecordingStopped() {
        self.showRecordingStoppedCalled = true
        self.pendingNotifications.append("recordingStopped")
    }

    func showTranscriptionCompleted() {
        self.showTranscriptionCompletedCalled = true
        self.pendingNotifications.append("transcriptionCompleted")
    }

    func showTranscriptionFailed() {
        self.showTranscriptionFailedCalled = true
        self.pendingNotifications.append("transcriptionFailed")
    }

    func sendNotification(title: String, body: String) {
        self.sentNotifications.append((title, body))
    }
}
