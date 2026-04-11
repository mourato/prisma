import Foundation

extension AppSettingsStore {
    static let defaultSummaryTemplate = """
    ---
    title: "{{title}}"
    date: "{{date}}"
    duration: "{{duration}}"
    app: "{{app}}"
    type: "{{type}}"
    ---

    # {{title}}

    {{summary}}
    """

    static func loadDecoded<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    static func loadAIConfiguration() -> AIConfiguration {
        guard let config = loadDecoded(AIConfiguration.self, forKey: Keys.aiConfiguration) else {
            return .default
        }

        if !config.legacyApiKey.isEmpty {
            let providerKey = KeychainManager.apiKeyKey(for: config.provider)
            try? KeychainManager.store(config.legacyApiKey, for: providerKey)
            return config.withoutLegacyKey
        }

        return config
    }

    static func loadEnhancementsAISelection(defaultingTo config: AIConfiguration) -> EnhancementsAISelection {
        if let selection = loadDecoded(EnhancementsAISelection.self, forKey: Keys.enhancementsAISelection) {
            return selection
        }

        return EnhancementsAISelection(provider: config.provider, selectedModel: config.selectedModel)
    }

    static func loadEnhancementsDictationAISelection(
        defaultingTo selection: EnhancementsAISelection
    ) -> EnhancementsAISelection {
        if let dictationSelection = loadDecoded(EnhancementsAISelection.self, forKey: Keys.enhancementsDictationAISelection) {
            return dictationSelection
        }

        return selection
    }

    static func loadEnhancementsProviderSelectedModels(
        defaultMeetingSelection: EnhancementsAISelection,
        defaultDictationSelection: EnhancementsAISelection
    ) -> [String: String] {
        let loaded = loadDecoded([String: String].self, forKey: Keys.enhancementsProviderSelectedModels) ?? [:]
        var normalized: [String: String] = [:]

        for (providerRawValue, model) in loaded {
            guard AIProvider(rawValue: providerRawValue) != nil else { continue }
            let normalizedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedModel.isEmpty else { continue }
            normalized[providerRawValue] = normalizedModel
        }

        let meetingModel = defaultMeetingSelection.selectedModel.trimmingCharacters(in: .whitespacesAndNewlines)
        if !meetingModel.isEmpty {
            normalized[defaultMeetingSelection.provider.rawValue] = meetingModel
        }

        let dictationModel = defaultDictationSelection.selectedModel.trimmingCharacters(in: .whitespacesAndNewlines)
        if !dictationModel.isEmpty {
            normalized[defaultDictationSelection.provider.rawValue] = dictationModel
        }

        return normalized
    }

    static func loadTranscriptionDictationSelection() -> TranscriptionProviderSelection {
        guard let selection = loadDecoded(
            TranscriptionProviderSelection.self,
            forKey: Keys.transcriptionDictationSelection
        ) else {
            return .default
        }

        let normalizedModel = selection.provider.normalizedModelID(selection.selectedModel)
        return TranscriptionProviderSelection(
            provider: selection.provider,
            selectedModel: normalizedModel
        )
    }

    static func loadTranscriptionProviderSelectedModels(
        defaultDictationSelection: TranscriptionProviderSelection
    ) -> [String: String] {
        let loaded = loadDecoded([String: String].self, forKey: Keys.transcriptionProviderSelectedModels) ?? [:]
        var normalized: [String: String] = [:]

        for (providerRawValue, model) in loaded {
            guard let provider = TranscriptionProvider(rawValue: providerRawValue) else { continue }
            normalized[providerRawValue] = provider.normalizedModelID(model)
        }

        normalized[defaultDictationSelection.provider.rawValue] = defaultDictationSelection.provider
            .normalizedModelID(defaultDictationSelection.selectedModel)
        return normalized
    }

    static func loadUUID(forKey key: String) -> UUID? {
        UserDefaults.standard.string(forKey: key).flatMap(UUID.init(uuidString:))
    }

    static func loadOptionalInt(forKey key: String) -> Int? {
        UserDefaults.standard.object(forKey: key) as? Int
    }

    static func loadInt(forKey key: String, defaultValue: Int) -> Int {
        let value = UserDefaults.standard.object(forKey: key) as? Int
        return value ?? defaultValue
    }

    static func loadDouble(forKey key: String, defaultValue: Double) -> Double {
        let value = UserDefaults.standard.object(forKey: key) as? Double
        return value ?? defaultValue
    }

    static func loadBoolDefaultIfUnset(forKey key: String, defaultValue: Bool) -> Bool {
        guard UserDefaults.standard.object(forKey: key) != nil else {
            return defaultValue
        }
        return UserDefaults.standard.bool(forKey: key)
    }

    static func loadEnum<T: RawRepresentable & Sendable>(forKey key: String, defaultValue: T) -> T where T.RawValue == String {
        let rawValue = UserDefaults.standard.string(forKey: key)
        return rawValue.flatMap(T.init(rawValue:)) ?? defaultValue
    }

    static func loadURLBookmark(forKey key: String) -> URL? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        var isStale = false
        return try? URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
    }

    static func loadDictationPresetKey(fallback: PresetShortcutKey) -> PresetShortcutKey {
        let rawValue = UserDefaults.standard.string(forKey: Keys.dictationSelectedPresetKey)
        return rawValue.flatMap { PresetShortcutKey(rawValue: $0) } ?? fallback
    }
}
