import Foundation

/// Service for interacting with LLM providers.
public protocol LLMService: Sendable {
    func validateURL(_ urlString: String) -> URL?
    func fetchAvailableModels(baseURL: URL, apiKey: String, provider: AIProvider) async throws -> [LLMModel]
    func testConnection(baseURL: URL, apiKey: String) async throws -> Bool
}

public struct DefaultLLMService: LLMService {
    private let session: URLSession
    private let requestTimeout: TimeInterval = 10

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func validateURL(_ urlString: String) -> URL? {
        guard let url = URL(string: urlString),
              let scheme = url.scheme,
              ["http", "https"].contains(scheme.lowercased())
        else { return nil }
        return url
    }

    public func fetchAvailableModels(baseURL: URL, apiKey: String, provider: AIProvider) async throws -> [LLMModel] {
        let request = try buildModelsRequest(baseURL: baseURL, apiKey: apiKey)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode)
        else {
            throw URLError(.badServerResponse)
        }

        let modelsResponse = try JSONDecoder().decode(LLMModelsResponse.self, from: data)
        return modelsResponse.data.sorted { $0.id < $1.id }
    }

    public func testConnection(baseURL: URL, apiKey: String) async throws -> Bool {
        // Append "models" to the base URL for verification, as most providers (OpenAI, Groq, Anthropic)
        // return 404 on the base URL but successfully list models on /models.
        let validationURL = baseURL.appendingPathComponent("models")
        var request = URLRequest(url: validationURL)
        request.httpMethod = "GET"
        request.timeoutInterval = requestTimeout
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let (_, response) = try await session.data(for: request)
        if let httpResponse = response as? HTTPURLResponse {
            return (200...299).contains(httpResponse.statusCode)
        }
        return false
    }

    private func buildModelsRequest(baseURL: URL, apiKey: String) throws -> URLRequest {
        let modelsURL = baseURL.appendingPathComponent("models")
        var request = URLRequest(url: modelsURL)
        request.httpMethod = "GET"
        request.timeoutInterval = requestTimeout

        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        return request
    }
}
