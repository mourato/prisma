import Foundation
import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

extension PostProcessingService {
    struct StructuredRequestContext {
        let transcription: String
        let prompt: PostProcessingPrompt
        let mode: IntelligenceKernelMode
        let systemPromptOverride: String?
        let requestProfile: RequestProfile
        let requestConfig: AIConfiguration
        let traceContext: RequestTraceContext
        let startedAt: Date
    }

    // MARK: - Public API (Structured)

    public func processTranscriptionStructured(_ transcription: String) async throws -> DomainPostProcessingResult {
        guard settings.postProcessingEnabled else {
            let fallback = summaryFallbackBuilder.build(providerOutput: "", transcription: transcription)
            AppLogger.info(
                "Post-processing disabled, returning deterministic structured fallback",
                category: .transcriptionEngine
            )
            return fallback
        }

        guard let prompt = settings.selectedPrompt else {
            throw PostProcessingError.noPromptSelected
        }

        return try await processTranscriptionStructured(transcription, with: prompt)
    }

    public func processTranscriptionStructured(
        _ transcription: String,
        with prompt: PostProcessingPrompt
    ) async throws -> DomainPostProcessingResult {
        try await processTranscriptionStructured(
            transcription,
            with: prompt,
            mode: .meeting,
            systemPromptOverride: nil
        )
    }

    public func processTranscriptionStructured(
        _ transcription: String,
        with prompt: PostProcessingPrompt,
        mode: IntelligenceKernelMode
    ) async throws -> DomainPostProcessingResult {
        try await processTranscriptionStructured(
            transcription,
            with: prompt,
            mode: mode,
            systemPromptOverride: nil
        )
    }

    func processTranscriptionStructured(
        _ transcription: String,
        with prompt: PostProcessingPrompt,
        mode: IntelligenceKernelMode,
        systemPromptOverride: String?
    ) async throws -> DomainPostProcessingResult {
        _ = try validateInput(transcription)
        guard settings.isEnhancementsInferenceReady(for: mode) else {
            throw unavailableConfigurationError(
                mode: mode,
                message: "Structured post-processing blocked: enhancements configuration not ready"
            )
        }

        let context = makeStructuredRequestContext(
            transcription: transcription,
            prompt: prompt,
            mode: mode,
            systemPromptOverride: systemPromptOverride
        )

        if !context.requestProfile.useStructuredPipeline {
            return try await runFastStructuredFallback(from: context)
        }

        isProcessing = true
        lastError = nil
        defer {
            isProcessing = false
            reportDictationPostProcessingDurationIfNeeded(mode: mode, startedAt: context.startedAt)
        }

        do {
            let result = try await sendToAIStructured(
                transcription: context.transcription,
                prompt: context.prompt,
                mode: context.mode,
                systemPromptOverride: context.systemPromptOverride,
                requestProfile: context.requestProfile,
                traceContext: context.traceContext
            )

            AppLogger.info(
                "Structured post-processing completed",
                category: .transcriptionEngine,
                extra: traceExtra(
                    from: context.traceContext,
                    attempt: 1,
                    elapsedMilliseconds: Date().timeIntervalSince(context.startedAt) * 1_000,
                    extra: ["output_state": result.outputState.rawValue]
                )
            )
            return result
        } catch {
            return try await handleStructuredFailure(context: context, error: error)
        }
    }

    private func makeStructuredRequestContext(
        transcription: String,
        prompt: PostProcessingPrompt,
        mode: IntelligenceKernelMode,
        systemPromptOverride: String?
    ) -> StructuredRequestContext {
        let requestProfile = profile(for: mode, prefersStructuredPipeline: true)
        let requestConfig = settings.resolvedEnhancementsAIConfiguration(for: mode)
        let traceContext = makeTraceContext(
            mode: mode,
            provider: requestConfig.provider,
            model: requestConfig.selectedModel,
            prompt: prompt,
            pipeline: requestProfile.pipeline
        )

        return StructuredRequestContext(
            transcription: transcription,
            prompt: prompt,
            mode: mode,
            systemPromptOverride: systemPromptOverride,
            requestProfile: requestProfile,
            requestConfig: requestConfig,
            traceContext: traceContext,
            startedAt: Date()
        )
    }

    private func runFastStructuredFallback(from context: StructuredRequestContext) async throws -> DomainPostProcessingResult {
        let fastResult = try await processTranscription(
            context.transcription,
            with: context.prompt,
            mode: context.mode,
            systemPromptOverride: context.systemPromptOverride
        )
        let fallbackSummary = summaryFallbackBuilder.build(
            providerOutput: fastResult,
            transcription: context.transcription
        )
        return DomainPostProcessingResult(
            processedText: fastResult,
            canonicalSummary: fallbackSummary.canonicalSummary,
            outputState: .deterministicFallback
        )
    }

    private func handleStructuredFailure(
        context: StructuredRequestContext,
        error: Error
    ) async throws -> DomainPostProcessingResult {
        let processingError = normalizePostProcessingError(error)

        guard shouldTriggerDictationTimeoutFallback(for: context.mode, error: processingError) else {
            lastError = processingError
            throw processingError
        }

        reportDictationFallbackMetrics()

        AppLogger.warning(
            "Structured dictation timed out; running fast fallback",
            category: .transcriptionEngine,
            extra: traceExtra(
                from: context.traceContext,
                attempt: 1,
                elapsedMilliseconds: Date().timeIntervalSince(context.startedAt) * 1_000
            )
        )

        return try await runStructuredFallback(from: context)
    }

    private func runStructuredFallback(from context: StructuredRequestContext) async throws -> DomainPostProcessingResult {
        let fallbackProfile = dictationFallbackProfile()
        let fallbackPrompt = PostProcessingPrompt.cleanTranscription
        let fallbackTraceContext = makeTraceContext(
            mode: context.mode,
            provider: context.requestConfig.provider,
            model: context.requestConfig.selectedModel,
            prompt: fallbackPrompt,
            pipeline: fallbackProfile.pipeline
        )

        do {
            let fallbackText = try await sendToAI(
                transcription: context.transcription,
                prompt: fallbackPrompt,
                mode: context.mode,
                systemPromptOverride: nil,
                requestProfile: fallbackProfile,
                traceContext: fallbackTraceContext
            )
            let fallbackSummary = summaryFallbackBuilder.build(
                providerOutput: fallbackText,
                transcription: context.transcription
            )
            return DomainPostProcessingResult(
                processedText: fallbackText,
                canonicalSummary: fallbackSummary.canonicalSummary,
                outputState: .deterministicFallback
            )
        } catch {
            let fallbackError = normalizePostProcessingError(error)
            lastError = fallbackError
            throw fallbackError
        }
    }
}
