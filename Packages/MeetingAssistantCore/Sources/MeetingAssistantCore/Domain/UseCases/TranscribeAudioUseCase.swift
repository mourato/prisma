// TranscribeAudioUseCase - Caso de uso para transcrever áudio

import Foundation

/// Caso de uso para transcrever arquivo de áudio
public final class TranscribeAudioUseCase: Sendable {
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
        postProcessingPrompt: DomainPostProcessingPrompt? = nil,
        availablePrompts: [DomainPostProcessingPrompt] = []
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
        var meetingType: String?

        if applyPostProcessing, let postProcessingRepo = postProcessingRepository {
            do {
                if let prompt = postProcessingPrompt {
                    // Prompt específico fornecido
                    processedContent = try await postProcessingRepo.processTranscription(response.text, with: prompt)
                    promptId = prompt.id
                    promptTitle = prompt.title
                } else {
                    // Autodetecção ou Prompt Geral
                    if !availablePrompts.isEmpty {
                        let classification = try await classifyMeeting(text: response.text, repository: postProcessingRepo)
                        meetingType = classification
                        
                        // Tentar encontrar prompt correspondente ao tipo
                        if let type = classification,
                           let match = findPrompt(for: type, in: availablePrompts) {
                                processedContent = try await postProcessingRepo.processTranscription(response.text, with: match)
                                promptId = match.id
                                promptTitle = match.title
                           } else {
                               // Fallback
                               processedContent = try await postProcessingRepo.processTranscription(response.text)
                           }
                    } else {
                        processedContent = try await postProcessingRepo.processTranscription(response.text)
                    }
                }
            } catch {
                // Pós-processamento falhou, mas transcrição foi bem-sucedida
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
        config.meetingType = meetingType

        let transcription = TranscriptionEntity(
            meeting: meeting,
            config: config
        )

        // Salvar transcrição
        try await transcriptionStorageRepository.saveTranscription(transcription)

        return transcription
    }


    // MARK: - Private Helpers

    private func classifyMeeting(text: String, repository: PostProcessingRepository) async throws -> String? {
        let classifierPrompt = DomainPostProcessingPrompt(
            id: UUID(),
            title: "Classifier",
            content: """
            Analise a transcrição e classifique o tipo de reunião.
            Responda APENAS com o JSON no seguinte formato:
            { "type": "VALOR" }
            Valores possíveis: standup, presentation, design_review, one_on_one, planning, general.
            """,
            isDefault: false
        )
        
        let jsonString = try await repository.processTranscription(text, with: classifierPrompt)
        
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let type = json["type"] else {
            return nil
        }
        return type
    }
    
    private func findPrompt(for type: String, in prompts: [DomainPostProcessingPrompt]) -> DomainPostProcessingPrompt? {
        return prompts.first { $0.title.localizedCaseInsensitiveContains(type) }
    }
}

/// Erros específicos do caso de uso de transcrição
public enum DomainTranscriptionError: Error {
    case serviceUnavailable
    case transcriptionFailed(String)
    case invalidAudioFile
    case postProcessingFailed(String)
}
