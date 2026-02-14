import Combine
import Foundation
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
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
    @Published public private(set) var lastModelsRefreshAt: Date?
    @Published public private(set) var lastModelsRefreshSucceeded = false
    @Published public private(set) var lastModelsRefreshResultText: String?
    @Published public var actionError: String?

    private let logger = Logger(subsystem: "MeetingAssistant", category: "AISettingsViewModel")
    private let keychain: KeychainProvider
    private let llmService: LLMService
    private var cancellables = Set<AnyCancellable>()
    private var lastAutomaticModelsFetchAt: Date?
    private let automaticModelsFetchThrottleInterval: TimeInterval = 15

    public var canRefreshModels: Bool {
        isKeySaved || !normalizedAPIKeyText.isEmpty
    }

    public var hasPendingAPIKeyInput: Bool {
        !normalizedAPIKeyText.isEmpty
    }

    public var modelsRefreshSummary: String? {
        guard let result = lastModelsRefreshResultText,
              let refreshedAt = lastModelsRefreshAt
        else { return nil }

        let refreshTime = DateFormatter.localizedString(from: refreshedAt, dateStyle: .none, timeStyle: .short)
        return "\(result) • \(refreshTime)"
    }

    public init(
        settings: AppSettingsStore,
        keychain: KeychainProvider = DefaultKeychainProvider(),
        llmService: LLMService = DefaultLLMService()
    ) {
        self.settings = settings
        self.keychain = keychain
        self.llmService = llmService

        settings.$aiConfiguration
            .map(\.provider)
            .removeDuplicates()
            .dropFirst() // Skip initial value to avoid clearing selection on tab switch
            .sink { [weak self] _ in
                guard let self else { return }
                settings.updateSelectedModel("") // Clear previous selection (properly triggers didSet)
                clearTransientAPIKey()

                refreshProviderCredentialState()
            }
            .store(in: &cancellables)

        // Initial load for current provider
        refreshProviderCredentialState()
    }

    private func updateUIStates() {
        showVerifyButton = !isKeySaved
        showGetApiKeyButton = !isKeySaved && settings.aiConfiguration.provider.apiKeyURL != nil
    }

    public func refreshProviderCredentialState() {
        isKeySaved = keychain.existsAPIKey(for: settings.aiConfiguration.provider)
        clearTransientAPIKey()

        if isKeySaved {
            connectionStatus = .success
            Task {
                await fetchAvailableModels()
            }
        } else {
            connectionStatus = .unknown
            availableModels = []
            modelsFetchError = nil
        }

        updateUIStates()
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

    @discardableResult
    public func testAPIConnection() -> Task<Void, Never> {
        connectionStatus = .testing
        availableModels = []
        modelsFetchError = nil

        let apiKeySnapshot = normalizedAPIKeyText
        guard let url = llmService.validateURL(settings.aiConfiguration.baseURL) else {
            connectionStatus = .failure("settings.ai.connection.invalid_url".localized)
            clearTransientAPIKey()
            return Task {}
        }

        return Task {
            do {
                let success = try await llmService.testConnection(
                    baseURL: url,
                    apiKey: apiKeySnapshot
                )

                if success {
                    self.connectionStatus = .success
                    try self.persistAPIKey(apiKeySnapshot)
                    self.isKeySaved = !apiKeySnapshot.isEmpty
                    self.clearTransientAPIKey()
                    self.updateUIStates()
                    await self.fetchAvailableModels()
                } else {
                    self.connectionStatus = .failure("settings.ai.connection.invalid_response".localized)
                    self.clearTransientAPIKey()
                    self.updateUIStates()
                }
            } catch {
                self.connectionStatus = .failure(self.connectionErrorMessage(from: error))
                logger.error("Connection test failed: \(error.localizedDescription)")
                self.clearTransientAPIKey()
            }
        }
    }

    @discardableResult
    public func refreshModelsManually() -> Task<Void, Never> {
        Task { [weak self] in
            guard let self else { return }
            await fetchAvailableModels(trigger: .manual)
        }
    }

    /// Fetches available models from the LLM service's /models endpoint.
    public func fetchAvailableModels(trigger: ModelFetchTrigger = .automatic) async {
        if trigger == .automatic,
           let lastFetch = lastAutomaticModelsFetchAt,
           Date().timeIntervalSince(lastFetch) < automaticModelsFetchThrottleInterval
        {
            return
        }

        guard let baseURL = llmService.validateURL(settings.aiConfiguration.baseURL) else {
            modelsFetchError = "settings.ai.connection.invalid_url".localized
            registerModelsRefreshResult(success: false, message: "settings.ai.connection.invalid_url".localized)
            return
        }

        if trigger == .automatic {
            lastAutomaticModelsFetchAt = Date()
        }

        isLoadingModels = true
        modelsFetchError = nil

        defer { self.isLoadingModels = false }

        do {
            let credential = resolvedCredentialForModelsFetch()
            availableModels = try await llmService.fetchAvailableModels(
                baseURL: baseURL,
                apiKey: credential,
                provider: settings.aiConfiguration.provider
            )
            registerModelsRefreshResult(
                success: true,
                message: String(format: "settings.ai.models_loaded".localized, availableModels.count)
            )
            // swiftformat:disable:next redundantSelf
            self.logger.info("Fetched \(self.availableModels.count) models from API")
        } catch {
            logger.error("Failed to fetch models: \(error.localizedDescription)")
            modelsFetchError = error.localizedDescription
            registerModelsRefreshResult(success: false, message: "settings.ai.models.fetch_failed".localized)
        }
    }

    /// Removes the API key for the current provider from the Keychain.
    public func removeAPIKey() {
        actionError = nil
        let providerKey = KeychainManager.apiKeyKey(for: settings.aiConfiguration.provider)
        do {
            try keychain.delete(for: providerKey)
            clearTransientAPIKey()
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

    private var normalizedAPIKeyText: String {
        apiKeyText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func clearTransientAPIKey() {
        guard !apiKeyText.isEmpty else { return }
        apiKeyText = ""
    }

    private func resolvedCredentialForModelsFetch() -> String {
        if isKeySaved {
            return loadAPIKeyForCurrentProvider() ?? ""
        }
        return normalizedAPIKeyText
    }

    private func registerModelsRefreshResult(success: Bool, message: String) {
        lastModelsRefreshSucceeded = success
        lastModelsRefreshResultText = message
        lastModelsRefreshAt = Date()
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

public enum ModelFetchTrigger {
    case automatic
    case manual
}
