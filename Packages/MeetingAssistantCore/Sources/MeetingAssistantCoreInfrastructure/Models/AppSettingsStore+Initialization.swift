import Foundation
import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain

// MARK: - Initialization Helpers

extension AppSettingsStore {
    /// Holds temporarily loaded values during initialization to avoid multiple UserDefaults reads.
    struct InitializationContext {
        var loadedAIConfiguration: AIConfiguration
        var loadedEnhancementsSelection: EnhancementsAISelection
        var loadedDictationSelection: EnhancementsAISelection
        var loadedAssistantShortcutDefinition: ShortcutDefinition?
        var loadedDictationShortcutDefinition: ShortcutDefinition?
        var loadedMeetingShortcutDefinition: ShortcutDefinition?
        var loadedIntegrations: [AssistantIntegrationConfig]?
        var loadedContextAwarenessEnabled: Bool
        var hasPersistedLegacyPerTargetBrowsers: Bool
        var hasGlobalBrowserSetting: Bool
    }

    /// Creates the initialization context by loading all required values from UserDefaults.
    static func createInitializationContext() -> InitializationContext {
        let loadedAIConfiguration = loadAIConfiguration()
        let loadedEnhancementsSelection = loadEnhancementsAISelection(defaultingTo: loadedAIConfiguration)
        let loadedDictationSelection = loadEnhancementsDictationAISelection(defaultingTo: loadedEnhancementsSelection)

        let loadedAssistantShortcutDefinition = loadDecoded(
            ShortcutDefinition.self,
            forKey: Keys.assistantShortcutDefinition
        )
        let loadedDictationShortcutDefinition = loadDecoded(
            ShortcutDefinition.self,
            forKey: Keys.dictationShortcutDefinition
        )
        let loadedMeetingShortcutDefinition = loadDecoded(
            ShortcutDefinition.self,
            forKey: Keys.meetingShortcutDefinition
        )

        let loadedIntegrations = loadDecoded([AssistantIntegrationConfig].self, forKey: Keys.assistantIntegrations)
        let loadedContextAwarenessEnabled = UserDefaults.standard.bool(forKey: Keys.contextAwarenessEnabled)

        let hasPersistedMarkdownWebTargets = UserDefaults.standard.object(forKey: Keys.markdownWebTargets) != nil
        let hasPersistedWebMeetingTargets = UserDefaults.standard.object(forKey: Keys.webMeetingTargets) != nil
        let hasPersistedLegacyPerTargetBrowsers = hasPersistedMarkdownWebTargets || hasPersistedWebMeetingTargets
        let hasGlobalBrowserSetting = UserDefaults.standard.object(forKey: Keys.webTargetBrowserBundleIdentifiers) != nil

        return InitializationContext(
            loadedAIConfiguration: loadedAIConfiguration,
            loadedEnhancementsSelection: loadedEnhancementsSelection,
            loadedDictationSelection: loadedDictationSelection,
            loadedAssistantShortcutDefinition: loadedAssistantShortcutDefinition,
            loadedDictationShortcutDefinition: loadedDictationShortcutDefinition,
            loadedMeetingShortcutDefinition: loadedMeetingShortcutDefinition,
            loadedIntegrations: loadedIntegrations,
            loadedContextAwarenessEnabled: loadedContextAwarenessEnabled,
            hasPersistedLegacyPerTargetBrowsers: hasPersistedLegacyPerTargetBrowsers,
            hasGlobalBrowserSetting: hasGlobalBrowserSetting
        )
    }

    // MARK: - Static Initialization Helpers

    /// Loads AI configuration properties from the context.
    static func loadAIConfigurationValues(from context: InitializationContext) -> (
        aiConfiguration: AIConfiguration,
        enhancementsAISelection: EnhancementsAISelection,
        enhancementsDictationAISelection: EnhancementsAISelection,
        enhancementsProviderSelectedModels: [String: String]
    ) {
        let enhancementsProviderSelectedModels = loadEnhancementsProviderSelectedModels(
            defaultMeetingSelection: context.loadedEnhancementsSelection,
            defaultDictationSelection: context.loadedDictationSelection
        )
        return (
            context.loadedAIConfiguration,
            context.loadedEnhancementsSelection,
            context.loadedDictationSelection,
            enhancementsProviderSelectedModels
        )
    }

