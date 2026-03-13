import Foundation
import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain

public struct CloudSyncSettingsPayloadV1: Codable, Sendable {
    public let aiConfiguration: AIConfiguration
    public let enhancementsAISelection: EnhancementsAISelection
    public let enhancementsDictationAISelection: EnhancementsAISelection
    public let enhancementsProviderSelectedModels: [String: String]

    public let systemPrompt: String
    public let userPrompts: [PostProcessingPrompt]
    public let dictationPrompts: [PostProcessingPrompt]
    public let meetingPrompts: [PostProcessingPrompt]
    public let deletedPromptIds: Set<UUID>
    public let selectedPromptId: UUID?
    public let dictationSelectedPromptId: UUID?
    public let postProcessingEnabled: Bool
    public let dictationStructuredPostProcessingEnabled: Bool
    public let isDiarizationEnabled: Bool
    public let minSpeakers: Int?
    public let maxSpeakers: Int?
    public let numSpeakers: Int?

    public let audioFormat: AppSettingsStore.AudioFormat
    public let shouldMergeAudioFiles: Bool
    public let selectedLanguage: AppLanguage

    public let shortcutActivationMode: ShortcutActivationMode
    public let dictationShortcutActivationMode: ShortcutActivationMode
    public let shortcutDoubleTapIntervalMilliseconds: Double
    public let useEscapeToCancelRecording: Bool
    public let selectedPresetKey: PresetShortcutKey
    public let dictationSelectedPresetKey: PresetShortcutKey
    public let meetingSelectedPresetKey: PresetShortcutKey
    public let dictationShortcutDefinition: ShortcutDefinition?
    public let assistantShortcutDefinition: ShortcutDefinition?
    public let meetingShortcutDefinition: ShortcutDefinition?
    public let cancelRecordingShortcutDefinition: ShortcutDefinition?
    public let dictationModifierShortcutGesture: ModifierShortcutGesture?
    public let assistantModifierShortcutGesture: ModifierShortcutGesture?
    public let meetingModifierShortcutGesture: ModifierShortcutGesture?

    public let assistantShortcutActivationMode: ShortcutActivationMode
    public let assistantUseEscapeToCancelRecording: Bool
    public let assistantUseEnterToStopRecording: Bool
    public let assistantSelectedPresetKey: PresetShortcutKey
    public let assistantBorderColor: AssistantBorderColor
    public let assistantBorderStyle: AssistantBorderStyle
    public let assistantBorderWidth: Double
    public let assistantGlowSize: Double
    public let assistantIntegrations: [AssistantIntegrationConfig]
    public let assistantSelectedIntegrationId: UUID?
    public let assistantRaycastEnabled: Bool
    public let assistantRaycastDeepLink: String

    public let meetingTypeAutoDetectEnabled: Bool
    public let meetingSummaryOutputLanguage: DictationOutputLanguage
    public let summaryTemplate: String
    public let summaryTemplateEnabled: Bool
    public let autoExportSummaries: Bool
    public let summaryExportSafetyPolicyLevel: SummaryExportSafetyPolicyLevel
    public let meetingNotesFontFamilyKey: String
    public let meetingNotesFontSize: Double
    public let meetingQnAEnabled: Bool

    public let contextAwarenessEnabled: Bool
    public let contextAwarenessExplicitActionOnly: Bool
    public let contextAwarenessIncludeClipboard: Bool
    public let contextAwarenessIncludeWindowOCR: Bool
    public let contextAwarenessIncludeAccessibilityText: Bool
    public let contextAwarenessProtectSensitiveApps: Bool
    public let contextAwarenessRedactSensitiveData: Bool
    public let contextAwarenessExcludedBundleIDs: [String]

    public let markdownTargetBundleIdentifiers: [String]
    public let dictationAppRules: [DictationAppRule]
    public let vocabularyReplacementRules: [VocabularyReplacementRule]
    public let markdownWebTargets: [WebContextTarget]
    public let webTargetBrowserBundleIdentifiers: [String]
    public let monitoredMeetingBundleIdentifiers: [String]
    public let webMeetingTargets: [WebMeetingTarget]
    public let ignoredCalendarEventIdentifiers: Set<String>

    public let recordingIndicatorEnabled: Bool
    public let recordingIndicatorStyle: RecordingIndicatorStyle
    public let recordingIndicatorPosition: RecordingIndicatorPosition
    public let recordingIndicatorAnimationSpeed: RecordingIndicatorAnimationSpeed
    public let autoDeleteTranscriptions: Bool
    public let autoDeletePeriodDays: Int
    public let appAccentColor: AppThemeColor
    public let soundFeedbackEnabled: Bool
    public let recordingStartSound: SoundFeedbackSound
    public let recordingStopSound: SoundFeedbackSound
    public let showInDock: Bool

