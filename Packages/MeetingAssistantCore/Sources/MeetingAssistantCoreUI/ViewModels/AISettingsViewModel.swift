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

public struct EnhancementsProviderModelOption: Identifiable, Hashable, Sendable {
    public let provider: AIProvider
    public let modelID: String

    public var id: String {
        "\(provider.rawValue)::\(modelID)"
    }
}

public enum CredentialBootstrapPolicy: Sendable {
    case eager
    case deferredUserAction
}

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
    @Published public var enhancementsAvailableModels: [LLMModel] = []
    @Published public var isLoadingEnhancementsModels = false
    @Published public var enhancementsModelsFetchError: String?
    @Published public var enhancementsProviderModels: [EnhancementsProviderModelOption] = []
    @Published public var isLoadingEnhancementsProviderModels = false
    @Published public var enhancementsProviderModelsFetchError: String?
    @Published public private(set) var enhancementsLastModelsRefreshAt: Date?
    @Published public private(set) var enhancementsLastModelsRefreshSucceeded = false
    @Published public private(set) var enhancementsLastModelsRefreshResultText: String?
    @Published public private(set) var activeEnhancementsProvider: AIProvider = .openai
    @Published public private(set) var isEnhancementsProviderKeySaved = false
    @Published public var enhancementsConnectionStatus: ConnectionStatus = .unknown
    @Published public var enhancementsAPIKeyText = ""
    @Published public var enhancementsActionError: String?
    @Published public var actionError: String?

    private let logger = Logger(subsystem: AppIdentity.logSubsystem, category: "AISettingsViewModel")
    private let keychain: KeychainProvider
    private let llmService: LLMService
    private let credentialBootstrapPolicy: CredentialBootstrapPolicy
    private var cancellables = Set<AnyCancellable>()
    private var lastAutomaticModelsFetchAt: Date?
    private var lastAutomaticEnhancementsModelsFetchAt: Date?
    private var lastAutomaticEnhancementsProviderModelsFetchAt: Date?
    private var enhancementsModelsByProvider: [AIProvider: [LLMModel]] = [:]
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

    public var enhancementsModelsRefreshSummary: String? {
        guard let result = enhancementsLastModelsRefreshResultText,
              let refreshedAt = enhancementsLastModelsRefreshAt
        else { return nil }

        let refreshTime = DateFormatter.localizedString(from: refreshedAt, dateStyle: .none, timeStyle: .short)
        return "\(result) • \(refreshTime)"
    }

    public var hasPendingEnhancementsAPIKeyInput: Bool {
        !normalizedEnhancementsAPIKeyText.isEmpty
    }

    public init(
        settings: AppSettingsStore,
        keychain: KeychainProvider = DefaultKeychainProvider(),
        llmService: LLMService = DefaultLLMService(),
        credentialBootstrapPolicy: CredentialBootstrapPolicy = .eager
    ) {
        self.settings = settings
        self.keychain = keychain
        self.llmService = llmService
        self.credentialBootstrapPolicy = credentialBootstrapPolicy
        activeEnhancementsProvider = settings.enhancementsAISelection.provider

        settings.$aiConfiguration
            .map(\.provider)
            .removeDuplicates()
            .dropFirst() // Skip initial value to avoid clearing selection on tab switch
            .sink { [weak self] _ in
                guard let self else { return }
                settings.updateSelectedModel("") // Clear previous selection (properly triggers didSet)
                clearTransientAPIKey()
                if credentialBootstrapPolicy == .eager {
                    refreshProviderCredentialState()
                } else {
                    resetPrimaryProviderStateForDeferredBootstrap()
                }
            }
            .store(in: &cancellables)

        settings.$enhancementsAISelection
            .map(\.provider)
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] provider in
                guard let self else { return }
                if activeEnhancementsProvider == provider {
                    if credentialBootstrapPolicy == .eager {
                        refreshEnhancementsProviderCredentialState(provider: provider)
                    } else {
                        resetEnhancementsProviderStateForDeferredBootstrap(provider: provider)
                    }
                }
            }
            .store(in: &cancellables)

        // Initial load for current provider
        if credentialBootstrapPolicy == .eager {
            refreshProviderCredentialState()
            refreshEnhancementsProviderCredentialState()
        } else {
            resetPrimaryProviderStateForDeferredBootstrap()
            resetEnhancementsProviderStateForDeferredBootstrap(provider: activeEnhancementsProvider)
        }
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
            if credentialBootstrapPolicy == .eager {
                Task {
                    await fetchAvailableModels()
                }
            } else {
                availableModels = []
                modelsFetchError = nil
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
                    apiKey: apiKeySnapshot,
                    provider: settings.aiConfiguration.provider
                )

                if success {
                    self.connectionStatus = .success
                    try self.persistAPIKey(apiKeySnapshot)
                    self.isKeySaved = !apiKeySnapshot.isEmpty
                    self.clearTransientAPIKey()
                    self.updateUIStates()
                    self.refreshEnhancementsCredentialStateIfNeeded()
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

    @discardableResult
    public func refreshEnhancementsModelsManually() -> Task<Void, Never> {
        Task { [weak self] in
            guard let self else { return }
            await fetchEnhancementsAvailableModels(trigger: .manual)
        }
    }

    @discardableResult
    public func refreshEnhancementsProviderModelsManually() -> Task<Void, Never> {
        Task { [weak self] in
            guard let self else { return }
            await fetchEnhancementsProviderModels(trigger: .manual)
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

    public func refreshEnhancementsProviderCredentialState(provider: AIProvider? = nil) {
        if let provider {
            activeEnhancementsProvider = provider
        }

        let activeProvider = activeEnhancementsProvider
        isEnhancementsProviderKeySaved = keychain.existsAPIKey(for: activeProvider)
        enhancementsModelsFetchError = nil
        enhancementsActionError = nil
        clearTransientEnhancementsAPIKey()

        if let cachedModels = enhancementsModelsByProvider[activeProvider] {
            enhancementsAvailableModels = cachedModels
        } else {
            enhancementsAvailableModels = []
        }

        if isEnhancementsProviderKeySaved {
            enhancementsConnectionStatus = .success
            if credentialBootstrapPolicy == .eager {
                Task {
                    await fetchEnhancementsAvailableModels(provider: activeProvider)
                }
            }
        } else {
            enhancementsConnectionStatus = .unknown
            enhancementsAvailableModels = []
            enhancementsLastModelsRefreshResultText = nil
            enhancementsLastModelsRefreshAt = nil
            enhancementsLastModelsRefreshSucceeded = false
        }

    }

    public func prepareEnhancementsProvider(_ provider: AIProvider) {
        enhancementsActionError = nil
        refreshEnhancementsProviderCredentialState(provider: provider)
    }

    public func hasSavedAPIKey(for provider: AIProvider) -> Bool {
        keychain.existsAPIKey(for: provider)
    }

    public func enhancementsReadinessIssue(for provider: AIProvider) -> EnhancementsInferenceReadinessIssue? {
        let config = enhancementsConfiguration(for: provider)
        guard llmService.validateURL(config.baseURL) != nil else {
            return .invalidBaseURL
        }

        guard hasSavedAPIKey(for: provider) else {
            return .missingAPIKey
        }

        return nil
    }

    @discardableResult
    public func testEnhancementsAPIConnection() -> Task<Void, Never> {
        enhancementsConnectionStatus = .testing
        enhancementsActionError = nil
        enhancementsModelsFetchError = nil

        let provider = activeEnhancementsProvider
        let config = enhancementsConfiguration(for: provider)
        guard let baseURL = llmService.validateURL(config.baseURL) else {
            enhancementsConnectionStatus = .failure("settings.ai.connection.invalid_url".localized)
            return Task {}
        }

        let pendingInput = normalizedEnhancementsAPIKeyText
        let persistedKey = (try? keychain.retrieveAPIKey(for: provider))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let credential = pendingInput.isEmpty ? persistedKey : pendingInput

        guard !credential.isEmpty else {
            enhancementsConnectionStatus = .failure("transcription.qa.error.no_api".localized)
            return Task {}
        }

        return Task {
            do {
                let success = try await llmService.testConnection(
                    baseURL: baseURL,
                    apiKey: credential,
                    provider: provider
                )

                if success {
                    if !pendingInput.isEmpty {
                        try self.persistEnhancementsAPIKey(pendingInput, for: provider)
                    }
                    self.isEnhancementsProviderKeySaved = true
                    self.enhancementsConnectionStatus = .success
                    self.clearTransientEnhancementsAPIKey()
                    await self.fetchEnhancementsAvailableModels(trigger: .manual, provider: provider)

                    if self.settings.aiConfiguration.provider == provider {
                        self.refreshProviderCredentialState()
                    }
                } else {
                    self.enhancementsConnectionStatus = .failure("settings.ai.connection.invalid_response".localized)
                }
            } catch {
                self.enhancementsConnectionStatus = .failure(self.connectionErrorMessage(from: error))
                self.logger.error("Enhancements connection test failed: \(error.localizedDescription)")
            }
        }
    }

    public func removeEnhancementsAPIKey() {
        enhancementsActionError = nil
        let provider = activeEnhancementsProvider
        let providerKey = KeychainManager.apiKeyKey(for: provider)

        do {
            try keychain.delete(for: providerKey)
            clearTransientEnhancementsAPIKey()
            isEnhancementsProviderKeySaved = false
            enhancementsConnectionStatus = .unknown
            enhancementsAvailableModels = []
            enhancementsModelsFetchError = nil

            if settings.aiConfiguration.provider == provider {
                refreshProviderCredentialState()
            }
        } catch {
            enhancementsActionError = "settings.ai.remove_failed".localized
            logger.error("Failed to remove enhancements API key: \(error.localizedDescription)")
        }
    }

    public func fetchEnhancementsAvailableModels(
        trigger: ModelFetchTrigger = .automatic,
        provider: AIProvider? = nil
    ) async {
        let targetProvider = provider ?? activeEnhancementsProvider
        if trigger == .automatic,
           let lastFetch = lastAutomaticEnhancementsModelsFetchAt,
           Date().timeIntervalSince(lastFetch) < automaticModelsFetchThrottleInterval
        {
            return
        }

        let config = enhancementsConfiguration(for: targetProvider)
        guard let baseURL = llmService.validateURL(config.baseURL) else {
            if activeEnhancementsProvider == targetProvider {
                enhancementsModelsFetchError = "settings.ai.connection.invalid_url".localized
                registerEnhancementsModelsRefreshResult(
                    success: false,
                    message: "settings.ai.connection.invalid_url".localized
                )
            }
            return
        }

        guard keychain.existsAPIKey(for: targetProvider) else {
            enhancementsModelsByProvider.removeValue(forKey: targetProvider)
            if activeEnhancementsProvider == targetProvider {
                enhancementsAvailableModels = []
                enhancementsModelsFetchError = nil
            }
            return
        }

        if trigger == .automatic {
            lastAutomaticEnhancementsModelsFetchAt = Date()
        }

        if activeEnhancementsProvider == targetProvider {
            isLoadingEnhancementsModels = true
            enhancementsModelsFetchError = nil
        }
        defer {
            if activeEnhancementsProvider == targetProvider {
                isLoadingEnhancementsModels = false
            }
        }

        do {
            let apiKey = try keychain.retrieveAPIKey(for: targetProvider) ?? ""
            let models = try await llmService.fetchAvailableModels(
                baseURL: baseURL,
                apiKey: apiKey,
                provider: targetProvider
            )
            enhancementsModelsByProvider[targetProvider] = models

            if activeEnhancementsProvider == targetProvider {
                enhancementsAvailableModels = models
                registerEnhancementsModelsRefreshResult(
                    success: true,
                    message: String(format: "settings.ai.models_loaded".localized, models.count)
                )
            }
        } catch {
            if activeEnhancementsProvider == targetProvider {
                enhancementsModelsFetchError = error.localizedDescription
                registerEnhancementsModelsRefreshResult(
                    success: false,
                    message: "settings.ai.models.fetch_failed".localized
                )
            }
        }
    }

    public func fetchEnhancementsProviderModels(trigger: ModelFetchTrigger = .automatic) async {
        if trigger == .automatic,
           let lastFetch = lastAutomaticEnhancementsProviderModelsFetchAt,
           Date().timeIntervalSince(lastFetch) < automaticModelsFetchThrottleInterval
        {
            return
        }

        if trigger == .automatic {
            lastAutomaticEnhancementsProviderModelsFetchAt = Date()
        }

        isLoadingEnhancementsProviderModels = true
        enhancementsProviderModelsFetchError = nil
        defer { isLoadingEnhancementsProviderModels = false }

        var options = Set<EnhancementsProviderModelOption>()
        var hadFailure = false

        // Force one-time legacy migration (.aiAPIKey -> provider slot) when applicable.
        _ = try? keychain.retrieveAPIKey(for: settings.aiConfiguration.provider)

        let apiKeysByProvider: [AIProvider: String]
        do {
            apiKeysByProvider = try keychain.retrieveAPIKeys(for: AIProvider.allCases)
        } catch {
            enhancementsProviderModels = []
            enhancementsProviderModelsFetchError = "settings.ai.models.fetch_failed".localized
            logger.error("Failed to read API keys in batch: \(error.localizedDescription)")
            return
        }

        for provider in AIProvider.allCases {
            guard let apiKey = apiKeysByProvider[provider] else { continue }

            let config = enhancementsConfiguration(for: provider)
            guard let baseURL = llmService.validateURL(config.baseURL) else {
                hadFailure = true
                continue
            }

            do {
                let models = try await llmService.fetchAvailableModels(
                    baseURL: baseURL,
                    apiKey: apiKey,
                    provider: provider
                )

                for model in models {
                    options.insert(
                        EnhancementsProviderModelOption(
                            provider: provider,
                            modelID: model.id
                        )
                    )
                }
            } catch {
                hadFailure = true
                logger.error("Failed to fetch enhancements provider models for \(provider.displayName): \(error.localizedDescription)")
            }
        }

        enhancementsProviderModels = options.sorted { lhs, rhs in
            if lhs.provider == rhs.provider {
                return lhs.modelID.localizedCaseInsensitiveCompare(rhs.modelID) == .orderedAscending
            }
            return lhs.provider.displayName.localizedCaseInsensitiveCompare(rhs.provider.displayName) == .orderedAscending
        }

        if hadFailure {
            enhancementsProviderModelsFetchError = "settings.ai.models.fetch_failed".localized
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
            refreshEnhancementsCredentialStateIfNeeded()
            // swiftformat:disable:next redundantSelf
            logger.info("API Key removed from Keychain for \(self.settings.aiConfiguration.provider.displayName)")
        } catch {
            actionError = "settings.ai.remove_failed".localized
            logger.error("Failed to remove API key: \(error.localizedDescription)")
        }
    }

    private func refreshEnhancementsCredentialStateIfNeeded() {
        guard activeEnhancementsProvider == settings.aiConfiguration.provider else { return }
        refreshEnhancementsProviderCredentialState()
    }

    private func resetPrimaryProviderStateForDeferredBootstrap() {
        isKeySaved = false
        connectionStatus = .unknown
        availableModels = []
        modelsFetchError = nil
        clearTransientAPIKey()
        updateUIStates()
    }

    private func resetEnhancementsProviderStateForDeferredBootstrap(provider: AIProvider) {
        activeEnhancementsProvider = provider
        isEnhancementsProviderKeySaved = false
        enhancementsConnectionStatus = .unknown
        enhancementsAvailableModels = enhancementsModelsByProvider[provider] ?? []
        enhancementsModelsFetchError = nil
        enhancementsActionError = nil
        clearTransientEnhancementsAPIKey()
    }

    private var normalizedAPIKeyText: String {
        apiKeyText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func clearTransientAPIKey() {
        guard !apiKeyText.isEmpty else { return }
        apiKeyText = ""
    }

    private var normalizedEnhancementsAPIKeyText: String {
        enhancementsAPIKeyText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func clearTransientEnhancementsAPIKey() {
        guard !enhancementsAPIKeyText.isEmpty else { return }
        enhancementsAPIKeyText = ""
    }

    private func resolvedCredentialForModelsFetch() -> String {
        if isKeySaved {
            return loadAPIKeyForCurrentProvider() ?? ""
        }
        return normalizedAPIKeyText
    }

    private func enhancementsConfiguration(for provider: AIProvider) -> AIConfiguration {
        let baseURL = provider == .custom ? settings.aiConfiguration.baseURL : provider.defaultBaseURL
        let selectedModel = settings.enhancementsSelectedModel(for: provider)

        return AIConfiguration(
            provider: provider,
            baseURL: baseURL,
            selectedModel: selectedModel
        )
    }

    private func registerModelsRefreshResult(success: Bool, message: String) {
        lastModelsRefreshSucceeded = success
        lastModelsRefreshResultText = message
        lastModelsRefreshAt = Date()
    }

    private func registerEnhancementsModelsRefreshResult(success: Bool, message: String) {
        enhancementsLastModelsRefreshSucceeded = success
        enhancementsLastModelsRefreshResultText = message
        enhancementsLastModelsRefreshAt = Date()
    }

    private func persistEnhancementsAPIKey(_ value: String, for provider: AIProvider) throws {
        let providerKey = KeychainManager.apiKeyKey(for: provider)
        do {
            try keychain.store(value, for: providerKey)
            // swiftformat:disable:next redundantSelf
            logger.info("Enhancements API key persisted for \(provider.displayName)")
        } catch {
            logger.error("Failed to persist enhancements API key: \(error.localizedDescription)")
            throw error
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

public enum ModelFetchTrigger {
    case automatic
    case manual
}