    /// Loads post-processing related properties.
    static func loadPostProcessingSettings() -> (
        systemPrompt: String,
        userPrompts: [PostProcessingPrompt],
        dictationPrompts: [PostProcessingPrompt],
        deletedPromptIds: Set<UUID>,
        postProcessingEnabled: Bool,
        dictationStructuredPostProcessingEnabled: Bool,
        isDiarizationEnabled: Bool,
        minSpeakers: Int?,
        maxSpeakers: Int?,
        numSpeakers: Int?,
        audioFormat: AudioFormat,
        selectedPromptId: UUID?,
        dictationSelectedPromptId: UUID?,
        shouldMergeAudioFiles: Bool
    ) {
        (
            UserDefaults.standard.string(forKey: Keys.systemPrompt) ?? AIPromptTemplates.defaultSystemPrompt,
            loadDecoded([PostProcessingPrompt].self, forKey: Keys.userPrompts) ?? [],
            loadDecoded([PostProcessingPrompt].self, forKey: Keys.dictationPrompts) ?? [],
            loadDecoded(Set<UUID>.self, forKey: Keys.deletedPromptIds) ?? [],
            UserDefaults.standard.bool(forKey: Keys.postProcessingEnabled),
            loadBoolDefaultIfUnset(forKey: Keys.dictationStructuredPostProcessingEnabled, defaultValue: false),
            UserDefaults.standard.bool(forKey: Keys.isDiarizationEnabled),
            loadOptionalInt(forKey: Keys.minSpeakers),
            loadOptionalInt(forKey: Keys.maxSpeakers),
            loadOptionalInt(forKey: Keys.numSpeakers),
            loadEnum(forKey: PostProcessingKeys.audioFormat, defaultValue: .m4a),
            loadUUID(forKey: Keys.selectedPromptId),
            loadUUID(forKey: Keys.dictationSelectedPromptId),
            loadBoolDefaultIfUnset(forKey: PostProcessingKeys.shouldMergeAudioFiles, defaultValue: true)
        )
    }

    /// Loads audio and language settings.
    static func loadAudioAndLanguageSettings() -> (
        selectedLanguage: AppLanguage,
        audioDevicePriority: [String],
        useSystemDefaultInput: Bool,
        muteOutputDuringRecording: Bool,
        autoIncreaseMicrophoneVolume: Bool
    ) {
        (
            loadEnum(forKey: Keys.selectedLanguage, defaultValue: .system),
            UserDefaults.standard.stringArray(forKey: Keys.audioDevicePriority) ?? [],
            loadBoolDefaultIfUnset(forKey: Keys.useSystemDefaultInput, defaultValue: true),
            UserDefaults.standard.bool(forKey: Keys.muteOutputDuringRecording),
            UserDefaults.standard.bool(forKey: Keys.autoIncreaseMicrophoneVolume)
        )
    }

    /// Loads shortcut activation settings.
    static func loadShortcutActivationSettings() -> (
        shortcutActivationMode: ShortcutActivationMode,
        dictationShortcutActivationMode: ShortcutActivationMode,
        shortcutDoubleTapIntervalMilliseconds: Double,
        useEscapeToCancelRecording: Bool,
        selectedPresetKey: PresetShortcutKey,
        dictationSelectedPresetKey: PresetShortcutKey,
        meetingSelectedPresetKey: PresetShortcutKey
    ) {
        let rawActivationMode = UserDefaults.standard.string(forKey: Keys.shortcutActivationMode)
        let resolvedActivationMode = rawActivationMode.flatMap { ShortcutActivationMode(rawValue: $0) } ?? .holdOrToggle

        let rawDictationActivationMode = UserDefaults.standard.string(forKey: Keys.dictationShortcutActivationMode)
        let dictationActivationMode = rawDictationActivationMode
            .flatMap { ShortcutActivationMode(rawValue: $0) }
            ?? resolvedActivationMode

        let rawPresetKey = UserDefaults.standard.string(forKey: Keys.selectedPresetKey)
        let presetKey = rawPresetKey.flatMap { PresetShortcutKey(rawValue: $0) } ?? .fn

        let rawDictationKey = UserDefaults.standard.string(forKey: Keys.dictationSelectedPresetKey)
        let dictationPresetKey = rawDictationKey.flatMap { PresetShortcutKey(rawValue: $0) }
            ?? (rawPresetKey.flatMap { PresetShortcutKey(rawValue: $0) } ?? .fn)

        let rawMeetingKey = UserDefaults.standard.string(forKey: Keys.meetingSelectedPresetKey)
        let meetingPresetKey = rawMeetingKey.flatMap { PresetShortcutKey(rawValue: $0) } ?? .notSpecified

        return (
            resolvedActivationMode,
            dictationActivationMode,
            loadDouble(forKey: Keys.shortcutDoubleTapIntervalMilliseconds, defaultValue: defaultShortcutDoubleTapIntervalMilliseconds),
            UserDefaults.standard.bool(forKey: Keys.useEscapeToCancelRecording),
            presetKey,
            dictationPresetKey,
            meetingPresetKey
        )
    }

