// TranscriptionRepositoryAdapter - Adapter para TranscriptionRepository usando TranscriptionClient

import Foundation
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

/// Adapter que implementa TranscriptionRepository usando TranscriptionClient existente
@MainActor
public final class TranscriptionRepositoryAdapter: TranscriptionRepository, TranscriptionRepositoryDiarizationOverride {
    private let transcriptionService: any TranscriptionService

    public init(transcriptionService: any TranscriptionService) {
        self.transcriptionService = transcriptionService
    }

    public func healthCheck() async throws -> Bool {
        try await transcriptionService.healthCheck()
    }

    public func fetchServiceStatus() async throws -> DomainServiceStatusResponse {
        let status = try await transcriptionService.fetchServiceStatus()
        return DomainServiceStatusResponse(
            status: status.status,
            message: "Model: \(status.modelName), State: \(status.modelState)",
            timestamp: Date()
        )
    }

    public func transcribe(
        audioURL: URL,
        onProgress: (@Sendable (Double) -> Void)?
    ) async throws -> DomainTranscriptionResponse {
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
    ) async throws -> DomainTranscriptionResponse {
        let response: TranscriptionResponse
        if let diarizationAwareService = transcriptionService as? any TranscriptionServiceDiarizationOverride {
            response = try await diarizationAwareService.transcribe(
                audioURL: audioURL,
                onProgress: onProgress,
                diarizationEnabledOverride: diarizationEnabledOverride
            )
        } else {
            response = try await transcriptionService.transcribe(
                audioURL: audioURL,
                onProgress: onProgress
            )
        }

        return mapToDomainResponse(response)
    }

    private func mapToDomainResponse(_ response: TranscriptionResponse) -> DomainTranscriptionResponse {
        return DomainTranscriptionResponse(
            text: response.text,
            segments: response.segments.map { segment in
                DomainTranscriptionSegment(
                    speaker: segment.speaker,
                    text: segment.text,
                    startTime: segment.startTime,
                    endTime: segment.endTime
                )
            },
            language: response.language,
            durationSeconds: response.durationSeconds,
            model: response.model,
            processedAt: response.processedAt,
            confidenceScore: response.confidenceScore
        )
    }
}
