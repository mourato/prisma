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
        guard try await self.transcriptionRepository.healthCheck() else {
            throw TranscriptionError.serviceUnavailable
        }

        // Transcrever áudio
        let response: DomainTranscriptionResponse
        do {
            response = try await self.transcriptionRepository.transcribe(audioURL: audioURL)
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
        let transcription = TranscriptionEntity(
            meeting: meeting,
            segments: response.segments.map { segment in
                TranscriptionEntity.Segment(
                    speaker: segment.speaker,
                    text: segment.text,
                    startTime: segment.startTime,
                    endTime: segment.endTime
                )
            },
            text: processedContent ?? response.text,
            rawText: response.text,
            processedContent: processedContent,
            postProcessingPromptId: promptId,
            postProcessingPromptTitle: promptTitle,
            language: response.language,
            modelName: response.model
        )

        // Salvar transcrição
        try await self.transcriptionStorageRepository.saveTranscription(transcription)

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