    /// Loads modifier shortcut gestures.
    static func loadModifierShortcutGestures() -> (
        dictation: ModifierShortcutGesture?,
        assistant: ModifierShortcutGesture?,
        meeting: ModifierShortcutGesture?
    ) {
        (
            loadDecoded(ModifierShortcutGesture.self, forKey: Keys.dictationModifierShortcutGesture),
            loadDecoded(ModifierShortcutGesture.self, forKey: Keys.assistantModifierShortcutGesture),
            loadDecoded(ModifierShortcutGesture.self, forKey: Keys.meetingModifierShortcutGesture)
        )
    }

    /// Loads assistant-specific settings.
    static func loadAssistantSettings(from context: InitializationContext) -> (
        assistantShortcutActivationMode: ShortcutActivationMode,
        assistantUseEscapeToCancelRecording: Bool,
        assistantUseEnterToStopRecording: Bool,
        assistantSelectedPresetKey: PresetShortcutKey,
        assistantLayerShortcutKey: String,
        assistantIntegrations: [AssistantIntegrationConfig],
        assistantSelectedIntegrationId: UUID?,
        assistantRaycastEnabled: Bool,
        assistantRaycastDeepLink: String
    ) {
        let rawAssistantActivation = UserDefaults.standard.string(forKey: Keys.assistantShortcutActivationMode)
        let activationMode = rawAssistantActivation
            .flatMap { ShortcutActivationMode(rawValue: $0) } ?? .holdOrToggle

        let rawAssistantPresetKey = UserDefaults.standard.string(forKey: Keys.assistantSelectedPresetKey)
        let presetKey = rawAssistantPresetKey.flatMap { PresetShortcutKey(rawValue: $0) } ?? .rightOption

        let rawSelectedIntegrationId = UserDefaults.standard.string(forKey: Keys.assistantSelectedIntegrationId)

        return (
            activationMode,
            UserDefaults.standard.bool(forKey: Keys.assistantUseEscapeToCancelRecording),
            UserDefaults.standard.bool(forKey: Keys.assistantUseEnterToStopRecording),
            presetKey,
            normalizedLayerShortcutKey(UserDefaults.standard.string(forKey: Keys.assistantLayerShortcutKey)) ?? "A",
            context.loadedIntegrations ?? [AssistantIntegrationConfig.defaultRaycast],
            rawSelectedIntegrationId.flatMap(UUID.init(uuidString:)),
            UserDefaults.standard.bool(forKey: Keys.assistantRaycastEnabled),
            UserDefaults.standard.string(forKey: Keys.assistantRaycastDeepLink) ?? AssistantIntegrationConfig.defaultRaycastDeepLink
        )
    }

