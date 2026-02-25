import Foundation
import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain

// MARK: - Computed Properties

extension AppSettingsStore {
    /// Indicates whether the Markdown targets list has been explicitly configured.
    public var hasConfiguredMarkdownTargets: Bool {
        UserDefaults.standard.object(forKey: Keys.markdownTargetBundleIdentifiers) != nil
    }

    /// Indicates whether the per-app dictation rules list has been explicitly configured.
    public var hasConfiguredDictationAppRules: Bool {
        UserDefaults.standard.object(forKey: Keys.dictationAppRules) != nil
    }

    /// Indicates whether Markdown web targets have been explicitly configured.
    public var hasConfiguredMarkdownWebTargets: Bool {
        UserDefaults.standard.object(forKey: Keys.markdownWebTargets) != nil
    }

    /// Indicates whether the global web target browsers list has been explicitly configured.
    public var hasConfiguredWebTargetBrowsers: Bool {
        UserDefaults.standard.object(forKey: Keys.webTargetBrowserBundleIdentifiers) != nil
    }

    /// Indicates whether the monitored meetings list has been explicitly configured.
    public var hasConfiguredMonitoredMeetingApps: Bool {
        UserDefaults.standard.object(forKey: Keys.monitoredMeetingBundleIdentifiers) != nil
    }

    /// Indicates whether web meeting targets have been explicitly configured.
    public var hasConfiguredWebMeetingTargets: Bool {
        UserDefaults.standard.object(forKey: Keys.webMeetingTargets) != nil
    }

    /// All available prompts (predefined + user-created), filtered by deleted and overrides.
    public var allPrompts: [PostProcessingPrompt] {
        deduplicatedPrompts(dictationAvailablePrompts + meetingAvailablePrompts)
    }

    /// Dictation prompts (predefined + user-created).
    public var dictationAvailablePrompts: [PostProcessingPrompt] {
        let predefined: [PostProcessingPrompt] = [
            .cleanTranscription,
            .flex,
        ]
        let predefinedIds = Set(predefined.map(\.id))
        let custom = dictationPrompts + userPrompts.filter { predefinedIds.contains($0.id) }
        return mergedPrompts(predefined: predefined, custom: custom)
    }

    /// Meeting prompts (predefined + user-created).
    public var meetingAvailablePrompts: [PostProcessingPrompt] {
        let predefined: [PostProcessingPrompt] = [
            .standup,
            .presentation,
            .designReview,
            .oneOnOne,
            .planning,
        ]

        // Backward-compat: prompts created in older versions lived under `userPrompts`.
        // Clean Transcription is dictation-only, so keep it out of meeting prompts.
        let custom = (meetingPrompts + userPrompts)
            .filter { $0.id != PostProcessingPrompt.cleanTranscription.id }
        return mergedPrompts(predefined: predefined, custom: custom)
    }

    /// Currently selected prompt.
    public var selectedPrompt: PostProcessingPrompt? {
        guard let id = selectedPromptId, id != Self.noPostProcessingPromptId else { return nil }
        return meetingAvailablePrompts.first { $0.id == id }
    }

    /// Currently selected dictation prompt.
    public var selectedDictationPrompt: PostProcessingPrompt? {
        guard let id = dictationSelectedPromptId, id != Self.noPostProcessingPromptId else { return nil }
        return dictationAvailablePrompts.first { $0.id == id }
    }

    public var isMeetingPostProcessingDisabled: Bool {
        selectedPromptId == Self.noPostProcessingPromptId
    }

    public var isDictationPostProcessingDisabled: Bool {
        dictationSelectedPromptId == Self.noPostProcessingPromptId
    }

    /// Browser bundle identifiers currently in effect for web target matching.
    public var effectiveWebTargetBrowserBundleIdentifiers: [String] {
        synchronizedWebTargetBrowsers(
            from: dictationAppRules,
            legacyBrowsers: webTargetBrowserBundleIdentifiers
        )
    }

    /// Whether the shared intelligence kernel is globally enabled.
    public var intelligenceKernelEnabled: Bool {
        FeatureFlags.enableIntelligenceKernel
    }

    /// Returns whether a specific intelligence-kernel mode is enabled.
    public func isIntelligenceKernelModeEnabled(_ mode: IntelligenceKernelMode) -> Bool {
        guard intelligenceKernelEnabled else { return false }

        switch mode {
        case .meeting:
            return FeatureFlags.enableMeetingIntelligenceMode
        case .dictation:
            return FeatureFlags.enableDictationIntelligenceMode
        case .assistant:
            return FeatureFlags.enableAssistantIntelligenceMode
        }
    }
}
