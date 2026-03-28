import Combine
import Foundation
import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import os.log

// MARK: - Transcription Client

/// Client for communicating with the local FluidAudio transcription service.
/// Adapts the local model manager to the existing client interface.
@MainActor
public class TranscriptionClient: ObservableObject, TranscriptionService, TranscriptionServiceDiarizationOverride {
    public static let shared = TranscriptionClient()

    private let logger = Logger(subsystem: AppIdentity.logSubsystem, category: "TranscriptionClient")

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
            if FeatureFlags.enableDiarization, AppSettingsStore.shared.isDiarizationEnabled {
                await FluidAIModelManager.shared.loadDiarizationModels()
            }
        }
    }

    /// Transcribe an audio file.
    public func transcribe(
        audioURL: URL,
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> TranscriptionResponse {
        try await transcribe(
            audioURL: audioURL,
            onProgress: onProgress,
            diarizationEnabledOverride: nil
        )
    }

    public func transcribe(
        audioURL: URL,
        onProgress: (@Sendable (Double) -> Void)?,
        diarizationEnabledOverride: Bool?
    ) async throws -> TranscriptionResponse {
        AppLogger.info(
            "Transcribing file",
            category: .transcriptionEngine,
            extra: ["filename": audioURL.lastPathComponent, "implementation": transcriptionImplementation == .xpc ? "XPC" : "local"]
        )

        switch transcriptionImplementation {
        case .xpc:
            return try await transcribeViaXPC(
                audioURL: audioURL,
                onProgress: onProgress,
                diarizationEnabledOverride: diarizationEnabledOverride
            )
        case .local:
            return try await transcribeLocally(
                audioURL: audioURL,
                onProgress: onProgress,
                diarizationEnabledOverride: diarizationEnabledOverride
            )
        }
    }

    private func transcribeViaXPC(
        audioURL: URL,
        onProgress: (@Sendable (Double) -> Void)?,
        diarizationEnabledOverride: Bool?
    ) async throws -> TranscriptionResponse {
        do {
            let response = try await MeetingAssistantAIClient.shared.transcribe(
                audioURL: audioURL,
                diarizationEnabledOverride: diarizationEnabledOverride
            )
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

    private func transcribeLocally(
        audioURL: URL,
        onProgress: (@Sendable (Double) -> Void)?,
        diarizationEnabledOverride: Bool?
    ) async throws -> TranscriptionResponse {
        do {
            let response = try await LocalTranscriptionClient.shared.transcribe(
                audioURL: audioURL,
                isDiarizationEnabled: diarizationEnabledOverride,
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
