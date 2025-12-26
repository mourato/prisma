import Foundation
import os.log

// MARK: - Post-Processing Error

/// Errors that can occur during post-processing.
public enum PostProcessingError: LocalizedError {
    case noPromptSelected
    case noAPIConfigured
    case invalidURL
    case requestFailed(Error)
    case invalidResponse
    case apiError(String)
    case emptyTranscription
    case transcriptionTooLong(Int)

    public var errorDescription: String? {
        switch self {
        case .noPromptSelected:
            "Nenhum prompt de pós-processamento selecionado"
        case .noAPIConfigured:
            "API de IA não configurada"
        case .invalidURL:
            "URL da API inválida"
        case let .requestFailed(error):
            "Falha na requisição: \(error.localizedDescription)"
        case .invalidResponse:
            "Resposta inválida da API"
        case let .apiError(message):
            "Erro da API: \(message)"
        case .emptyTranscription:
            "A transcrição está vazia"
        case let .transcriptionTooLong(count):
            "Transcrição muito longa (\(count) caracteres). Máximo permitido: 100.000"
        }
    }
}

// MARK: - Post-Processing Service

/// Service for post-processing transcriptions using AI.
@MainActor
public class PostProcessingService: ObservableObject, PostProcessingServiceProtocol {
    public static let shared = PostProcessingService()

    // ...

    private enum Constants {
        /// Maximum tokens for AI response (suitable for long meeting notes).
        static let maxTokens = 4096
        /// Request timeout in seconds (AI responses can be slow for long texts).
        static let requestTimeoutSeconds: TimeInterval = 120
        /// Anthropic API version header value.
        static let anthropicAPIVersion = "2023-06-01"
        /// Maximum input characters to prevent excessive API costs.
        static let maxInputCharacters = 100_000
    }

    @Published public private(set) var isProcessing = false
    @Published public private(set) var lastError: PostProcessingError?

    private let settings = AppSettingsStore.shared
    private let logger = Logger(subsystem: "MeetingAssistant", category: "PostProcessing")

    private init() {}

    // MARK: - Public API

    /// Processes a transcription using the currently selected prompt.
    /// - Parameter transcription: The raw transcription text.
    /// - Returns: The processed text from the AI.
    public func processTranscription(_ transcription: String) async throws -> String {
        guard self.settings.postProcessingEnabled else {
            self.logger.info("Post-processing is disabled, returning original transcription")
            return transcription
        }

        guard let prompt = settings.selectedPrompt else {
            throw PostProcessingError.noPromptSelected
        }

        return try await self.processTranscription(transcription, with: prompt)
    }

    /// Processes a transcription using a specific prompt.
    /// - Parameters:
    ///   - transcription: The raw transcription text.
    ///   - prompt: The prompt to use for processing.
    /// - Returns: The processed text from the AI.
    public func processTranscription(_ transcription: String, with prompt: PostProcessingPrompt) async throws -> String {
        // Input validation
        let trimmedTranscription = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTranscription.isEmpty else {
            throw PostProcessingError.emptyTranscription
        }

        guard trimmedTranscription.count <= Constants.maxInputCharacters else {
            throw PostProcessingError.transcriptionTooLong(trimmedTranscription.count)
        }

        guard self.settings.aiConfiguration.isValid else {
            throw PostProcessingError.noAPIConfigured
        }

        self.isProcessing = true
        self.lastError = nil

        defer { isProcessing = false }

        do {
            let result = try await sendToAI(transcription: transcription, prompt: prompt)
            self.logger.info("Post-processing completed successfully")
            return result
        } catch let error as PostProcessingError {
            lastError = error
            throw error
        } catch {
            let processingError = PostProcessingError.requestFailed(error)
            self.lastError = processingError
            throw processingError
        }
    }

    // MARK: - Private Methods

    // MARK: - Private Methods

    private func sendToAI(transcription: String, prompt: PostProcessingPrompt) async throws -> String {
        let config = self.settings.aiConfiguration

        guard let apiKey = try? KeychainManager.retrieve(for: .aiAPIKey), !apiKey.isEmpty else {
            throw PostProcessingError.noAPIConfigured
        }

        let endpoint = self.buildEndpoint(for: config.provider, baseURL: config.baseURL)

        guard let url = URL(string: endpoint) else {
            throw PostProcessingError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Authorization Headers
        switch config.provider {
        case .anthropic:
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue(Constants.anthropicAPIVersion, forHTTPHeaderField: "anthropic-version")
        case .openai, .groq, .custom:
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        // Request Body Creation using Codable
        let systemMessage = self.settings.systemPrompt
        let userContent = AIPromptTemplates.userMessage(transcription: transcription, prompt: prompt.promptText)
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
            self.logger.error("Failed to encode request body: \(error.localizedDescription)")
            throw PostProcessingError.requestFailed(error)
        }

        request.timeoutInterval = Constants.requestTimeoutSeconds

        self.logger.debug("Sending post-processing request to \(endpoint)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PostProcessingError.invalidResponse
        }

        // Error Handling
        guard (200...299).contains(httpResponse.statusCode) else {
            let decoder = JSONDecoder()
            if let errorResponse = try? decoder.decode(OpenAIErrorResponse.self, from: data) {
                throw PostProcessingError.apiError(errorResponse.error.message)
            }
            if let errorResponse = try? decoder.decode(AnthropicErrorResponse.self, from: data) {
                throw PostProcessingError.apiError(errorResponse.error.message)
            }

            // Fallback to raw string if possible
            let rawResponse = String(data: data, encoding: .utf8) ?? ""
            throw PostProcessingError.apiError("HTTP \(httpResponse.statusCode): \(rawResponse)")
        }

        // Success Parsing
        return try self.parseSuccessResponse(data: data, provider: config.provider)
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

            case .openai, .groq, .custom:
                let response = try decoder.decode(OpenAIChatResponse.self, from: data)
                guard let content = response.choices.first?.message.content else {
                    throw PostProcessingError.invalidResponse
                }
                return content
            }
        } catch {
            self.logger.error("Failed to decode response: \(error.localizedDescription)")
            throw PostProcessingError.invalidResponse
        }
    }

    private func buildEndpoint(for provider: AIProvider, baseURL: String) -> String {
        // Remove potential trailing slash to avoid double slash
        let base = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL

        switch provider {
        case .openai, .groq, .custom:
            return "\(base)/chat/completions"
        case .anthropic:
            return "\(base)/messages"
        }
    }
}
