import Foundation
import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

// MARK: - Post-Processing Service

/// Service for post-processing transcriptions using AI.
@MainActor
public final class PostProcessingService: ObservableObject, PostProcessingServiceProtocol {
    public static let shared = PostProcessingService()

    private enum Constants {
        /// Maximum tokens for AI response (suitable for long meeting notes).
        static let maxTokens = 4_096
        /// Request timeout in seconds (AI responses can be slow for long texts).
        static let meetingRequestTimeoutSeconds: TimeInterval = 120
        /// Dictation budget for the main post-processing request.
        static let dictationRequestTimeoutSeconds: TimeInterval = 25
        /// Dictation budget for timeout fallback fast request.
        static let dictationFallbackTimeoutSeconds: TimeInterval = 8
        /// Anthropic API version header value.
        static let anthropicAPIVersion = "2023-06-01"
        /// Maximum input characters to prevent excessive API costs.
        static let maxInputCharacters = 100_000
        /// Retry count for meeting profile (3 attempts total).
        static let meetingRetryCount = 2
        /// Base delay for exponential backoff (in nanoseconds).
        static let baseRetryDelay: UInt64 = 1_000_000_000 // 1 second
    }

    private struct RequestProfile {
        let name: String
        let timeoutSeconds: TimeInterval
        let retryCount: Int
        let useStructuredPipeline: Bool
        let useRepair: Bool
        let pipeline: String
    }

    private struct RequestTraceContext {
        let mode: IntelligenceKernelMode
        let provider: AIProvider
        let model: String
        let promptId: String
        let promptTitle: String
        let pipeline: String
    }

    @Published public private(set) var isProcessing = false
    @Published public private(set) var lastError: PostProcessingError?

    private let settings = AppSettingsStore.shared

    private let summaryResponseParser = CanonicalSummaryResponseParser()
    private let summaryPromptComposer = CanonicalSummaryPromptComposer()
    private let summaryRepairComposer = CanonicalSummaryRepairComposer()
    private let summaryFallbackBuilder = DeterministicSummaryFallbackBuilder()
    private let summaryRenderer = CanonicalSummaryRenderer()

    private init() {}

    deinit {
        AppLogger.debug("PostProcessingService deinitialized", category: .transcriptionEngine)
    }
}

