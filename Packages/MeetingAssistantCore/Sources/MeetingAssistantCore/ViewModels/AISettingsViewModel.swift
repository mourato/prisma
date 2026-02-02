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
        settings: AppSettingsStore,
        keychain: KeychainProvider = DefaultKeychainProvider(),
        session: URLSession = .shared
    ) {
        self.settings = settings
        self.keychain = keychain
        self.session = session
        apiKeyText = loadAPIKeyForCurrentProvider() ?? ""

        // Reactive persistence for API Key
        $apiKeyText
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] newValue in
                self?.persistAPIKey(newValue)
            }
            .store(in: &cancellables)

        settings.$aiConfiguration
            .map(\.provider)
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.apiKeyText = self?.loadAPIKeyForCurrentProvider() ?? ""
            }
            .store(in: &cancellables)
    }

    private func persistAPIKey(_ value: String) {
        let providerKey = KeychainManager.apiKeyKey(for: settings.aiConfiguration.provider)
        do {
            if !value.isEmpty {
                try keychain.store(value, for: providerKey)
                logger.info("API Key successfully persisted to Keychain")
            } else {
                try keychain.delete(for: providerKey)
                logger.info("API Key removed from Keychain")
            }
        } catch {
            logger.error("Failed to persist API key: \(error.localizedDescription)")
        }
    }

    private func loadAPIKeyForCurrentProvider() -> String? {
        do {
            return try KeychainManager.retrieveAPIKey(for: settings.aiConfiguration.provider)
        } catch {
            logger.error("Failed to load API key: \(error.localizedDescription)")
            return nil
        }
    }

    public func testAPIConnection() {
        connectionStatus = .testing
        availableModels = []
        modelsFetchError = nil

        guard let url = validateURL(settings.aiConfiguration.baseURL) else {
            connectionStatus = .failure("settings.ai.connection.invalid_url".localized)
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
                self.connectionStatus = .failure(self.connectionErrorMessage(from: error))
            }
        }
    }

    /// Fetches available models from the LLM service's /models endpoint.
    public func fetchAvailableModels() async {
        guard let baseURL = validateURL(settings.aiConfiguration.baseURL) else {
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

    private func buildModelsRequest(for baseURL: URL) throws -> URLRequest {
        let modelsURL = baseURL.appendingPathComponent("models")
        var request = URLRequest(url: modelsURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 10

        if let key = try? KeychainManager.retrieveAPIKey(for: settings.aiConfiguration.provider), !key.isEmpty {
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
        if let key = try? KeychainManager.retrieveAPIKey(for: settings.aiConfiguration.provider), !key.isEmpty {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
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