    /// Loads meeting summary settings.
    static func loadMeetingSummarySettings() -> (
        meetingTypeAutoDetectEnabled: Bool,
        meetingPrompts: [PostProcessingPrompt],
        summaryExportFolder: URL?,
        summaryTemplate: String,
        summaryTemplateEnabled: Bool,
        autoExportSummaries: Bool,
        summaryExportSafetyPolicyLevel: SummaryExportSafetyPolicyLevel,
        meetingQnAEnabled: Bool
    ) {
        var prompts: [PostProcessingPrompt] = []
        if let data = UserDefaults.standard.data(forKey: Keys.meetingPrompts),
           let decoded = try? JSONDecoder().decode([PostProcessingPrompt].self, from: data)
        {
            prompts = decoded
        }

        return (
            UserDefaults.standard.bool(forKey: Keys.meetingTypeAutoDetectEnabled),
            prompts,
            loadURLBookmark(forKey: Keys.summaryExportFolder),
            UserDefaults.standard.string(forKey: Keys.summaryTemplate) ?? defaultSummaryTemplate,
            loadBoolDefaultIfUnset(forKey: Keys.summaryTemplateEnabled, defaultValue: true),
            UserDefaults.standard.bool(forKey: Keys.autoExportSummaries),
            SummaryExportSafetyPolicyLevel(rawValue: UserDefaults.standard.string(forKey: Keys.summaryExportSafetyPolicyLevel) ?? "") ?? .standard,
            loadBoolDefaultIfUnset(forKey: Keys.meetingQnAEnabled, defaultValue: true)
        )
    }

    /// Loads context awareness settings.
    static func loadContextAwarenessSettings(from context: InitializationContext) -> (
        contextAwarenessEnabled: Bool,
        contextAwarenessExplicitActionOnly: Bool,
        contextAwarenessIncludeClipboard: Bool,
        contextAwarenessIncludeWindowOCR: Bool,
        contextAwarenessIncludeAccessibilityText: Bool,
        contextAwarenessProtectSensitiveApps: Bool,
        contextAwarenessRedactSensitiveData: Bool,
        contextAwarenessExcludedBundleIDs: [String]
    ) {
        (
            context.loadedContextAwarenessEnabled,
            loadBoolDefaultIfUnset(forKey: Keys.contextAwarenessExplicitActionOnly, defaultValue: true),
            UserDefaults.standard.bool(forKey: Keys.contextAwarenessIncludeClipboard),
            UserDefaults.standard.bool(forKey: Keys.contextAwarenessIncludeWindowOCR),
            loadBoolDefaultIfUnset(forKey: Keys.contextAwarenessIncludeAccessibilityText, defaultValue: true),
            loadBoolDefaultIfUnset(forKey: Keys.contextAwarenessProtectSensitiveApps, defaultValue: true),
            loadBoolDefaultIfUnset(forKey: Keys.contextAwarenessRedactSensitiveData, defaultValue: true),
            loadDecoded([String].self, forKey: Keys.contextAwarenessExcludedBundleIDs) ?? []
        )
    }

    /// Loads dictation rules and web targets.
    static func loadDictationRulesAndWebTargets() -> (
        markdownTargetBundleIdentifiers: [String],
        dictationAppRules: [DictationAppRule],
        vocabularyReplacementRules: [VocabularyReplacementRule],
        markdownWebTargets: [WebContextTarget],
        webTargetBrowserBundleIdentifiers: [String],
        monitoredMeetingBundleIdentifiers: [String],
        webMeetingTargets: [WebMeetingTarget]
    ) {
        (
            loadDecoded([String].self, forKey: Keys.markdownTargetBundleIdentifiers) ?? defaultMarkdownTargetBundleIdentifiers,
            normalizedDictationAppRules(loadDecoded([DictationAppRule].self, forKey: Keys.dictationAppRules) ?? defaultDictationAppRules),
            normalizedVocabularyReplacementRules(loadDecoded([VocabularyReplacementRule].self, forKey: Keys.vocabularyReplacementRules) ?? []),
            loadDecoded([WebContextTarget].self, forKey: Keys.markdownWebTargets) ?? defaultMarkdownWebTargets,
            loadDecoded([String].self, forKey: Keys.webTargetBrowserBundleIdentifiers) ?? defaultWebTargetBrowserBundleIdentifiers,
            loadDecoded([String].self, forKey: Keys.monitoredMeetingBundleIdentifiers) ?? defaultMonitoredMeetingBundleIdentifiers,
            loadDecoded([WebMeetingTarget].self, forKey: Keys.webMeetingTargets) ?? defaultWebMeetingTargets
        )
    }

