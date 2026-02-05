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

    private let logger = Logger(subsystem: "MeetingAssistant", category: "TranscriptionClient")

    /// The underlying transcription implementation based on feature flags.
    private enum TranscriptionImplementation {
        case xpc
        case local
    }

    private var transcriptionImplementation: TranscriptionImplementation {
        FeatureFlags.useXPCService ? .xpc : .local
    }

    private init() {}

    /// Check if the transcription service is healthy.
    public func healthCheck() async throws -> Bool {
        switch transcriptionImplementation {
        case .xpc:
            do {
                let status = try await MeetingAssistantAIClient.shared.fetchServiceStatus()
                return status.status == "healthy"
            } catch {
                return false
            }
        case .local:
            return FluidAIModelManager.shared.modelState == .loaded
        }
    }

    /// Fetch detailed service status.
    public func fetchServiceStatus() async throws -> ServiceStatusResponse {
        switch transcriptionImplementation {
        case .xpc:
            let xpcStatus = try await MeetingAssistantAIClient.shared.fetchServiceStatus()
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
        case .local:
            let state = FluidAIModelManager.shared.modelState
            return ServiceStatusResponse(
                status: state == .error ? "unhealthy" : "healthy",
                modelState: state.rawValue,
                modelLoaded: state == .loaded,
                device: "ANE",
                modelName: "parakeet-tdt-0.6b-v3-coreml",
                uptimeSeconds: 0,
                lastTranscriptionTime: nil,
                totalTranscriptions: 0,
                totalAudioProcessedSeconds: 0
            )
        }
    }

    /// Warm up the transcription model.
    public func warmupModel() async throws {
        switch transcriptionImplementation {
        case .xpc:
            try await MeetingAssistantAIClient.shared.warmupModel()
        case .local:
            await FluidAIModelManager.shared.loadModels()
        }
    }

    /// Transcribe an audio file.
    public func transcribe(
        audioURL: URL,
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> TranscriptionResponse {
        AppLogger.info(
            "Transcribing file",
            category: .transcriptionEngine,
            extra: ["filename": audioURL.lastPathComponent, "implementation": transcriptionImplementation == .xpc ? "XPC" : "local"]
        )

        switch transcriptionImplementation {
        case .xpc:
            return try await transcribeViaXPC(audioURL: audioURL, onProgress: onProgress)
        case .local:
            return try await transcribeLocally(audioURL: audioURL, onProgress: onProgress)
        }
    }

    private func transcribeViaXPC(audioURL: URL, onProgress: (@Sendable (Double) -> Void)?) async throws -> TranscriptionResponse {
        do {
            let response = try await MeetingAssistantAIClient.shared.transcribe(audioURL: audioURL)
            AppLogger.info(
                "Transcription completed via XPC",
                category: .transcriptionEngine,
                extra: ["words": response.text.split(separator: " ").count]
            )
            return response
        } catch {
            AppLogger.error(
                "Transcription failed via XPC",
                category: .transcriptionEngine,
                error: error,
                extra: ["filename": audioURL.lastPathComponent]
            )
            throw error
        }
    }

    private func transcribeLocally(audioURL: URL, onProgress: (@Sendable (Double) -> Void)?) async throws -> TranscriptionResponse {
        do {
            let response = try await LocalTranscriptionClient.shared.transcribe(
                audioURL: audioURL,
                onProgress: onProgress
            )
            AppLogger.info(
                "Transcription completed locally",
                category: .transcriptionEngine,
                extra: ["words": response.text.split(separator: " ").count]
            )
            return response
        } catch {
            AppLogger.error(
                "Transcription failed locally",
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