    public let autoStartRecording: Bool
    public let showSettingsOnLaunch: Bool
    public let autoCopyTranscriptionToClipboard: Bool
    public let autoPasteTranscriptionToActiveApp: Bool
    public let launchAtLogin: Bool
}

extension AppSettingsStore {
    public func exportCloudSnapshotV1() -> CloudSyncSettingsSnapshotV1 {
        let payload = makeCloudSyncPayloadV1()
        let payloadJSON = Self.encodeCloudPayload(payload)
        let deviceID = CloudSyncDeviceIdentity.current()
        let nowMillis = Int64(Date().timeIntervalSince1970 * 1_000.0)

        return CloudSyncSettingsSnapshotV1(
            payloadJSON: payloadJSON,
            updatedAtMillis: nowMillis,
            sourceDeviceID: deviceID
        )
    }

    public func applyCloudSnapshotV1(_ snapshot: CloudSyncSettingsSnapshotV1, source: CloudSyncSource) {
        _ = source

        guard let payload = Self.decodeCloudPayload(snapshot.payloadJSON) else {
            AppLogger.error(
                "Failed to decode cloud settings payload",
                category: .storage,
                extra: ["schemaVersion": snapshot.schemaVersion]
            )
            return
        }

        isApplyingCloudSnapshot = true
        defer { isApplyingCloudSnapshot = false }

        aiConfiguration = payload.aiConfiguration
        enhancementsAISelection = payload.enhancementsAISelection
        enhancementsDictationAISelection = payload.enhancementsDictationAISelection
        enhancementsProviderSelectedModels = payload.enhancementsProviderSelectedModels

        systemPrompt = payload.systemPrompt
        userPrompts = payload.userPrompts
        dictationPrompts = payload.dictationPrompts
        meetingPrompts = payload.meetingPrompts
        deletedPromptIds = payload.deletedPromptIds
        selectedPromptId = payload.selectedPromptId
        dictationSelectedPromptId = payload.dictationSelectedPromptId
        postProcessingEnabled = payload.postProcessingEnabled
        dictationStructuredPostProcessingEnabled = payload.dictationStructuredPostProcessingEnabled
        isDiarizationEnabled = payload.isDiarizationEnabled
        minSpeakers = payload.minSpeakers
        maxSpeakers = payload.maxSpeakers
        numSpeakers = payload.numSpeakers

        audioFormat = payload.audioFormat
        shouldMergeAudioFiles = payload.shouldMergeAudioFiles
        selectedLanguage = payload.selectedLanguage

        shortcutActivationMode = payload.shortcutActivationMode
        dictationShortcutActivationMode = payload.dictationShortcutActivationMode
        shortcutDoubleTapIntervalMilliseconds = payload.shortcutDoubleTapIntervalMilliseconds
        useEscapeToCancelRecording = payload.useEscapeToCancelRecording
        selectedPresetKey = payload.selectedPresetKey
        dictationSelectedPresetKey = payload.dictationSelectedPresetKey
        meetingSelectedPresetKey = payload.meetingSelectedPresetKey
        dictationShortcutDefinition = payload.dictationShortcutDefinition
        assistantShortcutDefinition = payload.assistantShortcutDefinition
        meetingShortcutDefinition = payload.meetingShortcutDefinition
        cancelRecordingShortcutDefinition = payload.cancelRecordingShortcutDefinition
        dictationModifierShortcutGesture = payload.dictationModifierShortcutGesture
        assistantModifierShortcutGesture = payload.assistantModifierShortcutGesture
        meetingModifierShortcutGesture = payload.meetingModifierShortcutGesture

        assistantShortcutActivationMode = payload.assistantShortcutActivationMode
        assistantUseEscapeToCancelRecording = payload.assistantUseEscapeToCancelRecording
        assistantUseEnterToStopRecording = payload.assistantUseEnterToStopRecording
        assistantSelectedPresetKey = payload.assistantSelectedPresetKey
        assistantBorderColor = payload.assistantBorderColor
        assistantBorderStyle = payload.assistantBorderStyle
        assistantBorderWidth = payload.assistantBorderWidth
        assistantGlowSize = payload.assistantGlowSize
        assistantIntegrations = payload.assistantIntegrations
        assistantSelectedIntegrationId = payload.assistantSelectedIntegrationId
        assistantRaycastEnabled = payload.assistantRaycastEnabled
        assistantRaycastDeepLink = payload.assistantRaycastDeepLink

        meetingTypeAutoDetectEnabled = payload.meetingTypeAutoDetectEnabled
        meetingSummaryOutputLanguage = payload.meetingSummaryOutputLanguage
        summaryTemplate = payload.summaryTemplate
        summaryTemplateEnabled = payload.summaryTemplateEnabled
        autoExportSummaries = payload.autoExportSummaries
        summaryExportSafetyPolicyLevel = payload.summaryExportSafetyPolicyLevel
        meetingNotesFontFamilyKey = payload.meetingNotesFontFamilyKey
        meetingNotesFontSize = payload.meetingNotesFontSize
        meetingQnAEnabled = payload.meetingQnAEnabled

        contextAwarenessEnabled = payload.contextAwarenessEnabled
        contextAwarenessExplicitActionOnly = payload.contextAwarenessExplicitActionOnly
        contextAwarenessIncludeClipboard = payload.contextAwarenessIncludeClipboard
        contextAwarenessIncludeWindowOCR = payload.contextAwarenessIncludeWindowOCR
        contextAwarenessIncludeAccessibilityText = payload.contextAwarenessIncludeAccessibilityText
        contextAwarenessProtectSensitiveApps = payload.contextAwarenessProtectSensitiveApps
        contextAwarenessRedactSensitiveData = payload.contextAwarenessRedactSensitiveData
        contextAwarenessExcludedBundleIDs = payload.contextAwarenessExcludedBundleIDs

        markdownTargetBundleIdentifiers = payload.markdownTargetBundleIdentifiers
        dictationAppRules = payload.dictationAppRules
        vocabularyReplacementRules = payload.vocabularyReplacementRules
        markdownWebTargets = payload.markdownWebTargets
        webTargetBrowserBundleIdentifiers = payload.webTargetBrowserBundleIdentifiers
        monitoredMeetingBundleIdentifiers = payload.monitoredMeetingBundleIdentifiers
        webMeetingTargets = payload.webMeetingTargets
        save(payload.ignoredCalendarEventIdentifiers, forKey: Keys.ignoredCalendarEventIdentifiers)

        recordingIndicatorEnabled = payload.recordingIndicatorEnabled
        recordingIndicatorStyle = payload.recordingIndicatorStyle
        recordingIndicatorPosition = payload.recordingIndicatorPosition
        recordingIndicatorAnimationSpeed = payload.recordingIndicatorAnimationSpeed
        autoDeleteTranscriptions = payload.autoDeleteTranscriptions
        autoDeletePeriodDays = payload.autoDeletePeriodDays
        appAccentColor = payload.appAccentColor
        soundFeedbackEnabled = payload.soundFeedbackEnabled
        recordingStartSound = payload.recordingStartSound
        recordingStopSound = payload.recordingStopSound
        showInDock = payload.showInDock

        autoStartRecording = payload.autoStartRecording
        showSettingsOnLaunch = payload.showSettingsOnLaunch
        autoCopyTranscriptionToClipboard = payload.autoCopyTranscriptionToClipboard
        autoPasteTranscriptionToActiveApp = payload.autoPasteTranscriptionToActiveApp
        launchAtLogin = payload.launchAtLogin
    }