    /// Loads UI and indicator settings.
    static func loadUIAndIndicatorSettings() -> (
        assistantBorderColor: AssistantBorderColor,
        assistantBorderStyle: AssistantBorderStyle,
        assistantBorderWidth: Double,
        assistantGlowSize: Double,
        recordingIndicatorEnabled: Bool,
        recordingIndicatorStyle: RecordingIndicatorStyle,
        recordingIndicatorPosition: RecordingIndicatorPosition,
        recordingIndicatorAnimationSpeed: RecordingIndicatorAnimationSpeed,
        autoDeleteTranscriptions: Bool,
        autoDeletePeriodDays: Int,
        appAccentColor: AppThemeColor,
        soundFeedbackEnabled: Bool,
        recordingStartSound: SoundFeedbackSound,
        recordingStopSound: SoundFeedbackSound,
        showInDock: Bool
    ) {
        let rawBorderColor = UserDefaults.standard.string(forKey: Keys.assistantBorderColor)
        let rawBorderStyle = UserDefaults.standard.string(forKey: Keys.assistantBorderStyle)
        let storedBorderWidth = UserDefaults.standard.object(forKey: Keys.assistantBorderWidth) as? NSNumber
        let storedGlowSize = UserDefaults.standard.object(forKey: Keys.assistantGlowSize) as? NSNumber

        let rawIndicatorStyle = UserDefaults.standard.string(forKey: Keys.recordingIndicatorStyle)
        let rawIndicatorPosition = UserDefaults.standard.string(forKey: Keys.recordingIndicatorPosition)
        let rawIndicatorAnimationSpeed = UserDefaults.standard.string(forKey: Keys.recordingIndicatorAnimationSpeed)

        let rawDays = UserDefaults.standard.object(forKey: Keys.autoDeletePeriodDays) as? Int
        let rawAccentColor = UserDefaults.standard.string(forKey: Keys.appAccentColor)

        let rawStartSound = UserDefaults.standard.string(forKey: Keys.recordingStartSound)
        let rawStopSound = UserDefaults.standard.string(forKey: Keys.recordingStopSound)

        return (
            rawBorderColor.flatMap { AssistantBorderColor(rawValue: $0) } ?? .green,
            rawBorderStyle.flatMap { AssistantBorderStyle(rawValue: $0) } ?? .stroke,
            max(1, storedBorderWidth?.doubleValue ?? 8),
            max(0, storedGlowSize?.doubleValue ?? 20),
            loadBoolDefaultIfUnset(forKey: Keys.recordingIndicatorEnabled, defaultValue: true),
            rawIndicatorStyle.flatMap { RecordingIndicatorStyle(rawValue: $0) } ?? .mini,
            rawIndicatorPosition.flatMap { RecordingIndicatorPosition(rawValue: $0) } ?? .bottom,
            rawIndicatorAnimationSpeed.flatMap { RecordingIndicatorAnimationSpeed(rawValue: $0) } ?? .normal,
            UserDefaults.standard.bool(forKey: Keys.autoDeleteTranscriptions),
            rawDays ?? 30,
            rawAccentColor.flatMap { AppThemeColor(rawValue: $0) } ?? .system,
            UserDefaults.standard.bool(forKey: Keys.soundFeedbackEnabled),
            rawStartSound.flatMap { SoundFeedbackSound(rawValue: $0) } ?? .pop,
            rawStopSound.flatMap { SoundFeedbackSound(rawValue: $0) } ?? .glass,
            UserDefaults.standard.bool(forKey: Keys.showInDock)
        )
    }

