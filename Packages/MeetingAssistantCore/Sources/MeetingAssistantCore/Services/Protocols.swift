import Combine
import Foundation

// MARK: - Audio Recording Protocol

/// Abstract interface for audio recording services.
@MainActor
public protocol AudioRecordingService: ObservableObject {
    var isRecording: Bool { get }
    var isRecordingPublisher: AnyPublisher<Bool, Never> { get } // For Combine observation
    var currentRecordingURL: URL? { get }
    var error: Error? { get }

    /// Start recording to the specified URL.
    func startRecording(to outputURL: URL, retryCount: Int) async throws

    /// Stop recording and return the URL of the created file.
    func stopRecording() async -> URL?

    /// Check if permission is granted.
    func hasPermission() async -> Bool

    /// Request permission from the user.
    func requestPermission() async

    /// Get the detailed permission state.
    func getPermissionState() -> PermissionState

    /// Open system settings for this permission.
    func openSettings()
}

// Default implementation for retryCount (since it's not always needed)
public extension AudioRecordingService {
    func startRecording(to outputURL: URL) async throws {
        try await self.startRecording(to: outputURL, retryCount: 0)
    }
}

// MARK: - Transcription Protocol

/// Abstract interface for transcription services.
@MainActor
public protocol TranscriptionService: ObservableObject {
    /// Check service health.
    func healthCheck() async throws -> Bool

    /// Fetch detailed service status.
    func fetchServiceStatus() async throws -> ServiceStatusResponse

    /// Transcribe an audio file.
    func transcribe(
        audioURL: URL,
        onProgress: (@Sendable (Double) -> Void)?
    ) async throws -> TranscriptionResponse
}

// MARK: - Post-Processing Protocol

/// Abstract interface for AI post-processing services.
@MainActor
public protocol PostProcessingServiceProtocol: ObservableObject {
    var isProcessing: Bool { get }
    var lastError: PostProcessingError? { get }

    /// Process a raw transcription text using the selected prompt.
    func processTranscription(_ transcription: String) async throws -> String

    /// Process a raw transcription using a specific prompt.
    func processTranscription(_ transcription: String, with prompt: PostProcessingPrompt) async throws -> String
}

// MARK: - Notification Service Protocol

/// Abstract interface for notification services.
public protocol NotificationServiceProtocol {
    /// Request notification authorization.
    func requestAuthorization()

    /// Show notification for recording started.
    func showRecordingStarted()

    /// Show notification for recording stopped.
    func showRecordingStopped()

    /// Show notification for transcription completed.
    func showTranscriptionCompleted()

    /// Show notification for transcription failed.
    func showTranscriptionFailed()

    /// Send a custom notification.
    func sendNotification(title: String, body: String)
}
