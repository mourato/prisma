import Foundation
import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

@MainActor
public final class MeetingQAService: ObservableObject, MeetingQAServiceProtocol {
    public static let shared = MeetingQAService()

    public typealias APIKeyProvider = (AIProvider) throws -> String
    public typealias SleepFunction = @Sendable (UInt64) async throws -> Void

    private enum Constants {
        static let requestTimeoutSeconds: TimeInterval = 45
        static let maxTokens = 1_200
        static let maxRetryAttempts = 2
        static let retryDelayNanoseconds: UInt64 = 800_000_000
        static let anthropicAPIVersion = "2023-06-01"
        static let maxSegmentsInPrompt = 40
    }

    @Published public private(set) var isAnswering = false
    @Published public private(set) var lastError: MeetingQAError?

    private let settings: AppSettingsStore
    private let session: URLSession
    private let apiKeyProvider: APIKeyProvider
    private let sleepFunction: SleepFunction

    public init(
        settings: AppSettingsStore = .shared,
        session: URLSession = .shared,
        apiKeyProvider: @escaping APIKeyProvider = { provider in
            guard let key = try KeychainManager.retrieveAPIKey(for: provider),
                  !key.isEmpty
            else {
                throw MeetingQAError.noAPIConfigured
            }
            return key
        },
        sleepFunction: @escaping SleepFunction = { nanoseconds in
            try await Task.sleep(nanoseconds: nanoseconds)
        }
    ) {
        self.settings = settings
        self.session = session
        self.apiKeyProvider = apiKeyProvider
        self.sleepFunction = sleepFunction
    }

    public func ask(question: String, transcription: Transcription) async throws -> MeetingQAResponse {
        guard settings.isIntelligenceKernelModeEnabled(.meeting) else {
            throw MeetingQAError.disabled
        }

        let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuestion.isEmpty else {
            throw MeetingQAError.emptyQuestion
        }

        guard settings.meetingQnAEnabled else {
            throw MeetingQAError.disabled
        }

        guard !settings.aiConfiguration.baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MeetingQAError.noAPIConfigured
        }

        isAnswering = true
        lastError = nil
        defer { isAnswering = false }