    /// Resolves shortcut definitions from loaded values or legacy presets.
    static func resolveShortcutDefinitionsValues(
        from context: InitializationContext,
        dictationModifierGesture: ModifierShortcutGesture?,
        assistantModifierGesture: ModifierShortcutGesture?,
        meetingModifierGesture: ModifierShortcutGesture?,
        dictationPresetKey: PresetShortcutKey,
        assistantPresetKey: PresetShortcutKey,
        meetingPresetKey: PresetShortcutKey,
        dictationActivationMode: ShortcutActivationMode,
        assistantActivationMode: ShortcutActivationMode,
        shortcutActivationMode: ShortcutActivationMode
    ) -> (
        dictation: ShortcutDefinition?,
        assistant: ShortcutDefinition?,
        meeting: ShortcutDefinition?
    ) {
        (
            context.loadedDictationShortcutDefinition ?? resolveShortcutDefinition(
                explicitGesture: dictationModifierGesture,
                legacyPresetKey: dictationPresetKey,
                activationMode: dictationActivationMode
            ),
            context.loadedAssistantShortcutDefinition ?? resolveShortcutDefinition(
                explicitGesture: assistantModifierGesture,
                legacyPresetKey: assistantPresetKey,
                activationMode: assistantActivationMode
            ),
            context.loadedMeetingShortcutDefinition ?? resolveShortcutDefinition(
                explicitGesture: meetingModifierGesture,
                legacyPresetKey: meetingPresetKey,
                activationMode: shortcutActivationMode
            )
        )
    }

    /// Finalizes initialization by performing migrations and saving initial state.
    func finalizeInitialization(context: InitializationContext) {
        // Resolve shortcut definitions
        let defs = Self.resolveShortcutDefinitionsValues(
            from: context,
            dictationModifierGesture: dictationModifierShortcutGesture,
            assistantModifierGesture: assistantModifierShortcutGesture,
            meetingModifierGesture: meetingModifierShortcutGesture,
            dictationPresetKey: dictationSelectedPresetKey,
            assistantPresetKey: assistantSelectedPresetKey,
            meetingPresetKey: meetingSelectedPresetKey,
            dictationActivationMode: dictationShortcutActivationMode,
            assistantActivationMode: assistantShortcutActivationMode,
            shortcutActivationMode: shortcutActivationMode
        )
        dictationShortcutDefinition = defs.dictation
        assistantShortcutDefinition = defs.assistant
        meetingShortcutDefinition = defs.meeting

        if contextAwarenessEnabled {
            contextAwarenessIncludeAccessibilityText = true
        }

        let shouldMigrateLegacyAssistantIntegration = context.loadedIntegrations == nil
        if shouldMigrateLegacyAssistantIntegration {
            var migratedRaycast = AssistantIntegrationConfig.defaultRaycast
            migratedRaycast.isEnabled = assistantRaycastEnabled
            migratedRaycast.deepLink = AssistantIntegrationConfig.defaultRaycastDeepLink
            assistantIntegrations = [migratedRaycast]
            assistantSelectedIntegrationId = migratedRaycast.id
        }

        if assistantSelectedIntegrationId == nil {
            assistantSelectedIntegrationId = assistantIntegrations.first?.id
        }

        synchronizeAssistantIntegrationsState()
        save(assistantIntegrations, forKey: Keys.assistantIntegrations)

        if context.loadedDictationShortcutDefinition == nil {
            save(dictationShortcutDefinition, forKey: Keys.dictationShortcutDefinition)
        }
        if context.loadedAssistantShortcutDefinition == nil {
            save(assistantShortcutDefinition, forKey: Keys.assistantShortcutDefinition)
        }
        if context.loadedMeetingShortcutDefinition == nil {
            save(meetingShortcutDefinition, forKey: Keys.meetingShortcutDefinition)
        }

        if let selectedID = assistantSelectedIntegrationId {
            UserDefaults.standard.set(selectedID.uuidString, forKey: Keys.assistantSelectedIntegrationId)
        } else {
            UserDefaults.standard.removeObject(forKey: Keys.assistantSelectedIntegrationId)
        }

        UserDefaults.standard.set(assistantRaycastEnabled, forKey: Keys.assistantRaycastEnabled)
        UserDefaults.standard.set(assistantRaycastDeepLink, forKey: Keys.assistantRaycastDeepLink)

        if context.hasPersistedLegacyPerTargetBrowsers, !context.hasGlobalBrowserSetting {
            migrateWebTargetBrowsersToGlobalSettingIfNeeded()
        }

        migrateLegacyMarkdownTargetsToDictationAppRulesIfNeeded()
        migrateLegacyWebTargetBrowsersToDictationAppRulesIfNeeded()
        backfillEnhancementsSelectionModelsIfNeeded()
        applyLanguage(selectedLanguage)
    }
}
