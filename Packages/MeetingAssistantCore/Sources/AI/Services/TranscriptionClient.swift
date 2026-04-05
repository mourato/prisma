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

    public enum CachedReadinessState: String, Sendable {
        case unknown
        case healthy
        case unhealthy
    }

    /// The underlying transcription implementation based on feature flags.
    private enum TranscriptionImplementation {
        case xpc
        case local
    }

    private var transcriptionImplementation: TranscriptionImplementation {
        FeatureFlags.useXPCService ? .xpc : .local
    }

    @Published public private(set) var cachedReadinessState: CachedReadinessState = .unknown

    public var supportsIncrementalTranscription: Bool {
        transcriptionImplementation == .local
    }

    private init() {}

    /// Check if the transcription service is healthy.
    public func healthCheck() async throws -> Bool {
        let isHealthy: Bool
        switch transcriptionImplementation {
        case .xpc:
            do {
                let status = try await MeetingAssistantAIClient.shared.fetchServiceStatus()
                isHealthy = status.status == "healthy"
            } catch {
                isHealthy = false
            }
        case .local:
            isHealthy = FluidAIModelManager.shared.modelState == .loaded
        }
        updateCachedReadiness(isHealthy ? .healthy : .unhealthy)
        return isHealthy
    }

    /// Fetch detailed service status.
    public func fetchServiceStatus() async throws -> ServiceStatusResponse {
        switch transcriptionImplementation {
        case .xpc:
            let xpcStatus = try await MeetingAssistantAIClient.shared.fetchServiceStatus()
            updateCachedReadiness(xpcStatus.status == "healthy" ? .healthy : .unhealthy)
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
            updateCachedReadiness(state == .loaded ? .healthy : (state == .error ? .unhealthy : .unknown))
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
            do {
                try await MeetingAssistantAIClient.shared.warmupModel()
                updateCachedReadiness(.healthy)
            } catch {
                updateCachedReadiness(.unhealthy)
                throw error
            }
        case .local:
            await FluidAIModelManager.shared.loadModels()
            if FeatureFlags.enableDiarization, AppSettingsStore.shared.isDiarizationEnabled {
                await FluidAIModelManager.shared.loadDiarizationModels()
            }
            updateCachedReadiness(FluidAIModelManager.shared.modelState == .loaded ? .healthy : .unhealthy)
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

    public func transcribe(samples: [Float]) async throws -> TranscriptionResponse {
        AppLogger.info(
            "Transcribing in-memory samples",
            category: .transcriptionEngine,
            extra: ["sampleCount": samples.count, "implementation": transcriptionImplementation == .xpc ? "XPC" : "local"]
        )

        guard supportsIncrementalTranscription else {
            updateCachedReadiness(.unhealthy)
            throw TranscriptionError.transcriptionFailed("Incremental transcription unsupported in current backend")
        }

        do {
            let response = try await LocalTranscriptionClient.shared.transcribe(samples: samples)
            updateCachedReadiness(.healthy)
            return response
        } catch {
            updateCachedReadiness(.unhealthy)
            throw error
        }
    }

    public func warmupModelIfNeededInBackground() {
        guard FeatureFlags.enableCachedTranscriptionReadinessGate else { return }
        guard cachedReadinessState != .healthy else { return }

        Task { @MainActor [weak self] in
            do {
                try await self?.warmupModel()
            } catch {
                self?.logger.error("Background warmup failed: \(error.localizedDescription)")
            }
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
            updateCachedReadiness(.healthy)
            AppLogger.info(
                "Transcription completed via XPC",
                category: .transcriptionEngine,
                extra: ["words": response.text.split(separator: " ").count]
            )
            return response
        } catch {
            updateCachedReadiness(.unhealthy)
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
            updateCachedReadiness(.healthy)
            AppLogger.info(
                "Transcription completed locally",
                category: .transcriptionEngine,
                extra: ["words": response.text.split(separator: " ").count]
            )
            return response
        } catch {
            updateCachedReadiness(.unhealthy)
            AppLogger.error(
                "Transcription failed locally",
                category: .transcriptionEngine,
                error: error,
                extra: ["filename": audioURL.lastPathComponent]
            )
            throw error
        }
    }

    private func updateCachedReadiness(_ state: CachedReadinessState) {
        guard FeatureFlags.enableCachedTranscriptionReadinessGate else { return }
        cachedReadinessState = state
    }

    deinit {
        AppLogger.debug("TranscriptionClient deinitialized", category: .transcriptionEngine)
    }
}
