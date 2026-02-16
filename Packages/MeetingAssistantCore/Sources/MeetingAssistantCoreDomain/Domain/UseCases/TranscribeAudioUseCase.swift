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
        inputSource: String? = nil,
        contextItems: [TranscriptionContextItem] = [],
        applyPostProcessing: Bool = false,
        postProcessingPrompt: DomainPostProcessingPrompt? = nil,
        defaultPostProcessingPrompt: DomainPostProcessingPrompt? = nil,
        postProcessingModel: String? = nil,
        autoDetectMeetingType: Bool = false,
        availablePrompts: [DomainPostProcessingPrompt] = [],
        postProcessingContext: String? = nil
    ) async throws -> TranscriptionEntity {
        // Verificar saúde do serviço
        guard try await transcriptionRepository.healthCheck() else {
            throw TranscriptionError.serviceUnavailable
        }

        // Transcrever áudio
        let transcriptionStartTime = Date()
        let response: DomainTranscriptionResponse
        do {
            response = try await transcriptionRepository.transcribe(
                audioURL: audioURL,
                onProgress: nil // No progress reporting from this use case for now
            )
        } catch {
            throw DomainTranscriptionError.transcriptionFailed(error.localizedDescription)
        }
        let transcriptionDuration = Date().timeIntervalSince(transcriptionStartTime)

        // Aplicar pós-processamento se solicitado
        var processedContent: String?
        var promptId: UUID?
        var promptTitle: String?
        var meetingType: String?
        var postProcessingDuration: Double = 0
        let postProcessingInput = mergedPostProcessingInput(
            transcriptionText: response.text,
            context: postProcessingContext
        )

        if applyPostProcessing, let postProcessingRepo = postProcessingRepository {
            let postProcessingStartTime = Date()
            defer {
                postProcessingDuration = Date().timeIntervalSince(postProcessingStartTime)
            }

            do {
                if let prompt = postProcessingPrompt {
                    // Prompt específico fornecido
                    processedContent = try await postProcessingRepo.processTranscription(postProcessingInput, with: prompt)
                    promptId = prompt.id
                    promptTitle = prompt.title
                } else {
                    if autoDetectMeetingType, !availablePrompts.isEmpty {
                        // Autodetecção: classifica o tipo e tenta escolher o prompt mais apropriado.
                        let classification = try await classifyMeeting(text: postProcessingInput, repository: postProcessingRepo)
                        meetingType = classification

                        let normalizedType = classification?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        if let normalizedType,
                           normalizedType != "general",
                           let match = findPrompt(for: normalizedType, in: availablePrompts)
                        {
                            processedContent = try await postProcessingRepo.processTranscription(postProcessingInput, with: match)
                            promptId = match.id
                            promptTitle = match.title
                        } else if let fallback = defaultPostProcessingPrompt {
                            processedContent = try await postProcessingRepo.processTranscription(postProcessingInput, with: fallback)
                            promptId = fallback.id
                            promptTitle = fallback.title
                        } else {
                            processedContent = try await postProcessingRepo.processTranscription(postProcessingInput)
                        }
                    } else if let fallback = defaultPostProcessingPrompt {
                        // Sem autodetecção: usar prompt default (quando fornecido).
                        processedContent = try await postProcessingRepo.processTranscription(postProcessingInput, with: fallback)
                        promptId = fallback.id
                        promptTitle = fallback.title
                    } else {
                        processedContent = try await postProcessingRepo.processTranscription(postProcessingInput)
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
        config.contextItems = contextItems
        config.processedContent = processedContent
        config.postProcessingPromptId = promptId
        config.postProcessingPromptTitle = promptTitle
        config.modelName = response.model
        config.meetingType = meetingType
        config.inputSource = inputSource
        config.transcriptionDuration = transcriptionDuration
        config.postProcessingDuration = processedContent == nil ? 0 : postProcessingDuration
        config.postProcessingModel = processedContent == nil ? nil : postProcessingModel

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
        return parseMeetingType(from: jsonString)
    }

    private func findPrompt(for type: String, in prompts: [DomainPostProcessingPrompt]) -> DomainPostProcessingPrompt? {
        let normalizedType = normalizedMatchKey(type)

        return prompts.first { prompt in
            let normalizedTitle = normalizedMatchKey(prompt.title)
            return normalizedTitle.contains(normalizedType)
        }
    }

    private func parseMeetingType(from jsonString: String) -> String? {
        if let type = parseMeetingTypeFromJSON(jsonString) {
            return type
        }

        // Fallback: try extracting the first JSON object from the string (handles code fences / extra text)
        guard let startIndex = jsonString.firstIndex(of: "{"),
              let endIndex = jsonString.lastIndex(of: "}")
        else {
            return nil
        }
        let candidate = String(jsonString[startIndex...endIndex])
        return parseMeetingTypeFromJSON(candidate)
    }

    private func parseMeetingTypeFromJSON(_ jsonString: String) -> String? {
        guard let data = jsonString.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rawType = object["type"] as? String
        else {
            return nil
        }

        let type = rawType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let allowed = Set(["standup", "presentation", "design_review", "one_on_one", "planning", "general"])
        return allowed.contains(type) ? type : nil
    }

    private func normalizedMatchKey(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined(separator: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func mergedPostProcessingInput(transcriptionText: String, context: String?) -> String {
        guard let context else { return transcriptionText }

        let trimmedContext = context.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContext.isEmpty else { return transcriptionText }

        return """
        \(transcriptionText)

        <CONTEXT_METADATA>
        \(trimmedContext)
        </CONTEXT_METADATA>
        """
    }
}

/// Erros específicos do caso de uso de transcrição
public enum DomainTranscriptionError: Error {
    case serviceUnavailable
    case transcriptionFailed(String)
    case invalidAudioFile
    case postProcessingFailed(String)
}
