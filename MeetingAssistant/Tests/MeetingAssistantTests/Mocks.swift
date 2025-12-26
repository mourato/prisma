import Foundation
import Combine
import MeetingAssistantCore

// MARK: - Mock Audio Recording Service

class MockAudioRecorder: AudioRecordingService {
    @Published var isRecording = false
    var isRecordingPublisher: AnyPublisher<Bool, Never> { $isRecording.eraseToAnyPublisher() }
    
    var currentRecordingURL: URL?
    var error: Error?
    
    var shouldFailStart = false
    var permissionGranted = true
    var permissionState: PermissionState = .granted
    
    var startRecordingCalled = false
    var stopRecordingCalled = false
    
    func startRecording(to outputURL: URL, retryCount: Int) async throws {
        if shouldFailStart {
             throw NSError(domain: "MockRecorder", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock failure"])
        }
        startRecordingCalled = true
        isRecording = true
        currentRecordingURL = outputURL
    }
    
    func stopRecording() async -> URL? {
        stopRecordingCalled = true
        isRecording = false
        return currentRecordingURL
    }
    
    func hasPermission() async -> Bool {
        return permissionGranted
    }
    
    func requestPermission() async {
        // no-op
    }
    
    func getPermissionState() -> PermissionState {
        return permissionState
    }
    
    func openSettings() {
        // no-op
    }
}

// MARK: - Mock Transcription Service

class MockTranscriptionClient: TranscriptionService {
    @Published var isTranscribing = false // Simulated state if needed
    
    var shouldFailHealthCheck = false
    var shouldFailTranscription = false
    
    func healthCheck() async throws -> Bool {
        if shouldFailHealthCheck { return false }
        return true
    }
    
    func fetchServiceStatus() async throws -> ServiceStatusResponse {
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
    var isProcessingPublisher: AnyPublisher<Bool, Never> { $isProcessing.eraseToAnyPublisher() }
    
    var lastError: PostProcessingError?
    
    var shouldFail = false
    
    func processTranscription(_ text: String, with prompt: PostProcessingPrompt) async throws -> String {
        if shouldFail {
            // Throwing a generic error for now as PostProcessingError might not have a generic init
            throw PostProcessingError.apiError("Mock failure")
        }
        return "Processed: \(text)"
    }
    
    func processTranscription(_ text: String) async throws -> String {
        return try await processTranscription(text, with: PostProcessingPrompt(
            id: UUID(),
            title: "Default",
            promptText: "Fix this: {{TRANSCRIPTION}}",
            isActive: true
        ))
    }
}
