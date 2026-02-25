import Foundation
import MeetingAssistantCoreDomain

public extension AppSettingsStore {
    /// Updates the selected model for the current AI provider.
    /// This properly triggers the @Published didSet to persist changes.
    func updateSelectedModel(_ model: String) {
        var config = aiConfiguration
        config.selectedModel = model
        aiConfiguration = config
    }

    /// Updates the AI configuration for a specific provider.
    /// Properly triggers the @Published didSet to persist changes.
    func updateAIConfiguration(provider: AIProvider, baseURL: String? = nil, selectedModel: String? = nil) {
        var config = aiConfiguration
        config.provider = provider
        if let baseURL {
            config.baseURL = baseURL
        }
        if let selectedModel {
            config.selectedModel = selectedModel
        }
        aiConfiguration = config
    }

    func updateEnhancementsProvider(_ provider: AIProvider) {
        var selection = enhancementsAISelection
        guard selection.provider != provider else { return }
        selection.provider = provider
        selection.selectedModel = enhancementsSelectedModel(for: provider)
        enhancementsAISelection = selection
    }

    func updateEnhancementsSelectedModel(_ model: String) {
        var selection = enhancementsAISelection
        let normalizedModel = normalizedEnhancementsModelID(model, for: selection.provider)
        selection.selectedModel = normalizedModel
        enhancementsAISelection = selection
        setEnhancementsProviderSelectedModel(normalizedModel, for: selection.provider)
    }

    func updateEnhancementsDictationProvider(_ provider: AIProvider) {
        var selection = enhancementsDictationAISelection
        guard selection.provider != provider else { return }
        selection.provider = provider
        selection.selectedModel = enhancementsSelectedModel(for: provider)
        enhancementsDictationAISelection = selection
    }

    func updateEnhancementsDictationSelectedModel(_ model: String) {
        var selection = enhancementsDictationAISelection
        let normalizedModel = normalizedEnhancementsModelID(model, for: selection.provider)
        selection.selectedModel = normalizedModel
        enhancementsDictationAISelection = selection
        setEnhancementsProviderSelectedModel(normalizedModel, for: selection.provider)
    }

    func updateEnhancementsSelection(
        provider: AIProvider,
        model: String,
        for mode: IntelligenceKernelMode
    ) {
        let normalizedModel = normalizedEnhancementsModelID(model, for: provider)
        switch mode {
        case .meeting:
            enhancementsAISelection = EnhancementsAISelection(provider: provider, selectedModel: normalizedModel)
        case .dictation, .assistant:
            enhancementsDictationAISelection = EnhancementsAISelection(provider: provider, selectedModel: normalizedModel)
        }
        setEnhancementsProviderSelectedModel(normalizedModel, for: provider)
    }

    func updateEnhancementsProviderSelectedModel(_ model: String, for provider: AIProvider) {
        setEnhancementsProviderSelectedModel(normalizedEnhancementsModelID(model, for: provider), for: provider)
    }

    func enhancementsSelectedModel(for provider: AIProvider) -> String {
        let model = enhancementsProviderSelectedModels[provider.rawValue] ?? ""
        return normalizedEnhancementsModelID(model, for: provider)
    }

    /// Resolves the runtime configuration for Enhancements (post-processing + Q&A).
    var resolvedEnhancementsAIConfiguration: AIConfiguration {
        resolvedEnhancementsAIConfiguration(for: .meeting)
    }

    func resolvedEnhancementsAIConfiguration(for mode: IntelligenceKernelMode) -> AIConfiguration {
        let selection = enhancementsSelection(for: mode)
        let provider = selection.provider
        let baseURL = provider == .custom ? aiConfiguration.baseURL : provider.defaultBaseURL
        let selectedModel = normalizedEnhancementsModelID(selection.selectedModel, for: provider)
        return AIConfiguration(
            provider: provider,
            baseURL: baseURL,
            selectedModel: selectedModel
        )
    }

    var enhancementsInferenceReadinessIssue: EnhancementsInferenceReadinessIssue? {
        enhancementsInferenceReadinessIssue(for: .meeting, apiKeyExists: nil)
    }

    var isEnhancementsInferenceReady: Bool {
        enhancementsInferenceReadinessIssue == nil
    }

    func isEnhancementsInferenceReady(for mode: IntelligenceKernelMode) -> Bool {
        enhancementsInferenceReadinessIssue(for: mode, apiKeyExists: nil) == nil
    }

    func enhancementsInferenceReadinessIssue(
        apiKeyExists: ((AIProvider) -> Bool)?
    ) -> EnhancementsInferenceReadinessIssue? {
        enhancementsInferenceReadinessIssue(for: .meeting, apiKeyExists: apiKeyExists)
    }

    func enhancementsInferenceReadinessIssue(
        for mode: IntelligenceKernelMode,
        apiKeyExists: ((AIProvider) -> Bool)?
    ) -> EnhancementsInferenceReadinessIssue? {
        let config = resolvedEnhancementsAIConfiguration(for: mode)
        let provider = enhancementsSelection(for: mode).provider
        let hasKey = apiKeyExists?(provider) ?? KeychainManager.existsAPIKey(for: provider)
        let hasModel = !config.selectedModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        guard Self.isValidHTTPURLString(config.baseURL) else {
            return .invalidBaseURL
        }

        guard hasKey else {
            return .missingAPIKey
        }

        guard hasModel else {
            return .missingModel
        }

        return nil
    }

