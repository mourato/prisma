import Foundation
import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

extension PostProcessingService {
    struct LegacyRequestContext {
        let transcription: String
        let prompt: PostProcessingPrompt
        let mode: IntelligenceKernelMode
        let systemPromptOverride: String?
        let requestProfile: RequestProfile
        let requestConfig: AIConfiguration
        let traceContext: RequestTraceContext
        let startedAt: Date
    }

    // MARK: - Public API (Legacy String)

    /// Processes a transcription using the currently selected prompt.
    /// - Parameter transcription: The raw transcription text.
    /// - Returns: The processed text from the AI.
    public func processTranscription(_ transcription: String) async throws -> String {
        guard settings.postProcessingEnabled else {
            AppLogger.info("Post-processing disabled, skipping", category: .transcriptionEngine)
            return transcription
        }

        guard let prompt = settings.selectedPrompt else {
            throw PostProcessingError.noPromptSelected
        }

        return try await processTranscription(transcription, with: prompt)
    }

    /// Processes a transcription using a specific prompt.
    /// - Parameters:
    ///   - transcription: The raw transcription text.
    ///   - prompt: The prompt to use for processing.
    /// - Returns: The processed text from the AI.
    public func processTranscription(
        _ transcription: String,
        with prompt: PostProcessingPrompt
    ) async throws -> String {
        try await processTranscription(
            transcription,
            with: prompt,
            mode: .meeting,
            systemPromptOverride: nil
        )
    }

    public func processTranscription(
        _ transcription: String,
        with prompt: PostProcessingPrompt,
        systemPromptOverride: String?
    ) async throws -> String {
        try await processTranscription(
            transcription,
            with: prompt,
            mode: .meeting,
            systemPromptOverride: systemPromptOverride
        )
    }

    public func processTranscription(
        _ transcription: String,
        with prompt: PostProcessingPrompt,
        mode: IntelligenceKernelMode,
        systemPromptOverride: String?
    ) async throws -> String {
        _ = try validateInput(transcription)
        guard settings.isEnhancementsInferenceReady(for: mode) else {
            throw unavailableConfigurationError(
                mode: mode,
                message: "Post-processing blocked: enhancements configuration not ready"
            )
        }

        let context = makeLegacyRequestContext(
            transcription: transcription,
            prompt: prompt,
            mode: mode,
            systemPromptOverride: systemPromptOverride
        )

        isProcessing = true
        lastError = nil
        defer {
            isProcessing = false
            reportDictationPostProcessingDurationIfNeeded(mode: mode, startedAt: context.startedAt)
        }

        do {
            let result = try await sendToAI(
                transcription: context.transcription,
                prompt: context.prompt,
                mode: context.mode,
                systemPromptOverride: context.systemPromptOverride,
                requestProfile: context.requestProfile,
                traceContext: context.traceContext
            )
            logRequestSuccess(message: "Post-processing completed", context: context.traceContext, startedAt: context.startedAt)
            return result
        } catch {
            return try await handleLegacyFailure(context: context, error: error)
        }
    }

    private func makeLegacyRequestContext(
        transcription: String,
        prompt: PostProcessingPrompt,
        mode: IntelligenceKernelMode,
        systemPromptOverride: String?
    ) -> LegacyRequestContext {
        let requestProfile = profile(for: mode, prefersStructuredPipeline: false)
        let requestConfig = settings.resolvedEnhancementsAIConfiguration(for: mode)
        let traceContext = makeTraceContext(
            mode: mode,
            provider: requestConfig.provider,
            model: requestConfig.selectedModel,
            prompt: prompt,
            pipeline: requestProfile.pipeline
        )

        return LegacyRequestContext(
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

    private func handleLegacyFailure(context: LegacyRequestContext, error: Error) async throws -> String {
        let processingError = normalizePostProcessingError(error)

        guard shouldTriggerDictationTimeoutFallback(for: context.mode, error: processingError) else {
            lastError = processingError
            throw processingError
        }

        reportDictationFallbackMetrics()

        AppLogger.warning(
            "Dictation post-processing timed out; running fast fallback",
            category: .transcriptionEngine,
            extra: traceExtra(
                from: context.traceContext,
                attempt: 1,
                elapsedMilliseconds: Date().timeIntervalSince(context.startedAt) * 1_000
            )
        )

        return try await runLegacyFallback(from: context)
    }

    private func runLegacyFallback(from context: LegacyRequestContext) async throws -> String {
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
            return try await sendToAI(
                transcription: context.transcription,
                prompt: fallbackPrompt,
                mode: context.mode,
                systemPromptOverride: nil,
                requestProfile: fallbackProfile,
                traceContext: fallbackTraceContext
            )
        } catch {
            let fallbackError = normalizePostProcessingError(error)
            lastError = fallbackError
            throw fallbackError
        }
    }

    func unavailableConfigurationError(mode: IntelligenceKernelMode, message: String) -> PostProcessingError {
        let reasonCode = settings
            .enhancementsInferenceReadinessIssue(for: mode, apiKeyExists: nil)?
            .rawValue ?? "enhancements.not_ready"
        AppLogger.info(message, category: .transcriptionEngine, extra: ["reasonCode": reasonCode])
        return .noAPIConfigured
    }

    private func logRequestSuccess(message: String, context: RequestTraceContext, startedAt: Date) {
        AppLogger.info(
            message,
            category: .transcriptionEngine,
            extra: traceExtra(
                from: context,
                attempt: 1,
                elapsedMilliseconds: Date().timeIntervalSince(startedAt) * 1_000
            )
        )
    }

    func reportDictationFallbackMetrics() {
        PerformanceMonitor.shared.reportMetric(name: "dictation_timeout_count", value: 1, unit: "count")
        PerformanceMonitor.shared.reportMetric(name: "dictation_fallback_triggered", value: 1, unit: "count")
    }
}
