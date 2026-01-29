// TranscribeAudioUseCase - Caso de uso para transcrever áudio

import Foundation

/// Caso de uso para transcrever arquivo de áudio
public final class TranscribeAudioUseCase {
    private let transcriptionRepository: TranscriptionRepository
    private let transcriptionStorageRepository: TranscriptionStorageRepository
    private let postProcessingRepository: PostProcessingRepository?

    /// Inicializa o caso de uso com dependências
    public init(
        transcriptionRepository: TranscriptionRepository,
        transcriptionStorageRepository: TranscriptionStorageRepository,
        postProcessingRepository: PostProcessingRepository? = nil
    ) {
        self.transcriptionRepository = transcriptionRepository
        self.transcriptionStorageRepository = transcriptionStorageRepository
        self.postProcessingRepository = postProcessingRepository
    }

    /// Executa o caso de uso para transcrever áudio
    /// - Parameters:
    ///   - audioURL: URL do arquivo de áudio a transcrever
    ///   - meeting: Reunião associada à transcrição
    ///   - applyPostProcessing: Se deve aplicar pós-processamento
    ///   - postProcessingPrompt: Prompt específico para pós-processamento (opcional)
    /// - Returns: Entidade de transcrição criada
    /// - Throws: TranscriptionError se falhar na transcrição
    public func execute(
        audioURL: URL,
        meeting: MeetingEntity,
        applyPostProcessing: Bool = false,
        postProcessingPrompt: DomainPostProcessingPrompt? = nil
    ) async throws -> TranscriptionEntity {
        // Verificar saúde do serviço
        guard try await transcriptionRepository.healthCheck() else {
            throw TranscriptionError.serviceUnavailable
        }

        // Transcrever áudio
        let response: DomainTranscriptionResponse
        do {
            response = try await transcriptionRepository.transcribe(
                audioURL: audioURL,
                onProgress: nil // No progress reporting from this use case for now
            )
        } catch {
            throw DomainTranscriptionError.transcriptionFailed(error.localizedDescription)
        }

        // Aplicar pós-processamento se solicitado
        var processedContent: String?
        var promptId: UUID?
        var promptTitle: String?

        if applyPostProcessing, let postProcessingRepo = postProcessingRepository {
            do {
                if let prompt = postProcessingPrompt {
                    processedContent = try await postProcessingRepo.processTranscription(response.text, with: prompt)
                    promptId = prompt.id
                    promptTitle = prompt.title
                } else {
                    processedContent = try await postProcessingRepo.processTranscription(response.text)
                }
            } catch {
                // Pós-processamento falhou, mas transcrição foi bem-sucedida
                // Não falhar o caso de uso inteiro por isso
                // swiftlint:disable:next disallow_print_and_nslog
                print("Post-processing failed: \(error)")
            }
        }

        // Criar entidade de transcrição
        var config = TranscriptionEntity.Configuration(
            text: processedContent ?? response.text,
            rawText: response.text,
            segments: response.segments.map { segment in
                TranscriptionEntity.Segment(
                    speaker: segment.speaker,
                    text: segment.text,
                    startTime: segment.startTime,
                    endTime: segment.endTime
                )
            },
            language: response.language
        )
        config.processedContent = processedContent
        config.postProcessingPromptId = promptId
        config.postProcessingPromptTitle = promptTitle
        config.modelName = response.model

        let transcription = TranscriptionEntity(
            meeting: meeting,
            config: config
        )

        // Salvar transcrição
        try await transcriptionStorageRepository.saveTranscription(transcription)

        return transcription
    }
}

/// Erros específicos do caso de uso de transcrição
public enum DomainTranscriptionError: Error {
    case serviceUnavailable
    case transcriptionFailed(String)
    case invalidAudioFile
    case postProcessingFailed(String)
}
