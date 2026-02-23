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
        static let requestTimeoutSeconds: TimeInterval = 120
        /// Anthropic API version header value.
        static let anthropicAPIVersion = "2023-06-01"
        /// Maximum input characters to prevent excessive API costs.
        static let maxInputCharacters = 100_000
        /// Maximum retry attempts for recoverable errors.
        static let maxRetryAttempts = 3
        /// Base delay for exponential backoff (in nanoseconds).
        static let baseRetryDelay: UInt64 = 1_000_000_000 // 1 second
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

        isProcessing = true
        lastError = nil
        defer { isProcessing = false }

        do {
            let result = try await sendToAI(
                transcription: transcription,
                prompt: prompt,
                mode: mode,
                systemPromptOverride: systemPromptOverride
            )
            AppLogger.info("Post-processing completed", category: .transcriptionEngine)
            return result
        } catch let error as PostProcessingError {
            lastError = error
            throw error
        } catch {
            let processingError = PostProcessingError.requestFailed(error)
            lastError = processingError
            throw processingError
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

        isProcessing = true
        lastError = nil
        defer { isProcessing = false }

        do {
            let result = try await sendToAIStructured(
                transcription: transcription,
                prompt: prompt,
                mode: mode,
                systemPromptOverride: systemPromptOverride
            )

            AppLogger.info(
                "Structured post-processing completed",
                category: .transcriptionEngine,
                extra: ["output_state": result.outputState.rawValue]
            )
            return result
        } catch let error as PostProcessingError {
            lastError = error
            throw error
        } catch {
            let processingError = PostProcessingError.requestFailed(error)
            lastError = processingError
            throw processingError
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

    // MARK: - Legacy Pipeline

    private func sendToAI(
        transcription: String,
        prompt: PostProcessingPrompt,
        mode: IntelligenceKernelMode,
        systemPromptOverride: String?
    ) async throws -> String {
        var lastError: Error?

        for attempt in 0..<Constants.maxRetryAttempts {
            do {
                return try await performAIRequest(
                    transcription: transcription,
                    prompt: prompt,
                    mode: mode,
                    systemPromptOverride: systemPromptOverride
                )
            } catch {
                lastError = error

                guard shouldRetry(error: error), attempt < Constants.maxRetryAttempts - 1 else {
                    throw error
                }

                let multiplier = Int(pow(2.0, Double(attempt)))
                let delay = Constants.baseRetryDelay * UInt64(multiplier)

                AppLogger.warning(
                    "AI request failed, retrying",
                    category: .transcriptionEngine,
                    extra: ["attempt": attempt + 1, "delay_ms": delay / 1_000_000]
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
        systemPromptOverride: String?
    ) async throws -> DomainPostProcessingResult {
        var lastError: Error?
        let structuredPrompt = makeStructuredPrompt(from: prompt)

        for attempt in 0..<Constants.maxRetryAttempts {
            do {
                let rawOutput = try await performAIRequest(
                    transcription: transcription,
                    prompt: structuredPrompt,
                    mode: mode,
                    systemPromptOverride: systemPromptOverride
                )

                if let summary = tryParseCanonicalSummary(rawOutput) {
                    return makeStructuredResult(summary, outputState: .structured)
                }

                AppLogger.warning(
                    "Structured summary parse failed, attempting repair",
                    category: .transcriptionEngine
                )

                if let repairedOutput = try? await performRepairRequest(
                    malformedOutput: rawOutput,
                    transcription: transcription,
                    originalPrompt: prompt,
                    mode: mode,
                    systemPromptOverride: systemPromptOverride
                ), let repairedSummary = tryParseCanonicalSummary(repairedOutput) {
                    return makeStructuredResult(repairedSummary, outputState: .repaired)
                }

                AppLogger.warning(
                    "Structured summary repair failed, using deterministic fallback",
                    category: .transcriptionEngine
                )
                return summaryFallbackBuilder.build(providerOutput: rawOutput, transcription: transcription)
            } catch {
                lastError = error

                guard shouldRetry(error: error), attempt < Constants.maxRetryAttempts - 1 else {
                    throw error
                }

                let multiplier = Int(pow(2.0, Double(attempt)))
                let delay = Constants.baseRetryDelay * UInt64(multiplier)

                AppLogger.warning(
                    "Structured AI request failed, retrying",
                    category: .transcriptionEngine,
                    extra: ["attempt": attempt + 1, "delay_ms": delay / 1_000_000]
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
        systemPromptOverride: String?
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
            userContent: userPrompt
        )
    }

    // MARK: - Request/Response

    private func performAIRequest(
        transcription: String,
        prompt: PostProcessingPrompt,
        mode: IntelligenceKernelMode,
        systemPromptOverride: String?
    ) async throws -> String {
        let config = settings.resolvedEnhancementsAIConfiguration(for: mode)
        let apiKey = try getAPIKey(for: config.provider)
        let url = try buildURL(for: config, apiKey: apiKey)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = Constants.requestTimeoutSeconds

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
            extra: ["url": sanitizedURLForLogging(url)]
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, data: data)

        return try parseSuccessResponse(data: data, provider: config.provider)
    }

    private func performCustomAIRequest(
        mode: IntelligenceKernelMode,
        systemPrompt: String,
        userContent: String
    ) async throws -> String {
        let config = settings.resolvedEnhancementsAIConfiguration(for: mode)
        let apiKey = try getAPIKey(for: config.provider)
        let url = try buildURL(for: config, apiKey: apiKey)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = Constants.requestTimeoutSeconds

        configureAuthHeaders(for: &request, provider: config.provider, apiKey: apiKey)
        try setCustomRequestBody(
            for: &request,
            config: config,
            systemMessage: systemPrompt,
            userContent: userContent
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, data: data)
        return try parseSuccessResponse(data: data, provider: config.provider)
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

    deinit {
        AppLogger.debug("PostProcessingService deinitialized", category: .transcriptionEngine)
    }
}