    func enhancementsSelection(for mode: IntelligenceKernelMode) -> EnhancementsAISelection {
        switch mode {
        case .meeting:
            enhancementsAISelection
        case .dictation, .assistant:
            enhancementsDictationAISelection
        }
    }

    func normalizedEnhancementsModelID(_ model: String, for provider: AIProvider) -> String {
        Self.normalizedEnhancementsModelID(model, for: provider)
    }

    static func normalizedEnhancementsModelID(_ model: String, for provider: AIProvider) -> String {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        guard provider == .google else { return trimmed }
        return normalizedGoogleEnhancementsModelID(trimmed)
    }

    func backfillEnhancementsSelectionModelsIfNeeded() {
        var updatedProviderSelectedModels = enhancementsProviderSelectedModels
        let updatedMeetingSelection = Self.withBackfilledEnhancementsModel(
            for: enhancementsAISelection,
            providerSelectedModels: &updatedProviderSelectedModels,
            legacyConfiguration: aiConfiguration
        )
        let updatedDictationSelection = Self.withBackfilledEnhancementsModel(
            for: enhancementsDictationAISelection,
            providerSelectedModels: &updatedProviderSelectedModels,
            legacyConfiguration: aiConfiguration
        )

        guard updatedMeetingSelection != enhancementsAISelection
            || updatedDictationSelection != enhancementsDictationAISelection
            || updatedProviderSelectedModels != enhancementsProviderSelectedModels
        else {
            return
        }

        enhancementsAISelection = updatedMeetingSelection
        enhancementsDictationAISelection = updatedDictationSelection
        enhancementsProviderSelectedModels = updatedProviderSelectedModels

        Self.persistBackfilledEnhancementsSelection(enhancementsAISelection)
        Self.persistBackfilledDictationSelection(enhancementsDictationAISelection)
        Self.persistBackfilledProviderModels(enhancementsProviderSelectedModels)
    }

    func setEnhancementsProviderSelectedModel(_ model: String, for provider: AIProvider) {
        let normalizedModel = normalizedEnhancementsModelID(model, for: provider)
        var updated = enhancementsProviderSelectedModels
        if normalizedModel.isEmpty {
            updated.removeValue(forKey: provider.rawValue)
        } else {
            updated[provider.rawValue] = normalizedModel
        }
        enhancementsProviderSelectedModels = updated
    }
}

private extension AppSettingsStore {
    static let enhancementsSelectionStorageKey = "enhancementsAISelection"
    static let enhancementsDictationSelectionStorageKey = "enhancementsDictationAISelection"
    static let enhancementsProviderModelsStorageKey = "enhancementsProviderSelectedModels"

    static func persistBackfilledEnhancementsSelection(_ selection: EnhancementsAISelection) {
        guard let data = try? JSONEncoder().encode(selection) else { return }
        UserDefaults.standard.set(data, forKey: enhancementsSelectionStorageKey)
    }

    static func persistBackfilledDictationSelection(_ selection: EnhancementsAISelection) {
        guard let data = try? JSONEncoder().encode(selection) else { return }
        UserDefaults.standard.set(data, forKey: enhancementsDictationSelectionStorageKey)
    }

    static func persistBackfilledProviderModels(_ models: [String: String]) {
        guard let data = try? JSONEncoder().encode(models) else { return }
        UserDefaults.standard.set(data, forKey: enhancementsProviderModelsStorageKey)
    }

    static func normalizedGoogleEnhancementsModelID(_ model: String) -> String {
        let withoutPrefix: String = if model.hasPrefix("models/") {
            String(model.dropFirst("models/".count))
        } else {
            model
        }

        switch withoutPrefix.lowercased() {
        case "gemini-2.0-flash-001":
            return "gemini-2.0-flash"
        default:
            return withoutPrefix
        }
    }

    static func withBackfilledEnhancementsModel(
        for selection: EnhancementsAISelection,
        providerSelectedModels: inout [String: String],
        legacyConfiguration: AIConfiguration
    ) -> EnhancementsAISelection {
        let providerKey = selection.provider.rawValue
        let normalizedSelectedModel = normalizedEnhancementsModelID(
            selection.selectedModel,
            for: selection.provider
        )

        if !normalizedSelectedModel.isEmpty {
            providerSelectedModels[providerKey] = normalizedSelectedModel
            return EnhancementsAISelection(provider: selection.provider, selectedModel: normalizedSelectedModel)
        }

        if let providerModel = providerSelectedModels[providerKey].map({
            normalizedEnhancementsModelID($0, for: selection.provider)
        }),
            !providerModel.isEmpty
        {
            providerSelectedModels[providerKey] = providerModel
            return EnhancementsAISelection(provider: selection.provider, selectedModel: providerModel)
        }

        let normalizedLegacyModel = normalizedEnhancementsModelID(
            legacyConfiguration.selectedModel,
            for: selection.provider
        )
        if legacyConfiguration.provider == selection.provider,
           !normalizedLegacyModel.isEmpty
        {
            providerSelectedModels[providerKey] = normalizedLegacyModel
            return EnhancementsAISelection(provider: selection.provider, selectedModel: normalizedLegacyModel)
        }

        providerSelectedModels.removeValue(forKey: providerKey)
        return EnhancementsAISelection(provider: selection.provider, selectedModel: "")
    }
}
