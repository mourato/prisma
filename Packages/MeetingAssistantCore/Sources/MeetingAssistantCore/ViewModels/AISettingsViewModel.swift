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
    private let llmService: LLMService
    private var cancellables = Set<AnyCancellable>()

    public init(
        settings: AppSettingsStore,
        keychain: KeychainProvider = DefaultKeychainProvider(),
        llmService: LLMService = DefaultLLMService()
    ) {
        self.settings = settings
        self.keychain = keychain
        self.llmService = llmService
        // Initial load for current provider
        apiKeyText = loadAPIKeyForCurrentProvider() ?? ""

        settings.$aiConfiguration
            .map(\.provider)
            .removeDuplicates()
            .dropFirst() // Skip initial value to avoid clearing selection on tab switch
            .sink { [weak self] provider in
                guard let self else { return }
                apiKeyText = ""
                isKeySaved = self.keychain.existsAPIKey(for: provider)
                self.settings.updateSelectedModel("") // Clear previous selection (properly triggers didSet)

                if isKeySaved {
                    // Restore verified state and fetch models
                    connectionStatus = .success
                    Task {
                        await self.fetchAvailableModels()
                    }
                } else {
                    connectionStatus = .unknown
                    availableModels = [] // Clear models if no key
                }

                updateUIStates()
            }
            .store(in: &cancellables)

        // Initial state
        isKeySaved = keychain.existsAPIKey(for: settings.aiConfiguration.provider)
        updateUIStates()
        if isKeySaved {
            connectionStatus = .success
            Task {
                await fetchAvailableModels()
            }
        }
    }

    private func updateUIStates() {
        let isVerified = connectionStatus == .success
        showVerifyButton = !isKeySaved || !isVerified
        showGetApiKeyButton = !isVerified && settings.aiConfiguration.provider.apiKeyURL != nil
    }

    private func persistAPIKey(_ value: String) throws {
        let providerKey = KeychainManager.apiKeyKey(for: settings.aiConfiguration.provider)
        do {
            if !value.isEmpty {
                try keychain.store(value, for: providerKey)
                // swiftformat:disable:next redundantSelf
                logger.info("API Key successfully persisted to Keychain for \(self.settings.aiConfiguration.provider.displayName)")
            } else {
                try keychain.delete(for: providerKey)
                // swiftformat:disable:next redundantSelf
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
            return try keychain.retrieveAPIKey(for: settings.aiConfiguration.provider)
        } catch {
            logger.error("Failed to load API key: \(error.localizedDescription)")
            return nil
        }
    }

    public func testAPIConnection() {
        connectionStatus = .testing
        availableModels = []
        modelsFetchError = nil

        guard let url = llmService.validateURL(settings.aiConfiguration.baseURL) else {
            connectionStatus = .failure("settings.ai.connection.invalid_url".localized)
            return
        }

        Task {
            do {
                let success = try await llmService.testConnection(
                    baseURL: url,
                    apiKey: apiKeyText
                )

                if success {
                    self.connectionStatus = .success
                    try self.persistAPIKey(apiKeyText)
                    self.isKeySaved = true
                    self.apiKeyText = "" // Clear plaintext from memory
                    self.updateUIStates()
                    await self.fetchAvailableModels()
                } else {
                    self.connectionStatus = .failure("settings.ai.connection.invalid_response".localized)
                    self.updateUIStates()
                }
            } catch {
                self.connectionStatus = .failure(self.connectionErrorMessage(from: error))
                logger.error("Connection test failed: \(error.localizedDescription)")
            }
        }
    }

    /// Fetches available models from the LLM service's /models endpoint.
    public func fetchAvailableModels() async {
        guard let baseURL = llmService.validateURL(settings.aiConfiguration.baseURL) else {
            modelsFetchError = "settings.ai.connection.invalid_url".localized
            return
        }

        isLoadingModels = true
        modelsFetchError = nil

        defer { self.isLoadingModels = false }

        do {
            availableModels = try await llmService.fetchAvailableModels(
                baseURL: baseURL,
                apiKey: apiKeyText.isEmpty ? (loadAPIKeyForCurrentProvider() ?? "") : apiKeyText,
                provider: settings.aiConfiguration.provider
            )
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
        let providerKey = KeychainManager.apiKeyKey(for: settings.aiConfiguration.provider)
        do {
            try keychain.delete(for: providerKey)
            apiKeyText = ""
            isKeySaved = false
            connectionStatus = .unknown
            updateUIStates()
            availableModels = []
            // swiftformat:disable:next redundantSelf
            logger.info("API Key removed from Keychain for \(self.settings.aiConfiguration.provider.displayName)")
        } catch {
            actionError = "settings.ai.remove_failed".localized
            logger.error("Failed to remove API key: \(error.localizedDescription)")
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
