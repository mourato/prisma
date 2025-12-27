import Foundation

// MARK: - Shared Models

public struct AIChatMessage: Codable {
    public let role: String
    public let content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

// MARK: - OpenAI / Groq / Custom

public struct OpenAIChatRequest: Codable {
    public let model: String
    public let messages: [AIChatMessage]
    public let maxTokens: Int

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case maxTokens = "max_tokens"
    }

    public init(model: String, messages: [AIChatMessage], maxTokens: Int) {
        self.model = model
        self.messages = messages
        self.maxTokens = maxTokens
    }
}

public struct OpenAIChatResponse: Codable {
    public struct Choice: Codable {
        public struct Message: Codable {
            public let content: String
        }

        public let message: Message
    }

    public let choices: [Choice]
}

public struct OpenAIErrorResponse: Codable {
    public struct ErrorDetail: Codable {
        public let message: String
    }

    public let error: ErrorDetail
}

// MARK: - Anthropic

public struct AnthropicMessageRequest: Codable {
    public let model: String
    public let maxTokens: Int
    public let system: String
    public let messages: [AIChatMessage]

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case system
        case messages
    }

    public init(model: String, maxTokens: Int, system: String, messages: [AIChatMessage]) {
        self.model = model
        self.maxTokens = maxTokens
        self.system = system
        self.messages = messages
    }
}

public struct AnthropicMessageResponse: Codable {
    public struct Content: Codable {
        public let text: String
    }

    public let content: [Content]
}

public struct AnthropicErrorResponse: Codable {
    public struct ErrorDetail: Codable {
        public let message: String
    }

    public let error: ErrorDetail
}
