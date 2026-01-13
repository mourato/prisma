// PostProcessingRepositoryAdapter - Adapter para PostProcessingRepository usando PostProcessingService
// Seguindo Clean Architecture

import Foundation

/// Adapter que implementa PostProcessingRepository usando PostProcessingService existente
@MainActor
public final class PostProcessingRepositoryAdapter: PostProcessingRepository {
    private let postProcessingService: any PostProcessingServiceProtocol

    public init(postProcessingService: PostProcessingServiceProtocol) {
        self.postProcessingService = postProcessingService
    }

    public func processTranscription(_ transcription: String) async throws -> String {
        return try await postProcessingService.processTranscription(transcription)
    }

    public func processTranscription(_ transcription: String, with prompt: DomainPostProcessingPrompt) async throws -> String {
        // Converter DomainPostProcessingPrompt para PostProcessingPrompt (legado)
        let legacyPrompt = PostProcessingPrompt(
            id: prompt.id,
            title: prompt.title,
            promptText: prompt.content,
            isActive: true
        )
        return try await postProcessingService.processTranscription(transcription, with: legacyPrompt)
    }
}