extension PostProcessingService {

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
            let reasonCode = settings.enhancementsInferenceReadinessIssue(for: mode, apiKeyExists: nil)?.rawValue ?? "enhancements.not_ready"
            AppLogger.info(
                "Post-processing blocked: enhancements configuration not ready",
                category: .transcriptionEngine,
                extra: ["reasonCode": reasonCode]
            )
            throw PostProcessingError.noAPIConfigured
        }

        let requestProfile = profile(for: mode, prefersStructuredPipeline: false)
        let requestConfig = settings.resolvedEnhancementsAIConfiguration(for: mode)
        let traceContext = makeTraceContext(
            mode: mode,
            provider: requestConfig.provider,
            model: requestConfig.selectedModel,
            prompt: prompt,
            pipeline: requestProfile.pipeline
        )

        isProcessing = true
        lastError = nil
        let startedAt = Date()
        defer {
            isProcessing = false
            reportDictationPostProcessingDurationIfNeeded(mode: mode, startedAt: startedAt)
        }

        do {
            let result = try await sendToAI(
                transcription: transcription,
                prompt: prompt,
                mode: mode,
                systemPromptOverride: systemPromptOverride,
                requestProfile: requestProfile,
                traceContext: traceContext
            )
            AppLogger.info(
                "Post-processing completed",
                category: .transcriptionEngine,
                extra: traceExtra(
                    from: traceContext,
                    attempt: 1,
                    elapsedMilliseconds: Date().timeIntervalSince(startedAt) * 1_000
                )
            )
            return result
        } catch {
            let processingError = normalizePostProcessingError(error)

            guard shouldTriggerDictationTimeoutFallback(for: mode, error: processingError) else {
                lastError = processingError
                throw processingError
            }

            PerformanceMonitor.shared.reportMetric(
                name: "dictation_timeout_count",
                value: 1,
                unit: "count"
            )
            PerformanceMonitor.shared.reportMetric(
                name: "dictation_fallback_triggered",
                value: 1,
                unit: "count"
            )

            let fallbackProfile = dictationFallbackProfile()
            let fallbackPrompt = PostProcessingPrompt.cleanTranscription
            let fallbackTraceContext = makeTraceContext(
                mode: mode,
                provider: requestConfig.provider,
                model: requestConfig.selectedModel,
                prompt: fallbackPrompt,
                pipeline: fallbackProfile.pipeline
            )

            AppLogger.warning(
                "Dictation post-processing timed out; running fast fallback",
                category: .transcriptionEngine,
                extra: traceExtra(from: traceContext, attempt: 1, elapsedMilliseconds: Date().timeIntervalSince(startedAt) * 1_000)
            )

            do {
                return try await sendToAI(
                    transcription: transcription,
                    prompt: fallbackPrompt,
                    mode: mode,
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
    }

    // MARK: - Public API (Structured)

    public func processTranscriptionStructured(_ transcription: String) async throws -> DomainPostProcessingResult {
        guard settings.postProcessingEnabled else {
            let fallback = summaryFallbackBuilder.build(providerOutput: "", transcription: transcription)
            AppLogger.info("Post-processing disabled, returning deterministic structured fallback", category: .transcriptionEngine)
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

    private func processTranscriptionStructured(
        _ transcription: String,
        with prompt: PostProcessingPrompt,
        mode: IntelligenceKernelMode,
        systemPromptOverride: String?
    ) async throws -> DomainPostProcessingResult {
        _ = try validateInput(transcription)
        guard settings.isEnhancementsInferenceReady(for: mode) else {
            let reasonCode = settings.enhancementsInferenceReadinessIssue(for: mode, apiKeyExists: nil)?.rawValue ?? "enhancements.not_ready"
            AppLogger.info(
                "Structured post-processing blocked: enhancements configuration not ready",
                category: .transcriptionEngine,
                extra: ["reasonCode": reasonCode]
            )
            throw PostProcessingError.noAPIConfigured
        }

        let requestProfile = profile(for: mode, prefersStructuredPipeline: true)
        let requestConfig = settings.resolvedEnhancementsAIConfiguration(for: mode)
        let traceContext = makeTraceContext(
            mode: mode,
            provider: requestConfig.provider,
            model: requestConfig.selectedModel,
            prompt: prompt,
            pipeline: requestProfile.pipeline
        )

        if !requestProfile.useStructuredPipeline {
            let fastResult = try await processTranscription(
                transcription,
                with: prompt,
                mode: mode,
                systemPromptOverride: systemPromptOverride
            )
            let fallbackSummary = summaryFallbackBuilder.build(
                providerOutput: fastResult,
                transcription: transcription
            )
            return DomainPostProcessingResult(
                processedText: fastResult,
                canonicalSummary: fallbackSummary.canonicalSummary,
                outputState: .deterministicFallback
            )
        }

        isProcessing = true
        lastError = nil
        let startedAt = Date()
        defer {
            isProcessing = false
            reportDictationPostProcessingDurationIfNeeded(mode: mode, startedAt: startedAt)
        }

        do {
            let result = try await sendToAIStructured(
                transcription: transcription,
                prompt: prompt,
                mode: mode,
                systemPromptOverride: systemPromptOverride,
                requestProfile: requestProfile,
                traceContext: traceContext
            )

            AppLogger.info(
                "Structured post-processing completed",
                category: .transcriptionEngine,
                extra: traceExtra(
                    from: traceContext,
                    attempt: 1,
                    elapsedMilliseconds: Date().timeIntervalSince(startedAt) * 1_000,
                    extra: ["output_state": result.outputState.rawValue]
                )
            )
            return result
        } catch {
            let processingError = normalizePostProcessingError(error)

            guard shouldTriggerDictationTimeoutFallback(for: mode, error: processingError) else {
                lastError = processingError
                throw processingError
            }

            PerformanceMonitor.shared.reportMetric(
                name: "dictation_timeout_count",
                value: 1,
                unit: "count"
            )
            PerformanceMonitor.shared.reportMetric(
                name: "dictation_fallback_triggered",
                value: 1,
                unit: "count"
            )

            let fallbackProfile = dictationFallbackProfile()
            let fallbackPrompt = PostProcessingPrompt.cleanTranscription
            let fallbackTraceContext = makeTraceContext(
                mode: mode,
                provider: requestConfig.provider,
                model: requestConfig.selectedModel,
                prompt: fallbackPrompt,
                pipeline: fallbackProfile.pipeline
            )

            AppLogger.warning(
                "Structured dictation timed out; running fast fallback",
                category: .transcriptionEngine,
                extra: traceExtra(from: traceContext, attempt: 1, elapsedMilliseconds: Date().timeIntervalSince(startedAt) * 1_000)
            )

            do {
                let fallbackText = try await sendToAI(
                    transcription: transcription,
                    prompt: fallbackPrompt,
                    mode: mode,
                    systemPromptOverride: nil,
                    requestProfile: fallbackProfile,
                    traceContext: fallbackTraceContext
                )
                let fallbackSummary = summaryFallbackBuilder.build(
                    providerOutput: fallbackText,
                    transcription: transcription
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

    // MARK: - Shared Validation

    private func validateInput(_ transcription: String) throws -> String {
        let trimmedTranscription = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTranscription.isEmpty else {
            throw PostProcessingError.emptyTranscription
        }

        guard trimmedTranscription.count <= Constants.maxInputCharacters else {
            throw PostProcessingError.transcriptionTooLong(trimmedTranscription.count)
        }

        return trimmedTranscription
    }

    private func profile(
        for mode: IntelligenceKernelMode,
        prefersStructuredPipeline: Bool
    ) -> RequestProfile {
        switch mode {
        case .meeting:
            return RequestProfile(
                name: "meetingProfile",
                timeoutSeconds: Constants.meetingRequestTimeoutSeconds,
                retryCount: Constants.meetingRetryCount,
                useStructuredPipeline: prefersStructuredPipeline,
                useRepair: prefersStructuredPipeline,
                pipeline: prefersStructuredPipeline ? "structured" : "fast"
            )
        case .dictation, .assistant:
            let canUseStructured = prefersStructuredPipeline && settings.dictationStructuredPostProcessingEnabled
            return RequestProfile(
                name: "dictationProfile",
                timeoutSeconds: Constants.dictationRequestTimeoutSeconds,
                retryCount: 0,
                useStructuredPipeline: canUseStructured,
                useRepair: false,
                pipeline: canUseStructured ? "structured" : "fast"
            )
        }
    }

    private func dictationFallbackProfile() -> RequestProfile {
        RequestProfile(
            name: "dictationFallbackProfile",
            timeoutSeconds: Constants.dictationFallbackTimeoutSeconds,
            retryCount: 0,
            useStructuredPipeline: false,
            useRepair: false,
            pipeline: "fast"
        )
    }

    private func makeTraceContext(
        mode: IntelligenceKernelMode,
        provider: AIProvider,
        model: String,
        prompt: PostProcessingPrompt,
        pipeline: String
    ) -> RequestTraceContext {
        RequestTraceContext(
            mode: mode,
            provider: provider,
            model: model,
            promptId: prompt.id.uuidString,
            promptTitle: prompt.title,
            pipeline: pipeline
        )
    }

    private func traceExtra(
        from context: RequestTraceContext,
        attempt: Int,
        elapsedMilliseconds: Double?,
        extra: [String: Any] = [:]
    ) -> [String: Any] {
        var payload: [String: Any] = [
            "mode": context.mode.rawValue,
            "provider": context.provider.rawValue,
            "model": context.model,
            "promptId": context.promptId,
            "promptTitle": context.promptTitle,
            "pipeline": context.pipeline,
            "attempt": attempt,
        ]

        if let elapsedMilliseconds {
            payload["elapsed_ms"] = elapsedMilliseconds
        }

        for (key, value) in extra {
            payload[key] = value
        }

        return payload
    }

    private func normalizePostProcessingError(_ error: Error) -> PostProcessingError {
        if let error = error as? PostProcessingError {
            return error
        }
        return .requestFailed(error)
    }

    private func shouldTriggerDictationTimeoutFallback(
        for mode: IntelligenceKernelMode,
        error: PostProcessingError
    ) -> Bool {
        mode == .dictation && isTimeoutError(error)
    }

    private func isTimeoutError(_ error: Error) -> Bool {
        if case let PostProcessingError.requestFailed(underlyingError) = error {
            return isTimeoutError(underlyingError)
        }

        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorTimedOut
    }

    private func reportDictationPostProcessingDurationIfNeeded(
        mode: IntelligenceKernelMode,
        startedAt: Date
    ) {
        guard mode == .dictation else { return }
        PerformanceMonitor.shared.reportMetric(
            name: "dictation_post_processing_ms",
            value: Date().timeIntervalSince(startedAt) * 1_000,
            unit: "ms"
        )
    }

    // MARK: - Legacy Pipeline

    private func sendToAI(
        transcription: String,
        prompt: PostProcessingPrompt,
        mode: IntelligenceKernelMode,
        systemPromptOverride: String?,
        requestProfile: RequestProfile,
        traceContext: RequestTraceContext
    ) async throws -> String {
        var lastError: Error?
        let attemptCount = max(1, requestProfile.retryCount + 1)

        for attempt in 0..<attemptCount {
            do {
                return try await performAIRequest(
                    transcription: transcription,
                    prompt: prompt,
                    mode: mode,
                    systemPromptOverride: systemPromptOverride,
                    timeoutSeconds: requestProfile.timeoutSeconds,
                    traceContext: traceContext,
                    attempt: attempt + 1
                )
            } catch {
                lastError = error

                guard shouldRetry(error: error), attempt < attemptCount - 1 else {
                    throw error
                }

                let multiplier = Int(pow(2.0, Double(attempt)))
                let delay = Constants.baseRetryDelay * UInt64(multiplier)

                AppLogger.warning(
                    "AI request failed, retrying",
                    category: .transcriptionEngine,
                    extra: traceExtra(
                        from: traceContext,
                        attempt: attempt + 1,
                        elapsedMilliseconds: nil,
                        extra: ["delay_ms": delay / 1_000_000]
                    )
                )

                try await Task.sleep(nanoseconds: delay)
            }
        }

        throw lastError ?? PostProcessingError.invalidResponse
    }

    // MARK: - Structured Pipeline

    private func sendToAIStructured(
        transcription: String,
        prompt: PostProcessingPrompt,
        mode: IntelligenceKernelMode,
        systemPromptOverride: String?,
        requestProfile: RequestProfile,
        traceContext: RequestTraceContext
    ) async throws -> DomainPostProcessingResult {
        var lastError: Error?
        let structuredPrompt = makeStructuredPrompt(from: prompt)
        let attemptCount = max(1, requestProfile.retryCount + 1)

        for attempt in 0..<attemptCount {
            do {
                let rawOutput = try await performAIRequest(
                    transcription: transcription,
                    prompt: structuredPrompt,
                    mode: mode,
                    systemPromptOverride: systemPromptOverride,
                    timeoutSeconds: requestProfile.timeoutSeconds,
                    traceContext: traceContext,
                    attempt: attempt + 1
                )

                if let summary = tryParseCanonicalSummary(rawOutput) {
                    return makeStructuredResult(summary, outputState: .structured)
                }

                AppLogger.warning(
                    "Structured summary parse failed, attempting repair",
                    category: .transcriptionEngine,
                    extra: traceExtra(from: traceContext, attempt: attempt + 1, elapsedMilliseconds: nil)
                )

                if requestProfile.useRepair {
                    if let repairedOutput = try? await performRepairRequest(
                        malformedOutput: rawOutput,
                        transcription: transcription,
                        originalPrompt: prompt,
                        mode: mode,
                        systemPromptOverride: systemPromptOverride,
                        timeoutSeconds: requestProfile.timeoutSeconds,
                        traceContext: traceContext,
                        attempt: attempt + 1
                    ), let repairedSummary = tryParseCanonicalSummary(repairedOutput) {
                        return makeStructuredResult(repairedSummary, outputState: .repaired)
                    }
                }

                AppLogger.warning(
                    "Structured summary repair failed, using deterministic fallback",
                    category: .transcriptionEngine,
                    extra: traceExtra(from: traceContext, attempt: attempt + 1, elapsedMilliseconds: nil)
                )
                return summaryFallbackBuilder.build(providerOutput: rawOutput, transcription: transcription)
            } catch {
                lastError = error

                guard shouldRetry(error: error), attempt < attemptCount - 1 else {
                    throw error
                }

                let multiplier = Int(pow(2.0, Double(attempt)))
                let delay = Constants.baseRetryDelay * UInt64(multiplier)

                AppLogger.warning(
                    "Structured AI request failed, retrying",
                    category: .transcriptionEngine,
                    extra: traceExtra(
                        from: traceContext,
                        attempt: attempt + 1,
                        elapsedMilliseconds: nil,
                        extra: ["delay_ms": delay / 1_000_000]
                    )
                )

                try await Task.sleep(nanoseconds: delay)
            }
        }

        throw lastError ?? PostProcessingError.invalidResponse
    }

    private func makeStructuredPrompt(from prompt: PostProcessingPrompt) -> PostProcessingPrompt {
        var structuredPrompt = prompt
        structuredPrompt.promptText = summaryPromptComposer.structuredPrompt(from: prompt.promptText)
        return structuredPrompt
    }

    private func tryParseCanonicalSummary(_ output: String) -> CanonicalSummary? {
        try? summaryResponseParser.parse(from: output)
    }

    private func makeStructuredResult(
        _ summary: CanonicalSummary,
        outputState: DomainPostProcessingOutputState
    ) -> DomainPostProcessingResult {
        DomainPostProcessingResult(
            processedText: summaryRenderer.render(summary),
            canonicalSummary: summary,
            outputState: outputState
        )
    }

    private func performRepairRequest(
        malformedOutput: String,
        transcription: String,
        originalPrompt: PostProcessingPrompt,
        mode: IntelligenceKernelMode,
        systemPromptOverride: String?,
        timeoutSeconds: TimeInterval,
        traceContext: RequestTraceContext,
        attempt: Int
    ) async throws -> String {
        let baseSystemPrompt = systemPromptOverride ?? settings.systemPrompt
        let systemPrompt = summaryRepairComposer.systemPrompt(basePrompt: baseSystemPrompt)
        let userPrompt = summaryRepairComposer.userMessage(
            malformedOutput: malformedOutput,
            transcription: transcription,
            originalPrompt: originalPrompt.promptText
        )

        return try await performCustomAIRequest(
            mode: mode,
            systemPrompt: systemPrompt,
            userContent: userPrompt,
            timeoutSeconds: timeoutSeconds,
            traceContext: traceContext,
            attempt: attempt
        )
    }

    // MARK: - Request/Response

    private func performAIRequest(
        transcription: String,
        prompt: PostProcessingPrompt,
        mode: IntelligenceKernelMode,
        systemPromptOverride: String?,
        timeoutSeconds: TimeInterval,
        traceContext: RequestTraceContext,
        attempt: Int
    ) async throws -> String {
        let requestStartedAt = Date()
        let config = settings.resolvedEnhancementsAIConfiguration(for: mode)
        let apiKey = try getAPIKey(for: config.provider)
        let url = try buildURL(for: config, apiKey: apiKey)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeoutSeconds

        configureAuthHeaders(for: &request, provider: config.provider, apiKey: apiKey)
        try setRequestBody(
            for: &request,
            config: config,
            transcription: transcription,
            prompt: prompt,
            systemPromptOverride: systemPromptOverride
        )

        AppLogger.debug(
            "Sending post-processing request",
            category: .transcriptionEngine,
            extra: traceExtra(
                from: traceContext,
                attempt: attempt,
                elapsedMilliseconds: nil,
                extra: ["url": sanitizedURLForLogging(url)]
            )
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, data: data)

        let output = try parseSuccessResponse(data: data, provider: config.provider)
        AppLogger.debug(
            "Post-processing provider request succeeded",
            category: .transcriptionEngine,
            extra: traceExtra(
                from: traceContext,
                attempt: attempt,
                elapsedMilliseconds: Date().timeIntervalSince(requestStartedAt) * 1_000
            )
        )
        return output
    }

    private func performCustomAIRequest(
        mode: IntelligenceKernelMode,
        systemPrompt: String,
        userContent: String,
        timeoutSeconds: TimeInterval,
        traceContext: RequestTraceContext,
        attempt: Int
    ) async throws -> String {
        let requestStartedAt = Date()
        let config = settings.resolvedEnhancementsAIConfiguration(for: mode)
        let apiKey = try getAPIKey(for: config.provider)
        let url = try buildURL(for: config, apiKey: apiKey)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeoutSeconds

        configureAuthHeaders(for: &request, provider: config.provider, apiKey: apiKey)
        try setCustomRequestBody(
            for: &request,
            config: config,
            systemMessage: systemPrompt,
            userContent: userContent
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, data: data)
        let output = try parseSuccessResponse(data: data, provider: config.provider)
        AppLogger.debug(
            "Custom post-processing provider request succeeded",
            category: .transcriptionEngine,
            extra: traceExtra(
                from: traceContext,
                attempt: attempt,
                elapsedMilliseconds: Date().timeIntervalSince(requestStartedAt) * 1_000
            )
        )
        return output
    }

    private func shouldRetry(error: Error) -> Bool {
        // Retry on timeouts and connection issues
        if (error as NSError).domain == NSURLErrorDomain {
            let code = (error as NSError).code
            if code == NSURLErrorTimedOut ||
                code == NSURLErrorNetworkConnectionLost ||
                code == NSURLErrorCannotConnectToHost
            {
                return true
            }
        }

        // Retry on rate limit (429) and server errors (5xx)
        if case let PostProcessingError.apiError(message) = error {
            if message.contains("429") || message.contains("HTTP 5") {
                return true
            }
        }

        // Retry on request failed (internal wrapper) if the underlying error is a timeout
        if case let PostProcessingError.requestFailed(underlyingError) = error {
            return shouldRetry(error: underlyingError)
        }

        return false
    }

    private func getAPIKey(for provider: AIProvider) throws -> String {
        guard let apiKey = try? KeychainManager.retrieveAPIKey(for: provider),
              !apiKey.isEmpty
        else {
            throw PostProcessingError.noAPIConfigured
        }
        return apiKey
    }

    private func buildURL(for config: AIConfiguration, apiKey: String) throws -> URL {
        let endpoint = try buildEndpoint(for: config.provider, baseURL: config.baseURL, model: config.selectedModel)
        guard var components = URLComponents(string: endpoint) else {
            throw PostProcessingError.invalidURL
        }
        if config.provider == .google {
            components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        }
        guard let url = components.url else {
            throw PostProcessingError.invalidURL
        }
        return url
    }

    private func configureAuthHeaders(
        for request: inout URLRequest,
        provider: AIProvider,
        apiKey: String
    ) {
        switch provider {
        case .anthropic:
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue(Constants.anthropicAPIVersion, forHTTPHeaderField: "anthropic-version")
        case .google:
            break
        case .openai, .groq, .custom:
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
    }

    private func setRequestBody(
        for request: inout URLRequest,
        config: AIConfiguration,
        transcription: String,
        prompt: PostProcessingPrompt,
        systemPromptOverride: String?
    ) throws {
        let extracted = AIPromptTemplates.extractSiteOrAppPriorityInstructions(from: prompt.promptText)
        let baseSystemMessage = systemPromptOverride ?? settings.systemPrompt
        let systemMessage = AIPromptTemplates.systemPrompt(
            basePrompt: baseSystemMessage,
            priorityInstructions: extracted.priorityInstructions
        )
        let userContent = AIPromptTemplates.userMessage(
            transcription: transcription,
            prompt: extracted.cleanPrompt,
            priorityInstructions: extracted.priorityInstructions
        )

        try setCustomRequestBody(
            for: &request,
            config: config,
            systemMessage: systemMessage,
            userContent: userContent
        )
    }

    private func setCustomRequestBody(
        for request: inout URLRequest,
        config: AIConfiguration,
        systemMessage: String,
        userContent: String
    ) throws {
        let encoder = JSONEncoder()

        do {
            switch config.provider {
            case .anthropic:
                let payload = AnthropicMessageRequest(
                    model: config.selectedModel,
                    maxTokens: Constants.maxTokens,
                    system: systemMessage,
                    messages: [AIChatMessage(role: "user", content: userContent)]
                )
                request.httpBody = try encoder.encode(payload)

            case .google:
                let payload = GeminiGenerateContentRequest(
                    systemInstruction: GeminiSystemInstruction(parts: [GeminiPart(text: systemMessage)]),
                    contents: [GeminiContent(role: "user", parts: [GeminiPart(text: userContent)])],
                    generationConfig: GeminiGenerationConfig(maxOutputTokens: Constants.maxTokens)
                )
                request.httpBody = try encoder.encode(payload)

            case .openai, .groq, .custom:
                let messages = [
                    AIChatMessage(role: "system", content: systemMessage),
                    AIChatMessage(role: "user", content: userContent),
                ]
                let payload = OpenAIChatRequest(
                    model: config.selectedModel,
                    messages: messages,
                    maxTokens: Constants.maxTokens
                )
                request.httpBody = try encoder.encode(payload)
            }
        } catch {
            AppLogger.error("Failed to encode request body", category: .transcriptionEngine, error: error)
            throw PostProcessingError.requestFailed(error)
        }
    }

    private func validateHTTPResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PostProcessingError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let decoder = JSONDecoder()
            if let errorResponse = try? decoder.decode(OpenAIErrorResponse.self, from: data) {
                throw PostProcessingError.apiError(errorResponse.error.message)
            }
            if let errorResponse = try? decoder.decode(AnthropicErrorResponse.self, from: data) {
                throw PostProcessingError.apiError(errorResponse.error.message)
            }
            if let errorResponse = try? decoder.decode(GeminiErrorResponse.self, from: data) {
                throw PostProcessingError.apiError(errorResponse.error.message)
            }

            // Fallback to raw string if possible
            let rawResponse = String(data: data, encoding: .utf8) ?? ""
            throw PostProcessingError.apiError("HTTP \(httpResponse.statusCode): \(rawResponse)")
        }
    }

    private func parseSuccessResponse(data: Data, provider: AIProvider) throws -> String {
        let decoder = JSONDecoder()

        do {
            switch provider {
            case .anthropic:
                let response = try decoder.decode(AnthropicMessageResponse.self, from: data)
                guard let text = response.content.first?.text else {
                    throw PostProcessingError.invalidResponse
                }
                return text

            case .google:
                let response = try decoder.decode(GeminiGenerateContentResponse.self, from: data)
                guard let text = response.candidates?.first?.content?.parts.first?.text else {
                    throw PostProcessingError.invalidResponse
                }
                return text

            case .openai, .groq, .custom:
                let response = try decoder.decode(OpenAIChatResponse.self, from: data)
                guard let content = response.choices.first?.message.content else {
                    throw PostProcessingError.invalidResponse
                }
                return content
            }
        } catch {
            AppLogger.error("Failed to decode response", category: .transcriptionEngine, error: error)
            throw PostProcessingError.invalidResponse
        }
    }

    private func buildEndpoint(for provider: AIProvider, baseURL: String, model: String) throws -> String {
        // Remove potential trailing slash to avoid double slash
        let base = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL

        switch provider {
        case .openai, .groq, .custom:
            return "\(base)/chat/completions"
        case .anthropic:
            return "\(base)/messages"
        case .google:
            let rawModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rawModel.isEmpty else {
                throw PostProcessingError.noAPIConfigured
            }
            let normalizedModel = rawModel.hasPrefix("models/") ? rawModel : "models/\(rawModel)"
            return "\(base)/\(normalizedModel):generateContent"
        }
    }

    private func sanitizedURLForLogging(_ url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url.absoluteString
        }

        if let queryItems = components.queryItems, !queryItems.isEmpty {
            components.queryItems = queryItems.map { item in
                URLQueryItem(name: item.name, value: "REDACTED")
            }
        }

        return components.url?.absoluteString ?? url.absoluteString
    }

}
