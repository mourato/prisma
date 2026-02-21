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
        vocabularyReplacementRules: [VocabularyReplacementRule] = [],
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
        let replacedTranscriptionText = applyVocabularyReplacements(
            to: response.text,
            with: vocabularyReplacementRules
        )
        let replacedSegments = applyVocabularyReplacements(
            to: response.segments,
            with: vocabularyReplacementRules
        )

        // Aplicar pós-processamento se solicitado
        var processedContent: String?
        var canonicalSummary: CanonicalSummary?
        var promptId: UUID?
        var promptTitle: String?
        var meetingType: String?
        var postProcessingDuration: Double = 0
        let postProcessingInput = mergedPostProcessingInput(
            transcriptionText: replacedTranscriptionText,
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
                    let structuredResult = try await postProcessingRepo.processTranscriptionStructured(
                        postProcessingInput,
                        with: prompt
                    )
                    processedContent = structuredResult.processedText
                    canonicalSummary = structuredResult.canonicalSummary
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
                            let structuredResult = try await postProcessingRepo.processTranscriptionStructured(
                                postProcessingInput,
                                with: match
                            )
                            processedContent = structuredResult.processedText
                            canonicalSummary = structuredResult.canonicalSummary
                            promptId = match.id
                            promptTitle = match.title
                        } else if let fallback = defaultPostProcessingPrompt {
                            let structuredResult = try await postProcessingRepo.processTranscriptionStructured(
                                postProcessingInput,
                                with: fallback
                            )
                            processedContent = structuredResult.processedText
                            canonicalSummary = structuredResult.canonicalSummary
                            promptId = fallback.id
                            promptTitle = fallback.title
                        } else {
                            let structuredResult = try await postProcessingRepo.processTranscriptionStructured(postProcessingInput)
                            processedContent = structuredResult.processedText
                            canonicalSummary = structuredResult.canonicalSummary
                        }
                    } else if let fallback = defaultPostProcessingPrompt {
                        // Sem autodetecção: usar prompt default (quando fornecido).
                        let structuredResult = try await postProcessingRepo.processTranscriptionStructured(
                            postProcessingInput,
                            with: fallback
                        )
                        processedContent = structuredResult.processedText
                        canonicalSummary = structuredResult.canonicalSummary
                        promptId = fallback.id
                        promptTitle = fallback.title
                    } else {
                        let structuredResult = try await postProcessingRepo.processTranscriptionStructured(postProcessingInput)
                        processedContent = structuredResult.processedText
                        canonicalSummary = structuredResult.canonicalSummary
                    }
                }
            } catch {
                // Pós-processamento falhou, mas transcrição foi bem-sucedida
                // swiftlint:disable:next disallow_print_and_nslog
                print("Post-processing failed: \(error)")
            }
        }

        let transcription = TranscriptionEntity(
            meeting: meeting,
            config: buildConfiguration(
                .init(
                    response: response,
                    replacedText: replacedTranscriptionText,
                    replacedSegments: replacedSegments,
                    contextItems: contextItems,
                    processedContent: processedContent,
                    canonicalSummary: canonicalSummary,
                    promptId: promptId,
                    promptTitle: promptTitle,
                    meetingType: meetingType,
                    inputSource: inputSource,
                    transcriptionDuration: transcriptionDuration,
                    postProcessingDuration: postProcessingDuration,
                    postProcessingModel: postProcessingModel
                )
            )
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

    private func applyVocabularyReplacements(
        to text: String,
        with rules: [VocabularyReplacementRule]
    ) -> String {
        var output = text

        for rule in rules {
            let find = rule.find.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !find.isEmpty else { continue }

            let escapedFind = NSRegularExpression.escapedPattern(for: find)
            let pattern = "\\b\(escapedFind)\\b"

            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }

            let escapedReplacement = NSRegularExpression.escapedTemplate(for: rule.replace)
            let range = NSRange(output.startIndex..<output.endIndex, in: output)
            output = regex.stringByReplacingMatches(
                in: output,
                options: [],
                range: range,
                withTemplate: escapedReplacement
            )
        }

        return output
    }

    private func applyVocabularyReplacements(
        to segments: [DomainTranscriptionSegment],
        with rules: [VocabularyReplacementRule]
    ) -> [DomainTranscriptionSegment] {
        segments.map { segment in
            DomainTranscriptionSegment(
                id: segment.id,
                speaker: segment.speaker,
                text: applyVocabularyReplacements(to: segment.text, with: rules),
                startTime: segment.startTime,
                endTime: segment.endTime
            )
        }
    }

    private struct ConfigurationBuildInput {
        let response: DomainTranscriptionResponse
        let replacedText: String
        let replacedSegments: [DomainTranscriptionSegment]
        let contextItems: [TranscriptionContextItem]
        let processedContent: String?
        let canonicalSummary: CanonicalSummary?
        let promptId: UUID?
        let promptTitle: String?
        let meetingType: String?
        let inputSource: String?
        let transcriptionDuration: Double
        let postProcessingDuration: Double
        let postProcessingModel: String?
    }

    private func buildConfiguration(_ input: ConfigurationBuildInput) -> TranscriptionEntity.Configuration {
        var config = TranscriptionEntity.Configuration(
            text: input.processedContent ?? input.replacedText,
            rawText: input.response.text,
            segments: input.replacedSegments.map { segment in
                TranscriptionEntity.Segment(
                    speaker: segment.speaker,
                    text: segment.text,
                    startTime: segment.startTime,
                    endTime: segment.endTime
                )
            },
            language: input.response.language
        )
        config.contextItems = input.contextItems
        config.processedContent = input.processedContent
        config.canonicalSummary = input.canonicalSummary
        config.postProcessingPromptId = input.promptId
        config.postProcessingPromptTitle = input.promptTitle
        config.modelName = input.response.model
        config.meetingType = input.meetingType
        config.inputSource = input.inputSource
        config.transcriptionDuration = input.transcriptionDuration
        config.postProcessingDuration = input.processedContent == nil ? 0 : input.postProcessingDuration
        config.postProcessingModel = input.processedContent == nil ? nil : input.postProcessingModel
        return config
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
