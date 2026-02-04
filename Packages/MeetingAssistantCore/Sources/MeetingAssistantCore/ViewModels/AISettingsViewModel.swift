import Combine
import Foundation
import os.log
import SwiftUI

@MainActor
public class AISettingsViewModel: ObservableObject {
    @Published var settings: AppSettingsStore
    @Published public var showAPIKey = false
    @Published public var apiKeyText = ""
    @Published public var isKeySaved = false
    @Published public var connectionStatus: ConnectionStatus = .unknown
    @Published public var showVerifyButton = true
    @Published public var showGetApiKeyButton = true
    @Published public var availableModels: [LLMModel] = []
    @Published public var isLoadingModels = false
    @Published public var modelsFetchError: String?
    @Published public var actionError: String?

    private let logger = Logger(subsystem: "MeetingAssistant", category: "AISettingsViewModel")
    private let keychain: KeychainProvider
    private let session: URLSession
    private var cancellables = Set<AnyCancellable>()

    public init(
        settings: AppSettingsStore,
        keychain: KeychainProvider = DefaultKeychainProvider(),
        session: URLSession = .shared
    ) {
        self.settings = settings
        self.keychain = keychain
        self.session = session
        // Initial load for current provider
        apiKeyText = loadAPIKeyForCurrentProvider() ?? ""

        settings.$aiConfiguration
            .map(\.provider)
            .removeDuplicates()
            .dropFirst() // Skip initial value to avoid clearing selection on tab switch
            .sink { [weak self] provider in
                self?.apiKeyText = ""
                self?.isKeySaved = KeychainManager.existsAPIKey(for: provider)
                self?.settings.aiConfiguration.selectedModel = "" // Clear previous selection

                if self?.isKeySaved == true {
                    // Restore verified state and fetch models
                    self?.connectionStatus = .success
                    Task {
                        await self?.fetchAvailableModels()
                    }
                } else {
                    self?.connectionStatus = .unknown
                    self?.availableModels = [] // Clear models if no key
                }

                self?.updateUIStates()
            }
            .store(in: &cancellables)

        // Initial state
        isKeySaved = KeychainManager.existsAPIKey(for: settings.aiConfiguration.provider)
        updateUIStates()
        if isKeySaved {
            connectionStatus = .success
        }
    }

    private func updateUIStates() {
        let isVerified = connectionStatus == .success
        showVerifyButton = !isKeySaved || !isVerified
        showGetApiKeyButton = !isVerified && settings.aiConfiguration.provider.apiKeyURL != nil
    }

    private func persistAPIKey(_ value: String) throws {
        let providerKey = KeychainManager.apiKeyKey(for: self.settings.aiConfiguration.provider)
        do {
            if !value.isEmpty {
                try keychain.store(value, for: providerKey)
                logger.info("API Key successfully persisted to Keychain for \(self.settings.aiConfiguration.provider.displayName)")
            } else {
                try keychain.delete(for: providerKey)
                logger.info("API Key removed from Keychain for \(self.settings.aiConfiguration.provider.displayName)")
            }
        } catch {
            logger.error("Failed to persist API key: \(error.localizedDescription)")
            // We'll handle visual feedback in the verify/remove methods
            throw error
        }
    }

    private func loadAPIKeyForCurrentProvider() -> String? {
        do {
            return try KeychainManager.retrieveAPIKey(for: self.settings.aiConfiguration.provider)
        } catch {
            logger.error("Failed to load API key: \(error.localizedDescription)")
            return nil
        }
    }

