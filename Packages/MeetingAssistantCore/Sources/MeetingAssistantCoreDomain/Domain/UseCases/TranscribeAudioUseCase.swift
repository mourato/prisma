// TranscribeAudioUseCase - Caso de uso para transcrever áudio

import Foundation
import MeetingAssistantCoreCommon

/// Caso de uso para transcrever arquivo de áudio
public final class TranscribeAudioUseCase: Sendable {
    private let transcriptionRepository: TranscriptionRepository
    private let transcriptionStorageRepository: TranscriptionStorageRepository
    private let postProcessingRepository: PostProcessingRepository?
    private let transcriptPreprocessor: TranscriptIntelligencePreprocessor

    /// Inicializa o caso de uso com dependências
    public init(
        transcriptionRepository: TranscriptionRepository,
        transcriptionStorageRepository: TranscriptionStorageRepository,
        postProcessingRepository: PostProcessingRepository? = nil,
        transcriptPreprocessor: TranscriptIntelligencePreprocessor = .init()
    ) {
        self.transcriptionRepository = transcriptionRepository
        self.transcriptionStorageRepository = transcriptionStorageRepository
        self.postProcessingRepository = postProcessingRepository
        self.transcriptPreprocessor = transcriptPreprocessor
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
        postProcessingContext: String? = nil,
        kernelMode: IntelligenceKernelMode = .meeting,
        dictationStructuredPostProcessingEnabled: Bool = false
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
        let qualityProfile = transcriptPreprocessor.preprocess(
            transcriptionText: replacedTranscriptionText,
            segments: replacedSegments,
            asrConfidenceScore: response.confidenceScore
        )

        // Aplicar pós-processamento se solicitado
        var processedContent: String?
        var canonicalSummary: CanonicalSummary?
        var promptId: UUID?
        var promptTitle: String?
        var meetingType: String?
        var postProcessingDuration: Double = 0
        let postProcessingInput = mergedPostProcessingInput(
            transcriptionText: qualityProfile.normalizedTextForIntelligence,
            qualityProfile: qualityProfile,
            context: postProcessingContext
        )

        if applyPostProcessing, let postProcessingRepo = postProcessingRepository {
            let postProcessingStartTime = Date()
            defer {
                postProcessingDuration = Date().timeIntervalSince(postProcessingStartTime)
            }
            let useStructuredPipeline = shouldUseStructuredPostProcessing(
                mode: kernelMode,
                dictationStructuredPostProcessingEnabled: dictationStructuredPostProcessingEnabled
            )

            do {
                if let prompt = postProcessingPrompt {
                    // Prompt específico fornecido
                    if useStructuredPipeline {
                        let structuredResult = try await postProcessingRepo.processTranscriptionStructured(
                            postProcessingInput,
                            with: prompt,
                            mode: kernelMode
                        )
                        processedContent = structuredResult.processedText
                        canonicalSummary = recalibrateCanonicalSummary(
                            structuredResult.canonicalSummary,
                            with: qualityProfile
                        )
                    } else {
                        processedContent = try await postProcessingRepo.processTranscription(
                            postProcessingInput,
                            with: prompt,
                            mode: kernelMode
                        )
                        canonicalSummary = nil
                    }
                    promptId = prompt.id
                    promptTitle = prompt.title
                } else {
                    if autoDetectMeetingType, !availablePrompts.isEmpty {
                        // Autodetecção: classifica o tipo e tenta escolher o prompt mais apropriado.
                        let classification = try await classifyMeeting(
                            text: postProcessingInput,
                            mode: kernelMode,
                            repository: postProcessingRepo
                        )
                        meetingType = classification

                        let normalizedType = classification?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        if let normalizedType,
                           normalizedType != "general",
                           let match = findPrompt(for: normalizedType, in: availablePrompts)
                        {
                            if useStructuredPipeline {
                                let structuredResult = try await postProcessingRepo.processTranscriptionStructured(
                                    postProcessingInput,
                                    with: match,
                                    mode: kernelMode
                                )
                                processedContent = structuredResult.processedText
                                canonicalSummary = recalibrateCanonicalSummary(
                                    structuredResult.canonicalSummary,
                                    with: qualityProfile
                                )
                            } else {
                                processedContent = try await postProcessingRepo.processTranscription(
                                    postProcessingInput,
                                    with: match,
                                    mode: kernelMode
                                )
                                canonicalSummary = nil
                            }
                            promptId = match.id
                            promptTitle = match.title
                        } else if let fallback = defaultPostProcessingPrompt {
                            if useStructuredPipeline {
                                let structuredResult = try await postProcessingRepo.processTranscriptionStructured(
                                    postProcessingInput,
                                    with: fallback,
                                    mode: kernelMode
                                )
                                processedContent = structuredResult.processedText
                                canonicalSummary = recalibrateCanonicalSummary(
                                    structuredResult.canonicalSummary,
                                    with: qualityProfile
                                )
                            } else {
                                processedContent = try await postProcessingRepo.processTranscription(
                                    postProcessingInput,
                                    with: fallback,
                                    mode: kernelMode
                                )
                                canonicalSummary = nil
                            }
                            promptId = fallback.id
                            promptTitle = fallback.title
                        } else {
                            if useStructuredPipeline {
                                let structuredResult = try await postProcessingRepo.processTranscriptionStructured(
                                    postProcessingInput,
                                    mode: kernelMode
                                )
                                processedContent = structuredResult.processedText
                                canonicalSummary = recalibrateCanonicalSummary(
                                    structuredResult.canonicalSummary,
                                    with: qualityProfile
                                )
                            } else {
                                processedContent = try await postProcessingRepo.processTranscription(
                                    postProcessingInput,
                                    mode: kernelMode
                                )
                                canonicalSummary = nil
                            }
                        }
                    } else if let fallback = defaultPostProcessingPrompt {
                        // Sem autodetecção: usar prompt default (quando fornecido).
                        if useStructuredPipeline {
                            let structuredResult = try await postProcessingRepo.processTranscriptionStructured(
                                postProcessingInput,
                                with: fallback,
                                mode: kernelMode
                            )
                            processedContent = structuredResult.processedText
                            canonicalSummary = recalibrateCanonicalSummary(
                                structuredResult.canonicalSummary,
                                with: qualityProfile
                            )
                        } else {
                            processedContent = try await postProcessingRepo.processTranscription(
                                postProcessingInput,
                                with: fallback,
                                mode: kernelMode
                            )
                            canonicalSummary = nil
                        }
                        promptId = fallback.id
                        promptTitle = fallback.title
                    } else {
                        if useStructuredPipeline {
                            let structuredResult = try await postProcessingRepo.processTranscriptionStructured(
                                postProcessingInput,
                                mode: kernelMode
                            )
                            processedContent = structuredResult.processedText
                            canonicalSummary = recalibrateCanonicalSummary(
                                structuredResult.canonicalSummary,
                                with: qualityProfile
                            )
                        } else {
                            processedContent = try await postProcessingRepo.processTranscription(
                                postProcessingInput,
                                mode: kernelMode
                            )
                            canonicalSummary = nil
                        }
                    }
                }
            } catch {
                // Pós-processamento falhou, mas transcrição foi bem-sucedida
                AppLogger.error(
                    "Post-processing failed; continuing with raw transcription",
                    category: .transcriptionEngine,
                    error: error
                )
            }
        }

        let transcription = TranscriptionEntity(
            meeting: meeting,
            config: buildConfiguration(
                .init(
                    response: response,
                    replacedText: replacedTranscriptionText,
                    replacedSegments: replacedSegments,
                    qualityProfile: qualityProfile,
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

    private func classifyMeeting(
        text: String,
        mode: IntelligenceKernelMode,
        repository: PostProcessingRepository
    ) async throws -> String? {
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

        let jsonString = try await repository.processTranscription(
            text,
            with: classifierPrompt,
            mode: mode
        )
        return parseMeetingType(from: jsonString)
    }

    private func shouldUseStructuredPostProcessing(
        mode: IntelligenceKernelMode,
        dictationStructuredPostProcessingEnabled: Bool
    ) -> Bool {
        switch mode {
        case .meeting:
            true
        case .dictation, .assistant:
            dictationStructuredPostProcessingEnabled
        }
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
        let qualityProfile: TranscriptionQualityProfile
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
        config.qualityProfile = input.qualityProfile
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

    private func mergedPostProcessingInput(
        transcriptionText: String,
        qualityProfile: TranscriptionQualityProfile,
        context: String?
    ) -> String {
        var blocks = [transcriptionText]
        blocks.append(qualityMetadataBlock(from: qualityProfile))

        if let context {
            let trimmedContext = context.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedContext.isEmpty {
                blocks.append(
                    """
                    <CONTEXT_METADATA>
                    \(trimmedContext)
                    </CONTEXT_METADATA>
                    """
                )
            }
        }

        return blocks.joined(separator: "\n\n")
    }

    private func qualityMetadataBlock(from qualityProfile: TranscriptionQualityProfile) -> String {
        let markerLines: [String]
        if qualityProfile.markers.isEmpty {
            markerLines = ["none"]
        } else {
            markerLines = qualityProfile.markers.map { marker in
                "- [\(marker.reason.rawValue)] \(marker.snippet) [\(marker.startTime)-\(marker.endTime)]"
            }
        }

        return """
        <TRANSCRIPT_QUALITY>
        normalizationVersion: \(qualityProfile.normalizationVersion)
        overallConfidence: \(qualityProfile.overallConfidence)
        containsUncertainty: \(qualityProfile.containsUncertainty)
        markers:
        \(markerLines.joined(separator: "\n"))
        </TRANSCRIPT_QUALITY>
        """
    }

    private func recalibrateCanonicalSummary(
        _ summary: CanonicalSummary,
        with qualityProfile: TranscriptionQualityProfile
    ) -> CanonicalSummary {
        let trustFlags = CanonicalSummary.TrustFlags(
            isGroundedInTranscript: summary.trustFlags.isGroundedInTranscript,
            containsSpeculation: summary.trustFlags.containsSpeculation || qualityProfile.containsUncertainty,
            isHumanReviewed: summary.trustFlags.isHumanReviewed,
            confidenceScore: min(summary.trustFlags.confidenceScore, qualityProfile.overallConfidence)
        )

        return CanonicalSummary(
            schemaVersion: summary.schemaVersion,
            generatedAt: summary.generatedAt,
            summary: summary.summary,
            keyPoints: summary.keyPoints,
            decisions: summary.decisions,
            actionItems: summary.actionItems,
            openQuestions: summary.openQuestions,
            trustFlags: trustFlags
        )
    }
}

/// Erros específicos do caso de uso de transcrição
public enum DomainTranscriptionError: Error {
    case serviceUnavailable
    case transcriptionFailed(String)
    case invalidAudioFile
    case postProcessingFailed(String)
}
