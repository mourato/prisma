import Combine
import Foundation
import os.log
import SwiftUI

@MainActor
public class AISettingsViewModel: ObservableObject {
    @Published var settings: AppSettingsStore
    @Published public var showAPIKey = false
    @Published public var apiKeyText = ""
    @Published public var connectionStatus: ConnectionStatus = .unknown
    @Published public var availableModels: [LLMModel] = []
    @Published public var isLoadingModels = false
    @Published public var modelsFetchError: String?

    private let logger = Logger(subsystem: "MeetingAssistant", category: "AISettingsViewModel")
    private let keychain: KeychainProvider
    private let session: URLSession
    private var cancellables = Set<AnyCancellable>()

    public init(
        settings: AppSettingsStore = .shared,
        keychain: KeychainProvider = DefaultKeychainProvider(),
        session: URLSession = .shared
    ) {
        self.settings = settings
        self.keychain = keychain
        self.session = session
        self.apiKeyText = (try? keychain.retrieve(for: .aiAPIKey)) ?? ""

        // Reactive persistence for API Key
        self.$apiKeyText
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] newValue in
                self?.persistAPIKey(newValue)
            }
            .store(in: &self.cancellables)
    }

    private func persistAPIKey(_ value: String) {
        do {
            if !value.isEmpty {
                try self.keychain.store(value, for: .aiAPIKey)
                self.logger.info("API Key successfully persisted to Keychain")
            } else {
                try self.keychain.delete(for: .aiAPIKey)
                self.logger.info("API Key removed from Keychain")
            }
        } catch {
            self.logger.error("Failed to persist API key: \(error.localizedDescription)")
        }
    }

    public func testAPIConnection() {
        self.connectionStatus = .testing
        self.availableModels = []
        self.modelsFetchError = nil

        guard let url = self.validateURL(self.settings.aiConfiguration.baseURL) else {
            self.connectionStatus = .failure(NSLocalizedString("settings.ai.connection.invalid_url", comment: ""))
            return
        }

        Task {
            do {
                let request = try self.buildTestRequest(for: url)
                let (_, response) = try await self.session.data(for: request)
                self.handleTestResponse(response)

                // Fetch models on successful connection
                if self.connectionStatus == .success {
                    await self.fetchAvailableModels()
                }
            } catch {
                self.connectionStatus = .failure(error.localizedDescription)
            }
        }
    }

    /// Fetches available models from the LLM service's /models endpoint.
    public func fetchAvailableModels() async {
        guard let baseURL = self.validateURL(self.settings.aiConfiguration.baseURL) else {
            self.modelsFetchError = NSLocalizedString("settings.ai.connection.invalid_url", comment: "")
            return
        }

        self.isLoadingModels = true
        self.modelsFetchError = nil

        defer { self.isLoadingModels = false }

        do {
            let request = try self.buildModelsRequest(for: baseURL)
            let (data, response) = try await self.session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode)
            else {
                self.modelsFetchError = NSLocalizedString("settings.ai.models.fetch_failed", comment: "")
                return
            }

            let modelsResponse = try JSONDecoder().decode(LLMModelsResponse.self, from: data)
            self.availableModels = modelsResponse.data.sorted { $0.id < $1.id }
            self.logger.info("Fetched \(self.availableModels.count) models from API")
        } catch {
            self.logger.error("Failed to fetch models: \(error.localizedDescription)")
            self.modelsFetchError = error.localizedDescription
        }
    }

    private func buildModelsRequest(for baseURL: URL) throws -> URLRequest {
        let modelsURL = baseURL.appendingPathComponent("models")
        var request = URLRequest(url: modelsURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 10

        if let key = try? self.keychain.retrieve(for: .aiAPIKey), !key.isEmpty {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func validateURL(_ urlString: String) -> URL? {
        guard let url = URL(string: urlString),
              let scheme = url.scheme,
              ["http", "https"].contains(scheme.lowercased())
        else { return nil }
        return url
    }

    private func buildTestRequest(for url: URL) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5
        if let key = try? self.keychain.retrieve(for: .aiAPIKey), !key.isEmpty {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func handleTestResponse(_ response: URLResponse) {
        if let httpResponse = response as? HTTPURLResponse {
            let statusCode = httpResponse.statusCode
            self.connectionStatus = (200...299).contains(statusCode) ? .success : .failure("HTTP \(statusCode)")
        } else {
            self.connectionStatus = .failure(NSLocalizedString("settings.ai.connection.invalid_response", comment: ""))
        }
    }
}
