import Combine
import Foundation
import MeetingAssistantCore

// MARK: - Mock Audio Recording Service

class MockAudioRecorder: AudioRecordingService {
    @Published var isRecording = false
    var isRecordingPublisher: AnyPublisher<Bool, Never> {
        $isRecording.eraseToAnyPublisher()
    }

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
        startRecordingParams.append((outputURL, retryCount))

        if shouldFailStart {
            throw NSError(domain: "MockRecorder", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock failure"])
        }
        startRecordingCalled = true
        isRecording = true
        currentRecordingURL = outputURL
    }

    func stopRecording() async -> URL? {
        stopRecordingCalledCount += 1
        stopRecordingCalled = true
        isRecording = false
        return currentRecordingURL
    }

    func hasPermission() async -> Bool {
        permissionGranted
    }

    func requestPermission() async {
        // no-op
    }

    func getPermissionState() -> PermissionState {
        permissionState
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
        healthCheckCallCount += 1
        if shouldFailHealthCheck { return false }
        return true
    }

    func fetchServiceStatus() async throws -> ServiceStatusResponse {
        fetchServiceStatusCallCount += 1
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

    func transcribe(
        audioURL: URL,
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> TranscriptionResponse {
        transcribeCallCount += 1
        lastTranscribeAudioURL = audioURL

        // Simulate progress updates if callback provided
        if let onProgress {
            onProgress(25.0)
            onProgress(50.0)
            onProgress(75.0)
            onProgress(100.0)
        }

        if shouldFailTranscription {
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
    var isProcessingPublisher: AnyPublisher<Bool, Never> {
        $isProcessing.eraseToAnyPublisher()
    }

    var lastError: PostProcessingError?

    var shouldFail = false
    var processTranscriptionCallCount = 0
    var lastProcessText: String?

    func processTranscription(_ text: String, with prompt: PostProcessingPrompt) async throws -> String {
        processTranscriptionCallCount += 1
        lastProcessText = text

        if shouldFail {
            throw PostProcessingError.apiError("Mock failure")
        }
        return "Processed: \(text)"
    }

    func processTranscription(_ text: String) async throws -> String {
        try await processTranscription(text, with: PostProcessingPrompt(
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

    /// Mock data for testing
    var mockTranscriptions: [Transcription] = []

    func createRecordingURL(for meeting: Meeting, type: RecordingType) -> URL {
        createRecordingURLParams.append((meeting, type))
        createRecordingURLCalled = true
        return recordingsDirectory.appendingPathComponent("mock_\(type.rawValue).wav")
    }

    func cleanupTemporaryFiles(urls: [URL]) {
        cleanupTemporaryFilesCalled = true
    }

    func saveTranscription(_ transcription: Transcription) async throws {
        saveTranscriptionCalled = true
    }

    func loadTranscriptions() async throws -> [Transcription] {
        loadTranscriptionsCallCount += 1
        return mockTranscriptions
    }

    func loadAllMetadata() async throws -> [TranscriptionMetadata] {
        allMetadata()
    }

    func loadMetadata(matching query: TranscriptionMetadataQuery) async throws -> [TranscriptionMetadata] {
        allMetadata()
            .filter { metadata in
                switch query.sourceFilter {
                case .all:
                    true
                case .dictations:
                    metadata.appRawValue == MeetingApp.unknown.rawValue
                case .meetings:
                    metadata.appRawValue != MeetingApp.unknown.rawValue &&
                        metadata.appRawValue != MeetingApp.importedFile.rawValue
                }
            }
            .filter { metadata in
                query.dateFilter.contains(metadata.createdAt)
            }
            .filter { metadata in
                guard let appRawValue = query.appRawValue else { return true }
                return metadata.appRawValue == appRawValue
            }
            .filter { metadata in
                let trimmed = query.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return true }

                let queryText = trimmed.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                let preview = metadata.previewText.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                let appName = metadata.appName.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                return preview.contains(queryText) || appName.contains(queryText)
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private func allMetadata() -> [TranscriptionMetadata] {
        mockTranscriptions.map { transcription in
            TranscriptionMetadata(
                id: transcription.id,
                meetingId: transcription.meeting.id,
                appName: transcription.meeting.appName,
                appRawValue: transcription.meeting.app.rawValue,
                appBundleIdentifier: transcription.meeting.appBundleIdentifier,
                startTime: transcription.meeting.startTime,
                createdAt: transcription.createdAt,
                previewText: transcription.preview,
                wordCount: transcription.wordCount,
                language: transcription.language,
                isPostProcessed: transcription.isPostProcessed,
                duration: transcription.meeting.duration,
                audioFilePath: transcription.meeting.audioFilePath,
                inputSource: transcription.inputSource
            )
        }
    }

    func loadTranscription(by id: UUID) async throws -> Transcription? {
        mockTranscriptions.first(where: { $0.id == id })
    }

    func deleteTranscription(by id: UUID) async throws {
        mockTranscriptions.removeAll(where: { $0.id == id })
    }

    func cleanupOldTranscriptions(olderThanDays days: Int) async throws {
        // Mock implementation
    }

    func computeRetentionCleanupPreview(olderThanDays days: Int) async throws -> RetentionCleanupPreview {
        RetentionCleanupPreview(
            retentionDays: days,
            audioFiles: [],
            transcriptions: []
        )
    }

    func performRetentionCleanup(preview: RetentionCleanupPreview) async throws -> RetentionCleanupResult {
        RetentionCleanupResult(
            deletedAudioCount: preview.audioCount,
            deletedTranscriptionCount: preview.transcriptionCount
        )
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
        requestAuthorizationCalled = true
    }

    func showRecordingStarted() {
        showRecordingStartedCalled = true
        pendingNotifications.append("recordingStarted")
    }

    func showRecordingStopped() {
        showRecordingStoppedCalled = true
        pendingNotifications.append("recordingStopped")
    }

    func showTranscriptionCompleted() {
        showTranscriptionCompletedCalled = true
        pendingNotifications.append("transcriptionCompleted")
    }

    func showTranscriptionFailed() {
        showTranscriptionFailedCalled = true
        pendingNotifications.append("transcriptionFailed")
    }

    func sendNotification(title: String, body: String) {
        sentNotifications.append((title, body))
    }
}