    public func testAPIConnection() {
        connectionStatus = .testing
        availableModels = []
        modelsFetchError = nil

        guard let url = validateURL(self.settings.aiConfiguration.baseURL) else {
            connectionStatus = .failure("settings.ai.connection.invalid_url".localized)
            return
        }

        Task {
            do {
                // Use the text from the UI for testing
                let request = try self.buildTestRequest(for: url, apiKey: apiKeyText)
                let (_, response) = try await self.session.data(for: request)
                self.handleTestResponse(response)

                // Fetch models and PERSIST key on successful connection
                if self.connectionStatus == .success {
                    try self.persistAPIKey(apiKeyText)
                    self.isKeySaved = true
                    self.apiKeyText = "" // Clear plaintext from memory
                    self.updateUIStates()
                    await self.fetchAvailableModels()
                }
            } catch {
                self.connectionStatus = .failure(self.connectionErrorMessage(from: error))
                logger.error("Connection test failed: \(error.localizedDescription)")
            }
        }
    }

    /// Fetches available models from the LLM service's /models endpoint.
    public func fetchAvailableModels() async {
        guard let baseURL = validateURL(self.settings.aiConfiguration.baseURL) else {
            modelsFetchError = "settings.ai.connection.invalid_url".localized
            return
        }

        isLoadingModels = true
        modelsFetchError = nil

        defer { self.isLoadingModels = false }

        do {
            let request = try buildModelsRequest(for: baseURL)
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode)
            else {
                modelsFetchError = "settings.ai.models.fetch_failed".localized
                return
            }

            let modelsResponse = try JSONDecoder().decode(LLMModelsResponse.self, from: data)
            availableModels = modelsResponse.data.sorted { $0.id < $1.id }
            // swiftformat:disable:next redundantSelf
            self.logger.info("Fetched \(self.availableModels.count) models from API")
        } catch {
            logger.error("Failed to fetch models: \(error.localizedDescription)")
            modelsFetchError = error.localizedDescription
        }
    }

    /// Removes the API key for the current provider from the Keychain.
    public func removeAPIKey() {
        actionError = nil
        let providerKey = KeychainManager.apiKeyKey(for: self.settings.aiConfiguration.provider)
        do {
            try keychain.delete(for: providerKey)
            apiKeyText = ""
            isKeySaved = false
            connectionStatus = .unknown
            updateUIStates()
            availableModels = []
            logger.info("API Key removed from Keychain for \(self.settings.aiConfiguration.provider.displayName)")
        } catch {
            actionError = "settings.ai.remove_failed".localized
            logger.error("Failed to remove API key: \(error.localizedDescription)")
        }
    }

    private func buildModelsRequest(for baseURL: URL) throws -> URLRequest {
        let modelsURL = baseURL.appendingPathComponent("models")
        var request = URLRequest(url: modelsURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 10

        if let key = try? KeychainManager.retrieveAPIKey(for: self.settings.aiConfiguration.provider), !key.isEmpty {
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

    private func buildTestRequest(for url: URL, apiKey: String) throws -> URLRequest {
        // Append "models" to the base URL for verification, as most providers (OpenAI, Groq, Anthropic)
        // return 404 on the base URL but successfully list models on /models.
        let validationURL = url.appendingPathComponent("models")
        var request = URLRequest(url: validationURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func handleTestResponse(_ response: URLResponse) {
        if let httpResponse = response as? HTTPURLResponse {
            let statusCode = httpResponse.statusCode
            connectionStatus = (200...299).contains(statusCode) ? .success : .failure("HTTP \(statusCode)")
        } else {
            connectionStatus = .failure("settings.ai.connection.invalid_response".localized)
        }
        updateUIStates()
    }

    private func connectionErrorMessage(from error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return "settings.ai.connection.not_connected".localized
            case .timedOut:
                return "settings.ai.connection.timed_out".localized
            case .cannotFindHost:
                return "settings.ai.connection.host_not_found".localized
            case .cannotConnectToHost:
                return "settings.ai.connection.cannot_connect".localized
            case .secureConnectionFailed:
                return "settings.ai.connection.secure_failed".localized
            case .networkConnectionLost:
                return "settings.ai.connection.network_lost".localized
            default:
                return urlError.localizedDescription
            }
        }
        return error.localizedDescription
    }
}
