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
            return "Nenhum prompt de pós-processamento selecionado"
        case .noAPIConfigured:
            return "API de IA não configurada"
        case .invalidURL:
            return "URL da API inválida"
        case .requestFailed(let error):
            return "Falha na requisição: \(error.localizedDescription)"
        case .invalidResponse:
            return "Resposta inválida da API"
        case .apiError(let message):
            return "Erro da API: \(message)"
        case .emptyTranscription:
            return "A transcrição está vazia"
        case .transcriptionTooLong(let count):
            return "Transcrição muito longa (\(count) caracteres). Máximo permitido: 100.000"
        }
    }
}

// MARK: - Post-Processing Service

/// Service for post-processing transcriptions using AI.
@MainActor
public class PostProcessingService: ObservableObject {
    public static let shared = PostProcessingService()
    
    // MARK: - Constants
    
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
        guard settings.postProcessingEnabled else {
            logger.info("Post-processing is disabled, returning original transcription")
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
    public func processTranscription(_ transcription: String, with prompt: PostProcessingPrompt) async throws -> String {
        // Input validation
        let trimmedTranscription = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTranscription.isEmpty else {
            throw PostProcessingError.emptyTranscription
        }
        
        guard trimmedTranscription.count <= Constants.maxInputCharacters else {
            throw PostProcessingError.transcriptionTooLong(trimmedTranscription.count)
        }
        
        guard settings.aiConfiguration.isValid else {
            throw PostProcessingError.noAPIConfigured
        }
        
        isProcessing = true
        lastError = nil
        
        defer { isProcessing = false }
        
        do {
            let result = try await sendToAI(transcription: transcription, prompt: prompt)
            logger.info("Post-processing completed successfully")
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
    
    // MARK: - Private Methods
    
    private func sendToAI(transcription: String, prompt: PostProcessingPrompt) async throws -> String {
        let config = settings.aiConfiguration
        
        guard let apiKey = try? KeychainManager.retrieve(for: .aiAPIKey), !apiKey.isEmpty else {
            throw PostProcessingError.noAPIConfigured
        }
        
        let endpoint = buildEndpoint(for: config.provider, baseURL: config.baseURL)
        
        guard let url = URL(string: endpoint) else {
            throw PostProcessingError.invalidURL
        }
        
        let systemMessage = settings.systemPrompt
        let userMessage = AIPromptTemplates.userMessage(transcription: transcription, prompt: prompt.promptText)
        
        let requestBody = buildRequestBody(
            provider: config.provider,
            model: config.selectedModel,
            systemMessage: systemMessage,
            userMessage: userMessage
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // Anthropic requires a different header
        if config.provider == .anthropic {
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue(Constants.anthropicAPIVersion, forHTTPHeaderField: "anthropic-version")
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = Constants.requestTimeoutSeconds
        
        logger.debug("Sending post-processing request to \(endpoint)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PostProcessingError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorMessage = parseErrorMessage(from: data) {
                throw PostProcessingError.apiError(errorMessage)
            }
            throw PostProcessingError.apiError("HTTP \(httpResponse.statusCode)")
        }
        
        return try parseResponseContent(from: data, provider: config.provider)
    }
    
    private func buildEndpoint(for provider: AIProvider, baseURL: String) -> String {
        let base = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        switch provider {
        case .openai, .groq, .custom:
            return "\(base)/chat/completions"
        case .anthropic:
            return "\(base)/messages"
        }
    }
    
    private func buildRequestBody(
        provider: AIProvider,
        model: String,
        systemMessage: String,
        userMessage: String
    ) -> [String: Any] {
        switch provider {
        case .anthropic:
            return [
                "model": model,
                "max_tokens": Constants.maxTokens,
                "system": systemMessage,
                "messages": [
                    ["role": "user", "content": userMessage]
                ]
            ]
        case .openai, .groq, .custom:
            return [
                "model": model,
                "messages": [
                    ["role": "system", "content": systemMessage],
                    ["role": "user", "content": userMessage]
                ],
                "max_tokens": Constants.maxTokens
            ]
        }
    }
    
    private func parseResponseContent(from data: Data, provider: AIProvider) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PostProcessingError.invalidResponse
        }
        
        switch provider {
        case .anthropic:
            // Anthropic response format: { "content": [{ "text": "..." }] }
            if let content = json["content"] as? [[String: Any]],
               let firstContent = content.first,
               let text = firstContent["text"] as? String {
                return text
            }
        case .openai, .groq, .custom:
            // OpenAI response format: { "choices": [{ "message": { "content": "..." } }] }
            if let choices = json["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let message = firstChoice["message"] as? [String: Any],
               let content = message["content"] as? String {
                return content
            }
        }
        
        throw PostProcessingError.invalidResponse
    }
    
    private func parseErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        // Both OpenAI and Anthropic use the same error format
        if let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            return message
        }
        
        return nil
    }
}
