// PostProcessingRepositoryAdapter - Adapter para PostProcessingRepository usando PostProcessingService
// Seguindo Clean Architecture

import Foundation
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

/// Adapter que implementa PostProcessingRepository usando PostProcessingService existente
@MainActor
public final class PostProcessingRepositoryAdapter: PostProcessingRepository {
    private let postProcessingService: any PostProcessingServiceProtocol

    public init(postProcessingService: any PostProcessingServiceProtocol) {
        self.postProcessingService = postProcessingService
    }

    public func processTranscription(_ transcription: String) async throws -> String {
        try await postProcessingService.processTranscription(transcription)
    }

    public func processTranscription(
        _ transcription: String,
        with prompt: DomainPostProcessingPrompt
    ) async throws -> String {
        // Converter DomainPostProcessingPrompt para PostProcessingPrompt (legado)
        let legacyPrompt = PostProcessingPrompt(
            id: prompt.id,
            title: prompt.title,
            promptText: prompt.content,
            isActive: true
        )
        return try await postProcessingService.processTranscription(transcription, with: legacyPrompt)
    }

    public func processTranscriptionStructured(_ transcription: String) async throws -> DomainPostProcessingResult {
        try await postProcessingService.processTranscriptionStructured(transcription)
    }

    public func processTranscriptionStructured(
        _ transcription: String,
        with prompt: DomainPostProcessingPrompt
    ) async throws -> DomainPostProcessingResult {
        let legacyPrompt = PostProcessingPrompt(
            id: prompt.id,
            title: prompt.title,
            promptText: prompt.content,
            isActive: true
        )
        return try await postProcessingService.processTranscriptionStructured(transcription, with: legacyPrompt)
    }
}