    private func makeCloudSyncPayloadV1() -> CloudSyncSettingsPayloadV1 {
        CloudSyncSettingsPayloadV1(
            aiConfiguration: aiConfiguration,
            enhancementsAISelection: enhancementsAISelection,
            enhancementsDictationAISelection: enhancementsDictationAISelection,
            enhancementsProviderSelectedModels: enhancementsProviderSelectedModels,
            systemPrompt: systemPrompt,
            userPrompts: userPrompts,
            dictationPrompts: dictationPrompts,
            meetingPrompts: meetingPrompts,
            deletedPromptIds: deletedPromptIds,
            selectedPromptId: selectedPromptId,
            dictationSelectedPromptId: dictationSelectedPromptId,
            postProcessingEnabled: postProcessingEnabled,
            dictationStructuredPostProcessingEnabled: dictationStructuredPostProcessingEnabled,
            isDiarizationEnabled: isDiarizationEnabled,
            minSpeakers: minSpeakers,
            maxSpeakers: maxSpeakers,
            numSpeakers: numSpeakers,
            audioFormat: audioFormat,
            shouldMergeAudioFiles: shouldMergeAudioFiles,
            selectedLanguage: selectedLanguage,
            shortcutActivationMode: shortcutActivationMode,
            dictationShortcutActivationMode: dictationShortcutActivationMode,
            shortcutDoubleTapIntervalMilliseconds: shortcutDoubleTapIntervalMilliseconds,
            useEscapeToCancelRecording: useEscapeToCancelRecording,
            selectedPresetKey: selectedPresetKey,
            dictationSelectedPresetKey: dictationSelectedPresetKey,
            meetingSelectedPresetKey: meetingSelectedPresetKey,
            dictationShortcutDefinition: dictationShortcutDefinition,
            assistantShortcutDefinition: assistantShortcutDefinition,
            meetingShortcutDefinition: meetingShortcutDefinition,
            cancelRecordingShortcutDefinition: cancelRecordingShortcutDefinition,
            dictationModifierShortcutGesture: dictationModifierShortcutGesture,
            assistantModifierShortcutGesture: assistantModifierShortcutGesture,
            meetingModifierShortcutGesture: meetingModifierShortcutGesture,
            assistantShortcutActivationMode: assistantShortcutActivationMode,
            assistantUseEscapeToCancelRecording: assistantUseEscapeToCancelRecording,
            assistantUseEnterToStopRecording: assistantUseEnterToStopRecording,
            assistantSelectedPresetKey: assistantSelectedPresetKey,
            assistantBorderColor: assistantBorderColor,
            assistantBorderStyle: assistantBorderStyle,
            assistantBorderWidth: assistantBorderWidth,
            assistantGlowSize: assistantGlowSize,
            assistantIntegrations: assistantIntegrations,
            assistantSelectedIntegrationId: assistantSelectedIntegrationId,
            assistantRaycastEnabled: assistantRaycastEnabled,
            assistantRaycastDeepLink: assistantRaycastDeepLink,
            meetingTypeAutoDetectEnabled: meetingTypeAutoDetectEnabled,
            meetingSummaryOutputLanguage: meetingSummaryOutputLanguage,
            summaryTemplate: summaryTemplate,
            summaryTemplateEnabled: summaryTemplateEnabled,
            autoExportSummaries: autoExportSummaries,
            summaryExportSafetyPolicyLevel: summaryExportSafetyPolicyLevel,
            meetingNotesFontFamilyKey: meetingNotesFontFamilyKey,
            meetingNotesFontSize: meetingNotesFontSize,
            meetingQnAEnabled: meetingQnAEnabled,
            contextAwarenessEnabled: contextAwarenessEnabled,
            contextAwarenessExplicitActionOnly: contextAwarenessExplicitActionOnly,
            contextAwarenessIncludeClipboard: contextAwarenessIncludeClipboard,
            contextAwarenessIncludeWindowOCR: contextAwarenessIncludeWindowOCR,
            contextAwarenessIncludeAccessibilityText: contextAwarenessIncludeAccessibilityText,
            contextAwarenessProtectSensitiveApps: contextAwarenessProtectSensitiveApps,
            contextAwarenessRedactSensitiveData: contextAwarenessRedactSensitiveData,
            contextAwarenessExcludedBundleIDs: contextAwarenessExcludedBundleIDs,
            markdownTargetBundleIdentifiers: markdownTargetBundleIdentifiers,
            dictationAppRules: dictationAppRules,
            vocabularyReplacementRules: vocabularyReplacementRules,
            markdownWebTargets: markdownWebTargets,
            webTargetBrowserBundleIdentifiers: webTargetBrowserBundleIdentifiers,
            monitoredMeetingBundleIdentifiers: monitoredMeetingBundleIdentifiers,
            webMeetingTargets: webMeetingTargets,
            ignoredCalendarEventIdentifiers: ignoredCalendarEventIdentifiers(),
            recordingIndicatorEnabled: recordingIndicatorEnabled,
            recordingIndicatorStyle: recordingIndicatorStyle,
            recordingIndicatorPosition: recordingIndicatorPosition,
            recordingIndicatorAnimationSpeed: recordingIndicatorAnimationSpeed,
            autoDeleteTranscriptions: autoDeleteTranscriptions,
            autoDeletePeriodDays: autoDeletePeriodDays,
            appAccentColor: appAccentColor,
            soundFeedbackEnabled: soundFeedbackEnabled,
            recordingStartSound: recordingStartSound,
            recordingStopSound: recordingStopSound,
            showInDock: showInDock,
            autoStartRecording: autoStartRecording,
            showSettingsOnLaunch: showSettingsOnLaunch,
            autoCopyTranscriptionToClipboard: autoCopyTranscriptionToClipboard,
            autoPasteTranscriptionToActiveApp: autoPasteTranscriptionToActiveApp,
            launchAtLogin: launchAtLogin
        )
    }

    private static func encodeCloudPayload(_ payload: CloudSyncSettingsPayloadV1) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(payload)) ?? Data()
    }

    private static func decodeCloudPayload(_ data: Data) -> CloudSyncSettingsPayloadV1? {
        guard !data.isEmpty else { return nil }
        return try? JSONDecoder().decode(CloudSyncSettingsPayloadV1.self, from: data)
    }
}
