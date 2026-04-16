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

    func hasSavedEnhancementsAPIKey(for registrationID: UUID?, provider: AIProvider) -> Bool {
        if let registrationID,
           KeychainManager.existsAPIKey(for: registrationID)
        {
            return true
        }

        return keychain.existsAPIKey(for: provider)
    }

    func enhancementsReadinessIssue(for provider: AIProvider) -> EnhancementsInferenceReadinessIssue? {
        let config = enhancementsConfiguration(for: provider)
        guard llmService.validateURL(config.baseURL) != nil else {
            return .invalidBaseURL
        }

        let registrationID = settings.enhancementsRegistration(for: provider)?.id
        guard hasSavedEnhancementsAPIKey(for: registrationID, provider: provider) else {
            return .missingAPIKey
        }

        return nil
    }

    @discardableResult
    func testEnhancementsAPIConnection() -> Task<Void, Never> {
        let provider = activeEnhancementsProvider
        let config = enhancementsConfiguration(for: provider)
        let registrationID = settings.enhancementsRegistration(for: provider)?.id
        let pendingInput = normalizedEnhancementsAPIKeyText

        return Task {
            _ = await self.testEnhancementsAPIConnection(
                provider: provider,
                baseURLString: config.baseURL,
                registrationID: registrationID,
                pendingAPIKeyInput: pendingInput
            )
        }
    }

    func testEnhancementsAPIConnection(
        provider: AIProvider,
        baseURLString: String,
        registrationID: UUID?,
        pendingAPIKeyInput: String
    ) async -> Bool {
        enhancementsConnectionStatus = .testing
        enhancementsActionError = nil
        enhancementsModelsFetchError = nil

        guard let baseURL = llmService.validateURL(baseURLString) else {
            enhancementsConnectionStatus = .failure("settings.ai.connection.invalid_url".localized)
            return false
        }

        let pendingInput = pendingAPIKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let persistedKey = resolvedEnhancementsPersistedAPIKey(
            registrationID: registrationID,
            provider: provider
        )
        let credential = pendingInput.isEmpty ? persistedKey : pendingInput

        guard !credential.isEmpty else {
            enhancementsConnectionStatus = .failure("transcription.qa.error.no_api".localized)
            return false
        }

        do {
            let success = try await llmService.testConnection(
                baseURL: baseURL,
                apiKey: credential,
                provider: provider
            )

            guard success else {
                enhancementsConnectionStatus = .failure("settings.ai.connection.invalid_response".localized)
                return false
            }

            if !pendingInput.isEmpty {
                try persistEnhancementsAPIKey(
                    pendingInput,
                    registrationID: registrationID,
                    provider: provider
                )
            }

            activeEnhancementsProvider = provider
            isEnhancementsProviderKeySaved = hasSavedEnhancementsAPIKey(
                for: registrationID,
                provider: provider
            )
            enhancementsConnectionStatus = .success
            clearTransientEnhancementsAPIKey()
            await fetchEnhancementsAvailableModels(trigger: .manual, provider: provider)
            await fetchEnhancementsProviderModels(trigger: .manual)

            if settings.aiConfiguration.provider == provider {
                refreshProviderCredentialState()
            }

            return true
        } catch {
            enhancementsConnectionStatus = .failure(connectionErrorMessage(from: error))
            logger.error("Enhancements connection test failed: \(error.localizedDescription)")
            return false
        }
    }

    func removeEnhancementsAPIKey() {
        let provider = activeEnhancementsProvider
        let registrationID = settings.enhancementsRegistration(for: provider)?.id
        removeEnhancementsAPIKey(registrationID: registrationID, provider: provider)
    }

    func removeEnhancementsAPIKey(registrationID: UUID?, provider: AIProvider) {
        enhancementsActionError = nil

        do {
            if let registrationID {
                try KeychainManager.deleteAPIKey(for: registrationID)
            } else {
                let providerKey = KeychainManager.apiKeyKey(for: provider)
                try keychain.delete(for: providerKey)
            }

            clearTransientEnhancementsAPIKey()
            isEnhancementsProviderKeySaved = hasSavedEnhancementsAPIKey(
                for: settings.enhancementsRegistration(for: provider)?.id,
                provider: provider
            )
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

    @discardableResult
    func saveEnhancementsAPIKey(
        _ value: String,
        registrationID: UUID?,
        provider: AIProvider
    ) -> Bool {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return true }

        do {
            try persistEnhancementsAPIKey(normalized, registrationID: registrationID, provider: provider)
            isEnhancementsProviderKeySaved = hasSavedEnhancementsAPIKey(
                for: registrationID,
                provider: provider
            )
            enhancementsActionError = nil
            return true
        } catch {
            enhancementsActionError = "settings.ai.save_failed".localized
            logger.error("Failed to save enhancements API key: \(error.localizedDescription)")
            return false
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

        guard let fetchContext = resolvedEnhancementsModelsFetchContext(for: targetProvider) else {
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
            let models = try await llmService.fetchAvailableModels(
                baseURL: fetchContext.baseURL,
                apiKey: fetchContext.apiKey,
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

    private func resolvedEnhancementsModelsFetchContext(
        for targetProvider: AIProvider
    ) -> (baseURL: URL, apiKey: String)? {
        let config = enhancementsConfiguration(for: targetProvider)
        guard let baseURL = llmService.validateURL(config.baseURL) else {
            if activeEnhancementsProvider == targetProvider {
                enhancementsModelsFetchError = "settings.ai.connection.invalid_url".localized
                registerEnhancementsModelsRefreshResult(
                    success: false,
                    message: "settings.ai.connection.invalid_url".localized
                )
            }
            return nil
        }

        let registrationID = settings.enhancementsRegistration(for: targetProvider)?.id
        let resolvedAPIKey = resolvedEnhancementsPersistedAPIKey(
            registrationID: registrationID,
            provider: targetProvider
        )

        guard !resolvedAPIKey.isEmpty else {
            enhancementsModelsByProvider.removeValue(forKey: targetProvider)
            if activeEnhancementsProvider == targetProvider {
                enhancementsAvailableModels = []
                enhancementsModelsFetchError = nil
            }
            return nil
        }

        return (baseURL, resolvedAPIKey)
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

        let registrations = settings.enhancementsProviderRegistrations

        do {
            if registrations.isEmpty {
                hadFailure = try await collectLegacyEnhancementsProviderModelOptions(into: &options)
            } else {
                hadFailure = try await collectRegistrationEnhancementsProviderModelOptions(
                    registrations,
                    into: &options
                )
            }
        } catch {
            enhancementsProviderModels = []
            enhancementsProviderModelsFetchError = "settings.ai.models.fetch_failed".localized
            logger.error("Failed to read API keys in batch: \(error.localizedDescription)")
            return
        }

        enhancementsProviderModels = sortedEnhancementsProviderModelOptions(options)

        if hadFailure {
            enhancementsProviderModelsFetchError = "settings.ai.models.fetch_failed".localized
        }
    }

    private func collectLegacyEnhancementsProviderModelOptions(
        into options: inout Set<EnhancementsProviderModelOption>
    ) async throws -> Bool {
        let apiKeysByProvider = try keychain.retrieveAPIKeys(for: AIProvider.allCases)
        var hadFailure = false

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

        return hadFailure
    }

    private func collectRegistrationEnhancementsProviderModelOptions(
        _ registrations: [EnhancementsProviderRegistration],
        into options: inout Set<EnhancementsProviderModelOption>
    ) async throws -> Bool {
        let providerKeysByProvider = try keychain.retrieveAPIKeys(
            for: Array(Set(registrations.map(\.provider)))
        )
        var hadFailure = false

        for registration in registrations {
            let provider = registration.provider

            let registrationKey = (try? KeychainManager.retrieveAPIKey(for: registration.id))?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let apiKey = if let registrationKey,
                            !registrationKey.isEmpty
            {
                registrationKey
            } else {
                providerKeysByProvider[provider]
            }

            guard let apiKey, !apiKey.isEmpty else { continue }

            let config = enhancementsConfiguration(for: registration)
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
                            registrationID: registration.id,
                            registrationName: registration.displayName,
                            modelID: model.id
                        )
                    )
                }
            } catch {
                hadFailure = true
                logger.error("Failed to fetch enhancements provider models for registration \(registration.displayName): \(error.localizedDescription)")
            }
        }

        return hadFailure
    }

    private func sortedEnhancementsProviderModelOptions(
        _ options: Set<EnhancementsProviderModelOption>
    ) -> [EnhancementsProviderModelOption] {
        options.sorted { lhs, rhs in
            let lhsName = lhs.registrationName ?? lhs.provider.displayName
            let rhsName = rhs.registrationName ?? rhs.provider.displayName

            if lhsName.caseInsensitiveCompare(rhsName) == .orderedSame {
                return lhs.modelID.localizedCaseInsensitiveCompare(rhs.modelID) == .orderedAscending
            }
            return lhsName.localizedCaseInsensitiveCompare(rhsName) == .orderedAscending
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

    private func enhancementsConfiguration(for registration: EnhancementsProviderRegistration) -> AIConfiguration {
        let selectedModel = settings.enhancementsSelectedModel(for: registration.id)

        return AIConfiguration(
            provider: registration.provider,
            baseURL: registration.resolvedBaseURL,
            selectedModel: selectedModel
        )
    }

    private func registerEnhancementsModelsRefreshResult(success: Bool, message: String) {
        enhancementsLastModelsRefreshSucceeded = success
        enhancementsLastModelsRefreshResultText = message
        enhancementsLastModelsRefreshAt = Date()
    }

    private func persistEnhancementsAPIKey(_ value: String, for provider: AIProvider) throws {
        try persistEnhancementsAPIKey(value, registrationID: nil, provider: provider)
    }

    private func persistEnhancementsAPIKey(
        _ value: String,
        registrationID: UUID?,
        provider: AIProvider
    ) throws {
        do {
            if let registrationID {
                try KeychainManager.storeAPIKey(value, for: registrationID)
            } else {
                let providerKey = KeychainManager.apiKeyKey(for: provider)
                try keychain.store(value, for: providerKey)
            }
            // swiftformat:disable:next redundantSelf
            logger.info("Enhancements API key persisted for \(provider.displayName)")
        } catch {
            logger.error("Failed to persist enhancements API key: \(error.localizedDescription)")
            throw error
        }
    }

    private func resolvedEnhancementsPersistedAPIKey(
        registrationID: UUID?,
        provider: AIProvider
    ) -> String {
        if let registrationID,
           let key = (try? KeychainManager.retrieveAPIKey(for: registrationID))?
           .trimmingCharacters(in: .whitespacesAndNewlines),
           !key.isEmpty
        {
            return key
        }

        return (try? keychain.retrieveAPIKey(for: provider))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

}
