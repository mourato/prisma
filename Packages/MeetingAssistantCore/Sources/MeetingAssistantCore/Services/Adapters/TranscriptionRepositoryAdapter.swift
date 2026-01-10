// TranscriptionRepositoryAdapter - Adapter para TranscriptionRepository usando TranscriptionClient

import Foundation

/// Adapter que implementa TranscriptionRepository usando TranscriptionClient existente
@MainActor
public final class TranscriptionRepositoryAdapter: TranscriptionRepository {
    private let transcriptionClient: TranscriptionClient

    public init(transcriptionClient: TranscriptionClient) {
        self.transcriptionClient = transcriptionClient
    }

    public func healthCheck() async throws -> Bool {
        return try await transcriptionClient.healthCheck()
    }

    public func fetchServiceStatus() async throws -> DomainServiceStatusResponse {
        let status = try await transcriptionClient.fetchServiceStatus()
        return DomainServiceStatusResponse(
            status: status.status,
            message: "Model: \(status.modelName), State: \(status.modelState)",
            timestamp: Date()
        )
    }

    public func transcribe(audioURL: URL) async throws -> DomainTranscriptionResponse {
        let response = try await transcriptionClient.transcribe(audioURL: audioURL)
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
            processedAt: response.processedAt
        )
    }
}