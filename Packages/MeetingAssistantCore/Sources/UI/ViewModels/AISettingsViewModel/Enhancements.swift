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

public extension AISettingsViewModel {
    func refreshEnhancementsProviderCredentialState(provider: AIProvider? = nil) {
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

    func prepareEnhancementsProvider(_ provider: AIProvider) {
        enhancementsActionError = nil
        refreshEnhancementsProviderCredentialState(provider: provider)
    }

    func hasSavedAPIKey(for provider: AIProvider) -> Bool {
        keychain.existsAPIKey(for: provider)
    }

    func enhancementsReadinessIssue(for provider: AIProvider) -> EnhancementsInferenceReadinessIssue? {
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
    func testEnhancementsAPIConnection() -> Task<Void, Never> {
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

    func removeEnhancementsAPIKey() {
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

    func fetchEnhancementsAvailableModels(
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

    func fetchEnhancementsProviderModels(trigger: ModelFetchTrigger = .automatic) async {
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

    func resetEnhancementsProviderStateForDeferredBootstrap(provider: AIProvider) {
        activeEnhancementsProvider = provider
        isEnhancementsProviderKeySaved = false
        enhancementsConnectionStatus = .unknown
        enhancementsAvailableModels = enhancementsModelsByProvider[provider] ?? []
        enhancementsModelsFetchError = nil
        enhancementsActionError = nil
        clearTransientEnhancementsAPIKey()
    }

    private var normalizedEnhancementsAPIKeyText: String {
        enhancementsAPIKeyText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func clearTransientEnhancementsAPIKey() {
        guard !enhancementsAPIKeyText.isEmpty else { return }
        enhancementsAPIKeyText = ""
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

}