        do {
            return try await askWithRetry(question: trimmedQuestion, transcription: transcription)
        } catch let error as MeetingQAError {
            lastError = error
            throw error
        } catch let urlError as URLError {
            let mappedError: MeetingQAError
            switch urlError.code {
            case .timedOut:
                mappedError = .timeout
            case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost:
                mappedError = .networkUnavailable
            default:
                mappedError = .requestFailed(urlError.localizedDescription)
            }
            lastError = mappedError
            throw mappedError
        } catch {
            let wrapped = MeetingQAError.requestFailed(error.localizedDescription)
            lastError = wrapped
            throw wrapped
        }
    }

    public func ask(_ request: IntelligenceKernelQuestionRequest) async throws -> MeetingQAResponse {
        guard settings.isIntelligenceKernelModeEnabled(request.mode) else {
            throw MeetingQAError.disabled
        }

        switch request.mode {
        case .meeting:
            return try await ask(question: request.question, transcription: request.transcription)
        case .dictation, .assistant:
            throw MeetingQAError.disabled
        }
    }

    private func askWithRetry(question: String, transcription: Transcription) async throws -> MeetingQAResponse {
        var lastThrownError: Error?

        for attempt in 0..<Constants.maxRetryAttempts {
            do {
                let rawOutput = try await performRequest(question: question, transcription: transcription)
                return try parseModelOutput(rawOutput)
            } catch {
                lastThrownError = error

                let shouldRetry = isRetryable(error)
                let isLastAttempt = attempt == Constants.maxRetryAttempts - 1
                guard shouldRetry, !isLastAttempt else {
                    throw error
                }

                AppLogger.warning(
                    "Meeting Q&A request failed, retrying",
                    category: .transcriptionEngine,
                    extra: ["attempt": attempt + 1]
                )
                try await sleepFunction(Constants.retryDelayNanoseconds)
            }
        }

        throw lastThrownError ?? MeetingQAError.invalidResponse
    }

    private func performRequest(question: String, transcription: Transcription) async throws -> String {
        let config = settings.aiConfiguration
        let apiKey = try getAPIKey(for: config.provider)
        let url = try buildURL(for: config)
        let (systemPrompt, userPrompt) = buildPrompts(question: question, transcription: transcription)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = Constants.requestTimeoutSeconds
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        switch config.provider {
        case .anthropic:
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue(Constants.anthropicAPIVersion, forHTTPHeaderField: "anthropic-version")
            let payload = AnthropicMessageRequest(
                model: config.selectedModel,
                maxTokens: Constants.maxTokens,
                system: systemPrompt,
                messages: [AIChatMessage(role: "user", content: userPrompt)]
            )
            request.httpBody = try JSONEncoder().encode(payload)

        case .openai, .groq, .custom:
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            let payload = OpenAIChatRequest(
                model: config.selectedModel,
                messages: [
                    AIChatMessage(role: "system", content: systemPrompt),
                    AIChatMessage(role: "user", content: userPrompt),
                ],
                maxTokens: Constants.maxTokens
            )
            request.httpBody = try JSONEncoder().encode(payload)
        }

        let (data, response) = try await session.data(for: request)
        try validateHTTP(response: response, data: data)
        return try parseProviderResponse(data: data, provider: config.provider)
    }

    private func buildPrompts(question: String, transcription: Transcription) -> (String, String) {
        let summaryText = transcription.canonicalSummary?.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let summaryBlock = (summaryText?.isEmpty == false) ? summaryText! : "(none)"

        let evidenceSegments = Array(transcription.segments.prefix(Constants.maxSegmentsInPrompt))
        let transcriptBlock: String

        if evidenceSegments.isEmpty {
            transcriptBlock = transcription.rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            transcriptBlock = evidenceSegments.map { segment in
                let speaker = segment.speaker.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? Transcription.unknownSpeaker
                    : segment.speaker
                return "[\(segment.startTime)-\(segment.endTime)] \(speaker): \(segment.text)"
            }.joined(separator: "\n")
        }

        let systemPrompt = """
        You are a grounded meeting Q&A assistant.
        Rules:
        - Answer only using information from provided transcript segments and canonical summary.
        - Never fabricate facts.
        - If evidence is insufficient, return status not_found.
        - If status is answered, include at least one evidence item with speaker/startTime/endTime/excerpt.
        - Return ONLY valid JSON matching this schema:
        {
          "status": "answered" | "not_found",
          "answer": "string",
          "evidence": [
            {
              "speaker": "string",
              "startTime": 0.0,
              "endTime": 1.0,
              "excerpt": "string"
            }
          ]
        }
        """

        let userPrompt = """
        QUESTION:
        \(question)

        CANONICAL_SUMMARY:
        \(summaryBlock)

        TRANSCRIPT_SEGMENTS:
        \(transcriptBlock)
        """

        return (systemPrompt, userPrompt)
    }

    private func parseModelOutput(_ rawOutput: String) throws -> MeetingQAResponse {
        guard let jsonCandidate = extractJSONCandidate(from: rawOutput),
              let data = jsonCandidate.data(using: .utf8)
        else {
            throw MeetingQAError.invalidResponse
        }

        let decoder = JSONDecoder()
        guard let decoded = try? decoder.decode(MeetingQAResponse.self, from: data) else {
            throw MeetingQAError.invalidResponse
        }

        if decoded.status == .answered {
            let hasAnswer = !decoded.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            guard hasAnswer, !decoded.evidence.isEmpty else {
                return .notFound
            }
            return decoded
        }

        return .notFound
    }

    private func extractJSONCandidate(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{") && trimmed.hasSuffix("}") {
            return trimmed
        }

        guard let firstBrace = trimmed.firstIndex(of: "{"),
              let lastBrace = trimmed.lastIndex(of: "}")
        else {
            return nil
        }

        return String(trimmed[firstBrace ... lastBrace])
    }

    private func parseProviderResponse(data: Data, provider: AIProvider) throws -> String {
        let decoder = JSONDecoder()

        switch provider {
        case .anthropic:
            let response = try decoder.decode(AnthropicMessageResponse.self, from: data)
            guard let text = response.content.first?.text else {
                throw MeetingQAError.invalidResponse
            }
            return text

        case .openai, .groq, .custom:
            let response = try decoder.decode(OpenAIChatResponse.self, from: data)
            guard let content = response.choices.first?.message.content else {
                throw MeetingQAError.invalidResponse
            }
            return content
        }
    }

    private func validateHTTP(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MeetingQAError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let decoder = JSONDecoder()
            if let openAIError = try? decoder.decode(OpenAIErrorResponse.self, from: data) {
                throw MeetingQAError.requestFailed(openAIError.error.message)
            }

            if let anthropicError = try? decoder.decode(AnthropicErrorResponse.self, from: data) {
                throw MeetingQAError.requestFailed(anthropicError.error.message)
            }

            let raw = String(data: data, encoding: .utf8) ?? ""
            throw MeetingQAError.requestFailed("HTTP \(httpResponse.statusCode): \(raw)")
        }
    }

    private func getAPIKey(for provider: AIProvider) throws -> String {
        let key = try apiKeyProvider(provider)
        guard !key.isEmpty else {
            throw MeetingQAError.noAPIConfigured
        }
        return key
    }

    private func buildURL(for config: AIConfiguration) throws -> URL {
        let base = config.baseURL.hasSuffix("/") ? String(config.baseURL.dropLast()) : config.baseURL
        let endpoint: String

        switch config.provider {
        case .anthropic:
            endpoint = "\(base)/messages"
        case .openai, .groq, .custom:
            endpoint = "\(base)/chat/completions"
        }

        guard let url = URL(string: endpoint) else {
            throw MeetingQAError.invalidURL
        }

        return url
    }

    private func isRetryable(_ error: Error) -> Bool {
        if let qaError = error as? MeetingQAError {
            switch qaError {
            case .timeout, .networkUnavailable:
                return true
            case .requestFailed(let message):
                return message.contains("429") || message.contains("HTTP 5")
            default:
                return false
            }
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorTimedOut, NSURLErrorNetworkConnectionLost, NSURLErrorCannotConnectToHost:
                return true
            default:
                return false
            }
        }

        return false
    }
}
