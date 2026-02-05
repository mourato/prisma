import Combine
import Foundation
import os.log

// MARK: - Service Status Response

/// Response from the /status endpoint with detailed service information.
public struct ServiceStatusResponse: Codable {
    public let status: String
    public let modelState: String
    public let modelLoaded: Bool
    public let device: String
    public let modelName: String
    public let uptimeSeconds: Double
    public let lastTranscriptionTime: String?
    public let totalTranscriptions: Int
    public let totalAudioProcessedSeconds: Double

    enum CodingKeys: String, CodingKey {
        case status
        case modelState = "model_state"
        case modelLoaded = "model_loaded"
        case device
        case modelName = "model_name"
        case uptimeSeconds = "uptime_seconds"
        case lastTranscriptionTime = "last_transcription_time"
        case totalTranscriptions = "total_transcriptions"
        case totalAudioProcessedSeconds = "total_audio_processed_seconds"
    }

    public init(
        status: String,
        modelState: String,
        modelLoaded: Bool,
        device: String,
        modelName: String,
        uptimeSeconds: Double,
        lastTranscriptionTime: String?,
        totalTranscriptions: Int,
        totalAudioProcessedSeconds: Double
    ) {
        self.status = status
        self.modelState = modelState
        self.modelLoaded = modelLoaded
        self.device = device
        self.modelName = modelName
        self.uptimeSeconds = uptimeSeconds
        self.lastTranscriptionTime = lastTranscriptionTime
        self.totalTranscriptions = totalTranscriptions
        self.totalAudioProcessedSeconds = totalAudioProcessedSeconds
    }

    /// Convert model state string to ModelState enum.
    public var modelStateEnum: ModelState {
        switch modelState {
        case "loaded": .loaded
        case "loading": .loading
        case "downloading": .downloading
        case "error": .error
        default: .unloaded
        }
    }
}

// MARK: - Transcription Client

/// Client for communicating with the local FluidAudio transcription service.
/// Adapts the local model manager to the existing client interface.
@MainActor
public class TranscriptionClient: ObservableObject, TranscriptionService {
    public static let shared = TranscriptionClient()

    private let manager = FluidAIModelManager.shared

    // We observe the manager to update our synthetic "ServiceStatus" if needed,
    // but the fetchServiceStatus() method is pull-based, so we can just compute it on demand.

    private init() {
        // NOTE: Model loading is now deferred to first transcription or explicit warmupModel() call
        // to prevent main thread starvation during app startup.
    }

    /// Check if the transcription service is healthy (delegates to XPC).
    public func healthCheck() async throws -> Bool {
        do {
            let status = try await MeetingAssistantAIClient.shared.fetchServiceStatus()
            return status.status == "healthy"
        } catch {
            return false
        }
    }

    /// Fetch detailed service status from XPC service.
    /// - Returns: ServiceStatusResponse with comprehensive service information.
    public func fetchServiceStatus() async throws -> ServiceStatusResponse {
        let xpcStatus = try await MeetingAssistantAIClient.shared.fetchServiceStatus()
        
        // Map XPC status to ServiceStatusResponse
        return ServiceStatusResponse(
            status: xpcStatus.status,
            modelState: xpcStatus.modelState,
            modelLoaded: xpcStatus.modelLoaded,
            device: xpcStatus.device,
            modelName: xpcStatus.modelName,
            uptimeSeconds: xpcStatus.uptimeSeconds,
            lastTranscriptionTime: nil,
            totalTranscriptions: 0,
            totalAudioProcessedSeconds: 0
        )
    }

    /// Warm up the model inside the XPC process.
    public func warmupModel() async throws {
        try await MeetingAssistantAIClient.shared.warmupModel()
    }

    /// Transcribe an audio file.
    /// - Parameter audioURL: Path to the audio file (WAV, M4A, etc.)
    /// - Parameter onProgress: Optional callback for transcription progress.
    /// - Returns: Transcription response from the service
    public func transcribe(
        audioURL: URL,
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> TranscriptionResponse {
        AppLogger.info(
            "Transcribing file locally",
            category: .transcriptionEngine,
            extra: ["filename": audioURL.lastPathComponent]
        )

        // Use MeetingAssistantAIClient (XPC) as the implementation provider.
        do {
            let response = try await MeetingAssistantAIClient.shared.transcribe(
                audioURL: audioURL
            )
            AppLogger.info(
                "Transcription completed via XPC",
                category: .transcriptionEngine,
                extra: ["words": response.text.split(separator: " ").count]
            )
            return response
        } catch {
            AppLogger.error(
                "Transcription failed",
                category: .transcriptionEngine,
                error: error,
                extra: ["filename": audioURL.lastPathComponent]
            )
            throw error
        }
    }

    deinit {
        AppLogger.debug("TranscriptionClient deinitialized", category: .transcriptionEngine)
    }
}

// MARK: - Errors

public enum TranscriptionError: LocalizedError {
    case serviceUnavailable
    case warmupFailed
    case invalidResponse
    case invalidURL(String)
    case transcriptionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .serviceUnavailable:
            NSLocalizedString("error.transcription.service_unavailable", bundle: .module, comment: "")
        case .warmupFailed:
            NSLocalizedString("error.transcription.warmup_failed", bundle: .module, comment: "")
        case .invalidResponse:
            NSLocalizedString("error.transcription.invalid_response", bundle: .module, comment: "")
        case let .invalidURL(urlString):
            String(
                format: NSLocalizedString("error.transcription.invalid_url", bundle: .module, comment: ""),
                urlString
            )
        case let .transcriptionFailed(message):
            String(format: NSLocalizedString("error.transcription.failed", bundle: .module, comment: ""), message)
        }
    }
}

