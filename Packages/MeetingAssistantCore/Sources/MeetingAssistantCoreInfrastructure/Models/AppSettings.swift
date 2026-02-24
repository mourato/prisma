import AppKit
import Foundation
import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain
import SwiftUI

// MARK: - App Settings Store

/// Centralized settings manager using UserDefaults.
@MainActor
public class AppSettingsStore: ObservableObject {
    public static let shared = AppSettingsStore()

    /// Sentinel UUID used to represent an explicit "No post-processing" selection.
    /// This avoids changing persisted schemas while still allowing an opt-out choice.
    public static let noPostProcessingPromptId: UUID = {
        guard let uuid = UUID(uuidString: "00000000-0000-0000-0000-000000000001") else {
            assertionFailure("Invalid UUID string for noPostProcessingPromptId")
            return UUID()
        }
        return uuid
    }()

    var isSynchronizingAssistantIntegrations = false

    /// Default list of apps that should force Markdown formatting for dictation.
    public static let defaultMarkdownTargetBundleIdentifiers: [String] = [
        "abnerworks.Typora",
        "com.microsoft.VSCode",
        "com.uranusjr.macdown",
        "md.obsidian",
        "net.shinyfrog.bear",
    ]

    /// Default per-app dictation rules.
    public static let defaultDictationAppRules: [DictationAppRule] = defaultMarkdownTargetBundleIdentifiers.map {
        DictationAppRule(bundleIdentifier: $0, forceMarkdownOutput: true, outputLanguage: .original)
    }

    /// Default list of websites that should force Markdown formatting for dictation.
    public static let defaultMarkdownWebTargets: [WebContextTarget] = []

    /// Default list of browsers used for web target matching.
    public static let defaultWebTargetBrowserBundleIdentifiers: [String] = [
        "com.apple.Safari",
        "com.google.Chrome",
        "com.microsoft.edgemac",
    ]

    /// Default list of apps monitored to start/stop meeting recordings.
    public static let defaultMonitoredMeetingBundleIdentifiers: [String] = [
        "com.apple.Safari",
        "com.google.Chrome",
        "com.microsoft.edgemac",
        "com.microsoft.teams",
        "com.microsoft.teams2",
        "com.hnc.Discord",
        "com.tinyspeck.slackmacgap",
        "net.whatsapp.WhatsApp",
        "us.zoom.xos",
    ]

    /// Default list of web meeting targets detected via browser URL matching.
    public static let defaultWebMeetingTargets: [WebMeetingTarget] = [
        WebMeetingTarget(
            app: .googleMeet,
            displayName: "Google Meet",
            urlPatterns: ["meet.google.com"],
            browserBundleIdentifiers: ["com.apple.Safari", "com.google.Chrome", "com.microsoft.edgemac"]
        ),
        WebMeetingTarget(
            app: .microsoftTeams,
            displayName: "Microsoft Teams",
            urlPatterns: ["teams.microsoft.com"],
            browserBundleIdentifiers: ["com.apple.Safari", "com.google.Chrome", "com.microsoft.edgemac"]
        ),
        WebMeetingTarget(
            app: .zoom,
            displayName: "Zoom",
            urlPatterns: ["zoom.us/j", "zoom.us/wc"],
            browserBundleIdentifiers: ["com.apple.Safari", "com.google.Chrome", "com.microsoft.edgemac"]
        ),
    ]

    public static let defaultShortcutDoubleTapIntervalMilliseconds: Double = 350
    public static let shortcutDoubleTapIntervalRangeMilliseconds: ClosedRange<Double> = 150...1_000

    // MARK: - Keys

    enum Keys {
        static let aiConfiguration = "aiConfiguration"
        static let enhancementsAISelection = "enhancementsAISelection"
        static let enhancementsDictationAISelection = "enhancementsDictationAISelection"
        static let enhancementsProviderSelectedModels = "enhancementsProviderSelectedModels"
        static let systemPrompt = "postProcessingSystemPrompt"
        static let userPrompts = "postProcessingUserPrompts"
        static let selectedPromptId = "postProcessingSelectedPromptId"
        static let dictationPrompts = "dictationPrompts"
        static let dictationSelectedPromptId = "dictationSelectedPromptId"
        static let postProcessingEnabled = "postProcessingEnabled"
        static let dictationStructuredPostProcessingEnabled = "dictationStructuredPostProcessingEnabled"
        static let isDiarizationEnabled = "isDiarizationEnabled"
        static let minSpeakers = "minSpeakers"
        static let maxSpeakers = "maxSpeakers"
        static let numSpeakers = "numSpeakers"
        static let selectedLanguage = "selectedLanguage"
        static let audioDevicePriority = "audioDevicePriority"
        static let useSystemDefaultInput = "useSystemDefaultInput"
        static let muteOutputDuringRecording = "muteOutputDuringRecording"
        static let autoIncreaseMicrophoneVolume = "autoIncreaseMicrophoneVolume"
        static let deletedPromptIds = "postProcessingDeletedPromptIds"
        static let shortcutActivationMode = "shortcutActivationMode"
        static let dictationShortcutActivationMode = "dictationShortcutActivationMode"
        static let shortcutDoubleTapIntervalMilliseconds = "shortcutDoubleTapIntervalMilliseconds"
        static let useEscapeToCancelRecording = "useEscapeToCancelRecording"
        static let selectedPresetKey = "selectedPresetKey"
        static let dictationSelectedPresetKey = "dictationSelectedPresetKey"
        static let meetingSelectedPresetKey = "meetingSelectedPresetKey"
        static let dictationShortcutDefinition = "dictationShortcutDefinition"
        static let assistantShortcutDefinition = "assistantShortcutDefinition"
        static let meetingShortcutDefinition = "meetingShortcutDefinition"
        static let dictationModifierShortcutGesture = "dictationModifierShortcutGesture"
        static let assistantModifierShortcutGesture = "assistantModifierShortcutGesture"
        static let meetingModifierShortcutGesture = "meetingModifierShortcutGesture"
        static let assistantShortcutActivationMode = "assistantShortcutActivationMode"
        static let assistantUseEscapeToCancelRecording = "assistantUseEscapeToCancelRecording"
        static let assistantUseEnterToStopRecording = "assistantUseEnterToStopRecording"
        static let assistantSelectedPresetKey = "assistantSelectedPresetKey"
        static let assistantLayerShortcutKey = "assistantLayerShortcutKey"
        static let assistantBorderColor = "assistantBorderColor"
        static let assistantBorderStyle = "assistantBorderStyle"
        static let assistantBorderWidth = "assistantBorderWidth"
        static let assistantGlowSize = "assistantGlowSize"
        static let assistantIntegrations = "assistantIntegrations"
        static let assistantSelectedIntegrationId = "assistantSelectedIntegrationId"
        static let assistantRaycastEnabled = "assistantRaycastEnabled"
        static let assistantRaycastDeepLink = "assistantRaycastDeepLink"
        static let recordingIndicatorEnabled = "recordingIndicatorEnabled"
        static let recordingIndicatorStyle = "recordingIndicatorStyle"
        static let recordingIndicatorPosition = "recordingIndicatorPosition"
        static let recordingIndicatorAnimationSpeed = "recordingIndicatorAnimationSpeed"
        static let autoDeleteTranscriptions = "autoDeleteTranscriptions"
        static let autoDeletePeriodDays = "autoDeletePeriodDays"
        static let appAccentColor = "appAccentColor"
        // Sound Feedback
        static let soundFeedbackEnabled = "soundFeedbackEnabled"
        static let recordingStartSound = "recordingStartSound"
        static let recordingStopSound = "recordingStopSound"
        /// App Visibility
        static let showInDock = "showInDock"

        // MARK: - Meeting Summary Configuration

        static let meetingTypeAutoDetectEnabled = "meetingTypeAutoDetectEnabled"
        static let meetingPrompts = "meetingPrompts"
        static let summaryExportFolder = "summaryExportFolder"
        static let summaryTemplate = "summaryTemplate"
        static let summaryTemplateEnabled = "summaryTemplateEnabled"
        static let autoExportSummaries = "autoExportSummaries"
        static let summaryExportSafetyPolicyLevel = "summaryExportSafetyPolicyLevel"
        static let meetingQnAEnabled = "meetingQnAEnabled"
        static let contextAwarenessEnabled = "contextAwarenessEnabled"
        static let contextAwarenessExplicitActionOnly = "contextAwarenessExplicitActionOnly"
        static let contextAwarenessIncludeClipboard = "contextAwarenessIncludeClipboard"
        static let contextAwarenessIncludeWindowOCR = "contextAwarenessIncludeWindowOCR"
        static let contextAwarenessIncludeAccessibilityText = "contextAwarenessIncludeAccessibilityText"
        static let contextAwarenessProtectSensitiveApps = "contextAwarenessProtectSensitiveApps"
        static let contextAwarenessRedactSensitiveData = "contextAwarenessRedactSensitiveData"
        static let contextAwarenessExcludedBundleIDs = "contextAwarenessExcludedBundleIDs"
        static let markdownTargetBundleIdentifiers = "markdownTargetBundleIdentifiers"
        static let dictationAppRules = "dictationAppRules"
        static let vocabularyReplacementRules = "vocabularyReplacementRules"
        static let markdownWebTargets = "markdownWebTargets"
        static let webTargetBrowserBundleIdentifiers = "webTargetBrowserBundleIdentifiers"
        static let monitoredMeetingBundleIdentifiers = "monitoredMeetingBundleIdentifiers"
        static let webMeetingTargets = "webMeetingTargets"
    }

    // MARK: - Published Properties

    @Published public var aiConfiguration: AIConfiguration {
        didSet { save(aiConfiguration, forKey: Keys.aiConfiguration) }
    }

    /// Provider/model selection for meeting intelligence features.
    @Published public var enhancementsAISelection: EnhancementsAISelection {
        didSet { save(enhancementsAISelection, forKey: Keys.enhancementsAISelection) }
    }

    /// Provider/model selection for dictation intelligence features.
    /// Assistant mode reuses this selection automatically.
    @Published public var enhancementsDictationAISelection: EnhancementsAISelection {
        didSet { save(enhancementsDictationAISelection, forKey: Keys.enhancementsDictationAISelection) }
    }

    /// Per-provider model selection used by provider cards in Enhancements setup.
    /// Keys are `AIProvider.rawValue`.
    @Published public var enhancementsProviderSelectedModels: [String: String] {
        didSet { save(enhancementsProviderSelectedModels, forKey: Keys.enhancementsProviderSelectedModels) }
    }

    // MARK: - Post-Processing Properties

    /// Custom system prompt for post-processing.
    @Published public var systemPrompt: String {
        didSet { UserDefaults.standard.set(systemPrompt, forKey: Keys.systemPrompt) }
    }

    /// User-created prompts for post-processing.
    @Published public var userPrompts: [PostProcessingPrompt] {
        didSet { save(userPrompts, forKey: Keys.userPrompts) }
    }

    /// Predefined prompt IDs that the user has explicitly deleted.
    @Published public var deletedPromptIds: Set<UUID> {
        didSet { save(deletedPromptIds, forKey: Keys.deletedPromptIds) }
    }

    /// Currently selected prompt ID for post-processing.
    @Published public var selectedPromptId: UUID? {
        didSet {
            if let id = selectedPromptId {
                UserDefaults.standard.set(id.uuidString, forKey: Keys.selectedPromptId)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.selectedPromptId)
            }
        }
    }

    /// User-created prompts specifically for dictation.
    @Published public var dictationPrompts: [PostProcessingPrompt] {
        didSet { save(dictationPrompts, forKey: Keys.dictationPrompts) }
    }

    /// User-created prompts specifically for meetings.
    @Published public var meetingPrompts: [PostProcessingPrompt] {
        didSet { save(meetingPrompts, forKey: Keys.meetingPrompts) }
    }

    /// Selected prompt ID for dictation post-processing.
    @Published public var dictationSelectedPromptId: UUID? {
        didSet {
            if let id = dictationSelectedPromptId {
                UserDefaults.standard.set(id.uuidString, forKey: Keys.dictationSelectedPromptId)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.dictationSelectedPromptId)
            }
        }
    }

    /// Whether post-processing is enabled.
    @Published public var postProcessingEnabled: Bool {
        didSet {
            UserDefaults.standard.set(postProcessingEnabled, forKey: Keys.postProcessingEnabled)
        }
    }

    /// Whether dictation should use the structured JSON post-processing pipeline.
    /// Default: false (fast direct pipeline).
    @Published public var dictationStructuredPostProcessingEnabled: Bool {
        didSet {
            UserDefaults.standard.set(
                dictationStructuredPostProcessingEnabled,
                forKey: Keys.dictationStructuredPostProcessingEnabled
            )
        }
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

    /// Whether speaker diarization is enabled.
    @Published public var isDiarizationEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isDiarizationEnabled, forKey: Keys.isDiarizationEnabled)
        }
    }

    /// Minimum number of speakers for diarization.
    @Published public var minSpeakers: Int? {
        didSet {
            UserDefaults.standard.set(minSpeakers, forKey: Keys.minSpeakers)
        }
    }

    /// Maximum number of speakers for diarization.
    @Published public var maxSpeakers: Int? {
        didSet {
            UserDefaults.standard.set(maxSpeakers, forKey: Keys.maxSpeakers)
        }
    }

    /// Fixed number of speakers for diarization.
    @Published public var numSpeakers: Int? {
        didSet {
            UserDefaults.standard.set(numSpeakers, forKey: Keys.numSpeakers)
        }
    }

    /// Selected audio format for recordings.
    @Published public var audioFormat: AudioFormat {
        didSet {
            UserDefaults.standard.set(audioFormat.rawValue, forKey: PostProcessingKeys.audioFormat)
        }
    }

    /// Whether to merge audio files after recording.
    /// Default: true
    @Published public var shouldMergeAudioFiles: Bool {
        didSet {
            UserDefaults.standard.set(shouldMergeAudioFiles, forKey: PostProcessingKeys.shouldMergeAudioFiles)
        }
    }

    /// Selected app language.
    @Published public var selectedLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(selectedLanguage.rawValue, forKey: Keys.selectedLanguage)
            applyLanguage(selectedLanguage)
        }
    }

    /// Ordered list of audio device UIDs by priority.
    @Published public var audioDevicePriority: [String] {
        didSet { save(audioDevicePriority, forKey: Keys.audioDevicePriority) }
    }

    /// Whether to use the system default input device instead of a custom priority list.
    @Published public var useSystemDefaultInput: Bool {
        didSet { UserDefaults.standard.set(useSystemDefaultInput, forKey: Keys.useSystemDefaultInput) }
    }

    /// Whether to mute system audio output while recording is in progress.
    @Published public var muteOutputDuringRecording: Bool {
        didSet { UserDefaults.standard.set(muteOutputDuringRecording, forKey: Keys.muteOutputDuringRecording) }
    }

    /// Whether to set the default microphone input volume to maximum when recording starts.
    @Published public var autoIncreaseMicrophoneVolume: Bool {
        didSet { UserDefaults.standard.set(autoIncreaseMicrophoneVolume, forKey: Keys.autoIncreaseMicrophoneVolume) }
    }

    /// How keyboard shortcuts activate recording.
    @Published public var shortcutActivationMode: ShortcutActivationMode {
        didSet { UserDefaults.standard.set(shortcutActivationMode.rawValue, forKey: Keys.shortcutActivationMode) }
    }

    /// How keyboard shortcuts activate Dictation.
    @Published public var dictationShortcutActivationMode: ShortcutActivationMode {
        didSet { UserDefaults.standard.set(dictationShortcutActivationMode.rawValue, forKey: Keys.dictationShortcutActivationMode) }
    }

    /// Double-tap window applied globally to all shortcut handlers.
    @Published public var shortcutDoubleTapIntervalMilliseconds: Double {
        didSet {
            UserDefaults.standard.set(
                shortcutDoubleTapIntervalMilliseconds,
                forKey: Keys.shortcutDoubleTapIntervalMilliseconds
            )
        }
    }

    /// Whether pressing Escape cancels recording.
    @Published public var useEscapeToCancelRecording: Bool {
        didSet { UserDefaults.standard.set(useEscapeToCancelRecording, forKey: Keys.useEscapeToCancelRecording) }
    }

    /// Selected preset shortcut key for recording activation.
    @Published public var selectedPresetKey: PresetShortcutKey {
        didSet { UserDefaults.standard.set(selectedPresetKey.rawValue, forKey: Keys.selectedPresetKey) }
    }

    /// Selected preset shortcut key for Dictation activation.
    @Published public var dictationSelectedPresetKey: PresetShortcutKey {
        didSet { UserDefaults.standard.set(dictationSelectedPresetKey.rawValue, forKey: Keys.dictationSelectedPresetKey) }
    }

    /// Selected preset shortcut key for Meetings activation.
    @Published public var meetingSelectedPresetKey: PresetShortcutKey {
        didSet { UserDefaults.standard.set(meetingSelectedPresetKey.rawValue, forKey: Keys.meetingSelectedPresetKey) }
    }

    /// Canonical in-house shortcut definition for Dictation.
    @Published public var dictationShortcutDefinition: ShortcutDefinition? = nil {
        didSet { save(dictationShortcutDefinition, forKey: Keys.dictationShortcutDefinition) }
    }

    /// Canonical in-house shortcut definition for Assistant.
    @Published public var assistantShortcutDefinition: ShortcutDefinition? = nil {
        didSet { save(assistantShortcutDefinition, forKey: Keys.assistantShortcutDefinition) }
    }

    /// Canonical in-house shortcut definition for Meetings.
    @Published public var meetingShortcutDefinition: ShortcutDefinition? = nil {
        didSet { save(meetingShortcutDefinition, forKey: Keys.meetingShortcutDefinition) }
    }

    /// Modifier-only shortcut gesture for Dictation.
    @Published public var dictationModifierShortcutGesture: ModifierShortcutGesture? {
        didSet { save(dictationModifierShortcutGesture, forKey: Keys.dictationModifierShortcutGesture) }
    }

    /// Modifier-only shortcut gesture for Assistant.
    @Published public var assistantModifierShortcutGesture: ModifierShortcutGesture? {
        didSet { save(assistantModifierShortcutGesture, forKey: Keys.assistantModifierShortcutGesture) }
    }

    /// Modifier-only shortcut gesture for Meetings.
    @Published public var meetingModifierShortcutGesture: ModifierShortcutGesture? {
        didSet { save(meetingModifierShortcutGesture, forKey: Keys.meetingModifierShortcutGesture) }
    }

    /// How keyboard shortcuts activate Assistant commands.
    @Published public var assistantShortcutActivationMode: ShortcutActivationMode {
        didSet {
            UserDefaults.standard.set(
                assistantShortcutActivationMode.rawValue,
                forKey: Keys.assistantShortcutActivationMode
            )
        }
    }

    /// Whether pressing Escape cancels Assistant recording.
    @Published public var assistantUseEscapeToCancelRecording: Bool {
        didSet { UserDefaults.standard.set(assistantUseEscapeToCancelRecording, forKey: Keys.assistantUseEscapeToCancelRecording) }
    }

    /// Whether pressing Enter stops Assistant recording and starts post-processing.
    @Published public var assistantUseEnterToStopRecording: Bool {
        didSet { UserDefaults.standard.set(assistantUseEnterToStopRecording, forKey: Keys.assistantUseEnterToStopRecording) }
    }

    /// Selected preset shortcut key for Assistant activation.
    @Published public var assistantSelectedPresetKey: PresetShortcutKey {
        didSet { UserDefaults.standard.set(assistantSelectedPresetKey.rawValue, forKey: Keys.assistantSelectedPresetKey) }
    }

    /// Single-key action used inside Assistant shortcut layer to trigger Assistant mode.
    @Published public var assistantLayerShortcutKey: String {
        didSet { UserDefaults.standard.set(assistantLayerShortcutKey, forKey: Keys.assistantLayerShortcutKey) }
    }

    /// Color for the Assistant mode screen border.
    @Published public var assistantBorderColor: AssistantBorderColor {
        didSet { UserDefaults.standard.set(assistantBorderColor.rawValue, forKey: Keys.assistantBorderColor) }
    }

    /// Style for the Assistant mode screen border (stroke or glow).
    @Published public var assistantBorderStyle: AssistantBorderStyle {
        didSet { UserDefaults.standard.set(assistantBorderStyle.rawValue, forKey: Keys.assistantBorderStyle) }
    }

    /// Width for the Assistant mode screen border.
    @Published public var assistantBorderWidth: Double {
        didSet { UserDefaults.standard.set(assistantBorderWidth, forKey: Keys.assistantBorderWidth) }
    }

    /// Size for the Assistant mode glow effect.
    @Published public var assistantGlowSize: Double {
        didSet { UserDefaults.standard.set(assistantGlowSize, forKey: Keys.assistantGlowSize) }
    }

    /// Configured Assistant integrations (Raycast is pre-seeded by default).
    @Published public var assistantIntegrations: [AssistantIntegrationConfig] {
        didSet {
            guard !isSynchronizingAssistantIntegrations else { return }
            synchronizeAssistantIntegrationsState()
            save(assistantIntegrations, forKey: Keys.assistantIntegrations)
        }
    }

    /// Currently selected Assistant integration.
    @Published public var assistantSelectedIntegrationId: UUID? {
        didSet {
            if let id = assistantSelectedIntegrationId {
                UserDefaults.standard.set(id.uuidString, forKey: Keys.assistantSelectedIntegrationId)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.assistantSelectedIntegrationId)
            }
        }
    }

    /// Whether Raycast integration is enabled for Assistant mode.
    @Published public var assistantRaycastEnabled: Bool {
        didSet { UserDefaults.standard.set(assistantRaycastEnabled, forKey: Keys.assistantRaycastEnabled) }
    }

    /// Base deeplink used for Raycast AI command integration.
    @Published public var assistantRaycastDeepLink: String {
        didSet { UserDefaults.standard.set(assistantRaycastDeepLink, forKey: Keys.assistantRaycastDeepLink) }
    }

    // MARK: - Recording Indicator Properties

    /// Whether the floating recording indicator is enabled.
    @Published public var recordingIndicatorEnabled: Bool {
        didSet { UserDefaults.standard.set(recordingIndicatorEnabled, forKey: Keys.recordingIndicatorEnabled) }
    }

    /// Style of the floating recording indicator.
    @Published public var recordingIndicatorStyle: RecordingIndicatorStyle {
        didSet { UserDefaults.standard.set(recordingIndicatorStyle.rawValue, forKey: Keys.recordingIndicatorStyle) }
    }

    /// Position of the floating recording indicator on screen.
    @Published public var recordingIndicatorPosition: RecordingIndicatorPosition {
        didSet { UserDefaults.standard.set(recordingIndicatorPosition.rawValue, forKey: Keys.recordingIndicatorPosition) }
    }

    /// Animation speed profile used by the floating recording indicator waveform bars.
    @Published public var recordingIndicatorAnimationSpeed: RecordingIndicatorAnimationSpeed {
        didSet {
            UserDefaults.standard.set(
                recordingIndicatorAnimationSpeed.rawValue,
                forKey: Keys.recordingIndicatorAnimationSpeed
            )
        }
    }

    /// Whether retention limit for old recordings and transcriptions is enabled.
    @Published public var autoDeleteTranscriptions: Bool {
        didSet { UserDefaults.standard.set(autoDeleteTranscriptions, forKey: Keys.autoDeleteTranscriptions) }
    }

    /// Number of days to keep recordings and transcriptions before cleanup.
    @Published public var autoDeletePeriodDays: Int {
        didSet { UserDefaults.standard.set(autoDeletePeriodDays, forKey: Keys.autoDeletePeriodDays) }
    }

    /// Primary accent color for the application.
    @Published public var appAccentColor: AppThemeColor {
        didSet { UserDefaults.standard.set(appAccentColor.rawValue, forKey: Keys.appAccentColor) }
    }

    /// Whether sound feedback for recording events is enabled.
    @Published public var soundFeedbackEnabled: Bool {
        didSet { UserDefaults.standard.set(soundFeedbackEnabled, forKey: Keys.soundFeedbackEnabled) }
    }

    /// Sound to play when recording starts.
    @Published public var recordingStartSound: SoundFeedbackSound {
        didSet { UserDefaults.standard.set(recordingStartSound.rawValue, forKey: Keys.recordingStartSound) }
    }

    /// Sound to play when recording stops.
    @Published public var recordingStopSound: SoundFeedbackSound {
        didSet { UserDefaults.standard.set(recordingStopSound.rawValue, forKey: Keys.recordingStopSound) }
    }

    /// Whether to show the app icon in the Dock (allows Cmd+Tab switching).
    @Published public var showInDock: Bool {
        didSet { UserDefaults.standard.set(showInDock, forKey: Keys.showInDock) }
    }

    /// When enabled, the app will auto-detect the meeting type for new meetings.
    /// When disabled, it will use the selected meeting prompt as the baseline.
    @Published public var meetingTypeAutoDetectEnabled: Bool {
        didSet { UserDefaults.standard.set(meetingTypeAutoDetectEnabled, forKey: Keys.meetingTypeAutoDetectEnabled) }
    }

    /// Path URL for exporting summaries.
    @Published public var summaryExportFolder: URL? {
        didSet {
            if let url = summaryExportFolder {
                do {
                    let bookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                    UserDefaults.standard.set(bookmark, forKey: Keys.summaryExportFolder)
                } catch {
                    print("Failed to save bookmark for export folder: \(error)")
                }
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.summaryExportFolder)
            }
        }
    }

    /// Markdown template for summary generation.
    @Published public var summaryTemplate: String {
        didSet { UserDefaults.standard.set(summaryTemplate, forKey: Keys.summaryTemplate) }
    }

    /// Whether summary template formatting is applied to exported files.
    @Published public var summaryTemplateEnabled: Bool {
        didSet { UserDefaults.standard.set(summaryTemplateEnabled, forKey: Keys.summaryTemplateEnabled) }
    }

    /// Whether to automatically export summaries after generation.
    @Published public var autoExportSummaries: Bool {
        didSet { UserDefaults.standard.set(autoExportSummaries, forKey: Keys.autoExportSummaries) }
    }

    /// Export safety policy level used to validate and sanitize summary exports.
    @Published public var summaryExportSafetyPolicyLevel: SummaryExportSafetyPolicyLevel {
        didSet { UserDefaults.standard.set(summaryExportSafetyPolicyLevel.rawValue, forKey: Keys.summaryExportSafetyPolicyLevel) }
    }

    /// Enables grounded single-turn Q&A in transcription detail.
    @Published public var meetingQnAEnabled: Bool {
        didSet { UserDefaults.standard.set(meetingQnAEnabled, forKey: Keys.meetingQnAEnabled) }
    }


    /// Enables Context Awareness to enrich AI post-processing with active app context.
    @Published public var contextAwarenessEnabled: Bool {
        didSet {
            UserDefaults.standard.set(contextAwarenessEnabled, forKey: Keys.contextAwarenessEnabled)
            if contextAwarenessEnabled {
                contextAwarenessIncludeAccessibilityText = true
            }
        }
    }

    /// Restricts context capture to explicit user actions (dictation/commands).
    @Published public var contextAwarenessExplicitActionOnly: Bool {
        didSet { UserDefaults.standard.set(contextAwarenessExplicitActionOnly, forKey: Keys.contextAwarenessExplicitActionOnly) }
    }

    /// Includes clipboard text in context metadata.
    @Published public var contextAwarenessIncludeClipboard: Bool {
        didSet { UserDefaults.standard.set(contextAwarenessIncludeClipboard, forKey: Keys.contextAwarenessIncludeClipboard) }
    }

    /// Includes OCR text extracted from the active window image.
    @Published public var contextAwarenessIncludeWindowOCR: Bool {
        didSet { UserDefaults.standard.set(contextAwarenessIncludeWindowOCR, forKey: Keys.contextAwarenessIncludeWindowOCR) }
    }

    /// Includes focused UI text extracted via macOS Accessibility APIs.
    @Published public var contextAwarenessIncludeAccessibilityText: Bool {
        didSet { UserDefaults.standard.set(contextAwarenessIncludeAccessibilityText, forKey: Keys.contextAwarenessIncludeAccessibilityText) }
    }

    /// Enables blocking context capture when the frontmost app is in a sensitive-app list.
    @Published public var contextAwarenessProtectSensitiveApps: Bool {
        didSet { UserDefaults.standard.set(contextAwarenessProtectSensitiveApps, forKey: Keys.contextAwarenessProtectSensitiveApps) }
    }

    /// Redacts sensitive patterns (email, URLs, tokens, long numeric sequences) before sending context to AI.
    @Published public var contextAwarenessRedactSensitiveData: Bool {
        didSet { UserDefaults.standard.set(contextAwarenessRedactSensitiveData, forKey: Keys.contextAwarenessRedactSensitiveData) }
    }

    /// Additional app bundle identifiers excluded from context capture.
    @Published public var contextAwarenessExcludedBundleIDs: [String] {
        didSet { save(contextAwarenessExcludedBundleIDs, forKey: Keys.contextAwarenessExcludedBundleIDs) }
    }

    /// Bundle identifiers that should force Markdown formatting for dictation.
    @Published public var markdownTargetBundleIdentifiers: [String] {
        didSet { save(markdownTargetBundleIdentifiers, forKey: Keys.markdownTargetBundleIdentifiers) }
    }

    /// Per-app dictation overrides (Markdown and output language).
    @Published public var dictationAppRules: [DictationAppRule] {
        didSet {
            let normalizedRules = Self.normalizedDictationAppRules(dictationAppRules)
            if normalizedRules != dictationAppRules {
                dictationAppRules = normalizedRules
                return
            }

            save(dictationAppRules, forKey: Keys.dictationAppRules)

            let markdownTargets = dictationAppRules
                .filter(\.forceMarkdownOutput)
                .map(\.bundleIdentifier)

            if markdownTargets != markdownTargetBundleIdentifiers {
                markdownTargetBundleIdentifiers = markdownTargets
            }

            let synchronizedBrowsers = synchronizedWebTargetBrowsers(
                from: dictationAppRules,
                legacyBrowsers: webTargetBrowserBundleIdentifiers
            )

            if synchronizedBrowsers != webTargetBrowserBundleIdentifiers {
                webTargetBrowserBundleIdentifiers = synchronizedBrowsers
            }
        }
    }

    /// Deterministic find-and-replace rules applied before post-processing.
    @Published public var vocabularyReplacementRules: [VocabularyReplacementRule] {
        didSet {
            let normalizedRules = Self.normalizedVocabularyReplacementRules(vocabularyReplacementRules)
            if normalizedRules != vocabularyReplacementRules {
                vocabularyReplacementRules = normalizedRules
                return
            }

            save(vocabularyReplacementRules, forKey: Keys.vocabularyReplacementRules)
        }
    }

    /// Website targets that should force Markdown formatting for dictation.
    @Published public var markdownWebTargets: [WebContextTarget] {
        didSet { save(markdownWebTargets, forKey: Keys.markdownWebTargets) }
    }

    /// Browser bundle identifiers used for matching web targets.
    @Published public var webTargetBrowserBundleIdentifiers: [String] {
        didSet { save(webTargetBrowserBundleIdentifiers, forKey: Keys.webTargetBrowserBundleIdentifiers) }
    }

    /// Browser bundle identifiers currently in effect for web target matching.
    public var effectiveWebTargetBrowserBundleIdentifiers: [String] {
        synchronizedWebTargetBrowsers(
            from: dictationAppRules,
            legacyBrowsers: webTargetBrowserBundleIdentifiers
        )
    }

    /// Bundle identifiers monitored to auto-start/stop meetings.
    @Published public var monitoredMeetingBundleIdentifiers: [String] {
        didSet { save(monitoredMeetingBundleIdentifiers, forKey: Keys.monitoredMeetingBundleIdentifiers) }
    }

    /// Web meeting targets detected by URL matching in browsers.
    @Published public var webMeetingTargets: [WebMeetingTarget] {
        didSet { save(webMeetingTargets, forKey: Keys.webMeetingTargets) }
    }

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

    // MARK: - Initialization

    private init() {
        let loadedAIConfiguration = Self.loadAIConfiguration()
        let loadedEnhancementsSelection = Self.loadEnhancementsAISelection(defaultingTo: loadedAIConfiguration)
        let loadedDictationSelection = Self.loadEnhancementsDictationAISelection(defaultingTo: loadedEnhancementsSelection)
        aiConfiguration = loadedAIConfiguration
        enhancementsAISelection = loadedEnhancementsSelection
        enhancementsDictationAISelection = loadedDictationSelection
        enhancementsProviderSelectedModels = Self.loadEnhancementsProviderSelectedModels(
            defaultMeetingSelection: loadedEnhancementsSelection,
            defaultDictationSelection: loadedDictationSelection
        )

        systemPrompt = UserDefaults.standard.string(forKey: Keys.systemPrompt) ?? AIPromptTemplates.defaultSystemPrompt

        userPrompts = Self.loadDecoded([PostProcessingPrompt].self, forKey: Keys.userPrompts) ?? []

        dictationPrompts = Self.loadDecoded([PostProcessingPrompt].self, forKey: Keys.dictationPrompts) ?? []

        deletedPromptIds = Self.loadDecoded(Set<UUID>.self, forKey: Keys.deletedPromptIds) ?? []

        postProcessingEnabled = UserDefaults.standard.bool(forKey: Keys.postProcessingEnabled)
        dictationStructuredPostProcessingEnabled = Self.loadBoolDefaultIfUnset(
            forKey: Keys.dictationStructuredPostProcessingEnabled,
            defaultValue: false
        )
        isDiarizationEnabled = UserDefaults.standard.bool(forKey: Keys.isDiarizationEnabled)

        minSpeakers = Self.loadOptionalInt(forKey: Keys.minSpeakers)
        maxSpeakers = Self.loadOptionalInt(forKey: Keys.maxSpeakers)
        numSpeakers = Self.loadOptionalInt(forKey: Keys.numSpeakers)

        audioFormat = Self.loadEnum(forKey: PostProcessingKeys.audioFormat, defaultValue: .m4a)

        selectedPromptId = Self.loadUUID(forKey: Keys.selectedPromptId)
        dictationSelectedPromptId = Self.loadUUID(forKey: Keys.dictationSelectedPromptId)

        shouldMergeAudioFiles = Self.loadBoolDefaultIfUnset(
            forKey: PostProcessingKeys.shouldMergeAudioFiles,
            defaultValue: true
        )

        selectedLanguage = Self.loadEnum(forKey: Keys.selectedLanguage, defaultValue: .system)

        audioDevicePriority = UserDefaults.standard.stringArray(forKey: Keys.audioDevicePriority) ?? []
        useSystemDefaultInput = Self.loadBoolDefaultIfUnset(forKey: Keys.useSystemDefaultInput, defaultValue: true)
        muteOutputDuringRecording = UserDefaults.standard.bool(forKey: Keys.muteOutputDuringRecording)
        autoIncreaseMicrophoneVolume = UserDefaults.standard.bool(forKey: Keys.autoIncreaseMicrophoneVolume)

        let rawActivationMode = UserDefaults.standard.string(forKey: Keys.shortcutActivationMode)
        let resolvedActivationMode = rawActivationMode.flatMap { ShortcutActivationMode(rawValue: $0) } ?? .holdOrToggle
        shortcutActivationMode = resolvedActivationMode
        let rawDictationActivationMode = UserDefaults.standard.string(forKey: Keys.dictationShortcutActivationMode)
        dictationShortcutActivationMode = rawDictationActivationMode
            .flatMap { ShortcutActivationMode(rawValue: $0) }
            ?? resolvedActivationMode
        shortcutDoubleTapIntervalMilliseconds = Self.loadDouble(
            forKey: Keys.shortcutDoubleTapIntervalMilliseconds,
            defaultValue: Self.defaultShortcutDoubleTapIntervalMilliseconds
        )
        useEscapeToCancelRecording = UserDefaults.standard.bool(forKey: Keys.useEscapeToCancelRecording)

        let rawPresetKey = UserDefaults.standard.string(forKey: Keys.selectedPresetKey)
        selectedPresetKey = rawPresetKey.flatMap { PresetShortcutKey(rawValue: $0) } ?? .fn

        let rawDictationKey = UserDefaults.standard.string(forKey: Keys.dictationSelectedPresetKey)
        dictationSelectedPresetKey = rawDictationKey.flatMap { PresetShortcutKey(rawValue: $0) } ?? (rawPresetKey.flatMap { PresetShortcutKey(rawValue: $0) } ?? .fn)

        let rawMeetingKey = UserDefaults.standard.string(forKey: Keys.meetingSelectedPresetKey)
        meetingSelectedPresetKey = rawMeetingKey.flatMap { PresetShortcutKey(rawValue: $0) } ?? .notSpecified

        dictationModifierShortcutGesture = Self.loadDecoded(
            ModifierShortcutGesture.self,
            forKey: Keys.dictationModifierShortcutGesture
        )
        assistantModifierShortcutGesture = Self.loadDecoded(
            ModifierShortcutGesture.self,
            forKey: Keys.assistantModifierShortcutGesture
        )
        meetingModifierShortcutGesture = Self.loadDecoded(
            ModifierShortcutGesture.self,
            forKey: Keys.meetingModifierShortcutGesture
        )

        let loadedAssistantShortcutDefinition = Self.loadDecoded(
            ShortcutDefinition.self,
            forKey: Keys.assistantShortcutDefinition
        )

        let loadedDictationShortcutDefinition = Self.loadDecoded(
            ShortcutDefinition.self,
            forKey: Keys.dictationShortcutDefinition
        )

        let loadedMeetingShortcutDefinition = Self.loadDecoded(
            ShortcutDefinition.self,
            forKey: Keys.meetingShortcutDefinition
        )

        let rawAssistantActivation = UserDefaults.standard.string(forKey: Keys.assistantShortcutActivationMode)
        assistantShortcutActivationMode = rawAssistantActivation
            .flatMap { ShortcutActivationMode(rawValue: $0) } ?? .holdOrToggle
        assistantUseEscapeToCancelRecording = UserDefaults.standard.bool(forKey: Keys.assistantUseEscapeToCancelRecording)
        assistantUseEnterToStopRecording = UserDefaults.standard.bool(forKey: Keys.assistantUseEnterToStopRecording)

        let rawAssistantPresetKey = UserDefaults.standard.string(forKey: Keys.assistantSelectedPresetKey)
        assistantSelectedPresetKey = rawAssistantPresetKey.flatMap { PresetShortcutKey(rawValue: $0) } ?? .rightOption
        assistantLayerShortcutKey = Self.normalizedLayerShortcutKey(
            UserDefaults.standard.string(forKey: Keys.assistantLayerShortcutKey)
        ) ?? "A"

        let loadedIntegrations = Self.loadDecoded([AssistantIntegrationConfig].self, forKey: Keys.assistantIntegrations)
        assistantIntegrations = loadedIntegrations ?? [AssistantIntegrationConfig.defaultRaycast]
        let shouldMigrateLegacyAssistantIntegration = loadedIntegrations == nil

        let rawSelectedIntegrationId = UserDefaults.standard.string(forKey: Keys.assistantSelectedIntegrationId)
        assistantSelectedIntegrationId = rawSelectedIntegrationId.flatMap(UUID.init(uuidString:))

        assistantRaycastEnabled = UserDefaults.standard.bool(forKey: Keys.assistantRaycastEnabled)
        assistantRaycastDeepLink = UserDefaults.standard.string(forKey: Keys.assistantRaycastDeepLink) ?? AssistantIntegrationConfig.defaultRaycastDeepLink

        meetingTypeAutoDetectEnabled = UserDefaults.standard.bool(forKey: Keys.meetingTypeAutoDetectEnabled)

        if let data = UserDefaults.standard.data(forKey: Keys.meetingPrompts),
           let prompts = try? JSONDecoder().decode([PostProcessingPrompt].self, from: data)
        {
            meetingPrompts = prompts
        } else {
            meetingPrompts = []
        }

        if let data = UserDefaults.standard.data(forKey: Keys.summaryExportFolder) {
            var isStale = false
            if let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) {
                summaryExportFolder = url
            } else {
                summaryExportFolder = nil
            }
        } else {
            summaryExportFolder = nil
        }

        summaryTemplate = UserDefaults.standard.string(forKey: Keys.summaryTemplate) ?? Self.defaultSummaryTemplate

        summaryTemplateEnabled = Self.loadBoolDefaultIfUnset(
            forKey: Keys.summaryTemplateEnabled,
            defaultValue: true
        )
        autoExportSummaries = UserDefaults.standard.bool(forKey: Keys.autoExportSummaries)
        summaryExportSafetyPolicyLevel = SummaryExportSafetyPolicyLevel(
            rawValue: UserDefaults.standard.string(forKey: Keys.summaryExportSafetyPolicyLevel) ?? ""
        ) ?? .standard
        meetingQnAEnabled = Self.loadBoolDefaultIfUnset(
            forKey: Keys.meetingQnAEnabled,
            defaultValue: true
        )
        let loadedContextAwarenessEnabled = UserDefaults.standard.bool(forKey: Keys.contextAwarenessEnabled)
        contextAwarenessEnabled = loadedContextAwarenessEnabled
        contextAwarenessExplicitActionOnly = Self.loadBoolDefaultIfUnset(
            forKey: Keys.contextAwarenessExplicitActionOnly,
            defaultValue: true
        )
        contextAwarenessIncludeClipboard = UserDefaults.standard.bool(forKey: Keys.contextAwarenessIncludeClipboard)
        contextAwarenessIncludeWindowOCR = UserDefaults.standard.bool(forKey: Keys.contextAwarenessIncludeWindowOCR)
        contextAwarenessIncludeAccessibilityText = Self.loadBoolDefaultIfUnset(
            forKey: Keys.contextAwarenessIncludeAccessibilityText,
            defaultValue: true
        )
        contextAwarenessProtectSensitiveApps = Self.loadBoolDefaultIfUnset(
            forKey: Keys.contextAwarenessProtectSensitiveApps,
            defaultValue: true
        )
        contextAwarenessRedactSensitiveData = Self.loadBoolDefaultIfUnset(
            forKey: Keys.contextAwarenessRedactSensitiveData,
            defaultValue: true
        )
        contextAwarenessExcludedBundleIDs = Self.loadDecoded([String].self, forKey: Keys.contextAwarenessExcludedBundleIDs) ?? []
        markdownTargetBundleIdentifiers = Self.loadDecoded([String].self, forKey: Keys.markdownTargetBundleIdentifiers)
            ?? Self.defaultMarkdownTargetBundleIdentifiers
        dictationAppRules = Self.normalizedDictationAppRules(
            Self.loadDecoded([DictationAppRule].self, forKey: Keys.dictationAppRules)
                ?? Self.defaultDictationAppRules
        )
        vocabularyReplacementRules = Self.normalizedVocabularyReplacementRules(
            Self.loadDecoded([VocabularyReplacementRule].self, forKey: Keys.vocabularyReplacementRules) ?? []
        )
        markdownWebTargets = Self.loadDecoded([WebContextTarget].self, forKey: Keys.markdownWebTargets)
            ?? Self.defaultMarkdownWebTargets
        webTargetBrowserBundleIdentifiers = Self.loadDecoded([String].self, forKey: Keys.webTargetBrowserBundleIdentifiers)
            ?? Self.defaultWebTargetBrowserBundleIdentifiers
        monitoredMeetingBundleIdentifiers = Self.loadDecoded([String].self, forKey: Keys.monitoredMeetingBundleIdentifiers)
            ?? Self.defaultMonitoredMeetingBundleIdentifiers
        webMeetingTargets = Self.loadDecoded([WebMeetingTarget].self, forKey: Keys.webMeetingTargets)
            ?? Self.defaultWebMeetingTargets

        let hasPersistedMarkdownWebTargets = UserDefaults.standard.object(forKey: Keys.markdownWebTargets) != nil
        let hasPersistedWebMeetingTargets = UserDefaults.standard.object(forKey: Keys.webMeetingTargets) != nil
        let hasPersistedLegacyPerTargetBrowsers = hasPersistedMarkdownWebTargets || hasPersistedWebMeetingTargets
        let hasGlobalBrowserSetting = UserDefaults.standard.object(forKey: Keys.webTargetBrowserBundleIdentifiers) != nil

        if loadedContextAwarenessEnabled {
            contextAwarenessIncludeAccessibilityText = true
        }

        let rawBorderColor = UserDefaults.standard.string(forKey: Keys.assistantBorderColor)
        assistantBorderColor = rawBorderColor.flatMap { AssistantBorderColor(rawValue: $0) } ?? .green
        let rawBorderStyle = UserDefaults.standard.string(forKey: Keys.assistantBorderStyle)
        assistantBorderStyle = rawBorderStyle.flatMap { AssistantBorderStyle(rawValue: $0) } ?? .stroke
        let storedBorderWidth = UserDefaults.standard.object(forKey: Keys.assistantBorderWidth) as? NSNumber
        assistantBorderWidth = max(1, storedBorderWidth?.doubleValue ?? 8)
        let storedGlowSize = UserDefaults.standard.object(forKey: Keys.assistantGlowSize) as? NSNumber
        assistantGlowSize = max(0, storedGlowSize?.doubleValue ?? 20)

        recordingIndicatorEnabled = Self.loadBoolDefaultIfUnset(
            forKey: Keys.recordingIndicatorEnabled,
            defaultValue: true
        )
        let rawIndicatorStyle = UserDefaults.standard.string(forKey: Keys.recordingIndicatorStyle)
        recordingIndicatorStyle = rawIndicatorStyle.flatMap { RecordingIndicatorStyle(rawValue: $0) } ?? .mini
        let rawIndicatorPosition = UserDefaults.standard.string(forKey: Keys.recordingIndicatorPosition)
        recordingIndicatorPosition = rawIndicatorPosition.flatMap { RecordingIndicatorPosition(rawValue: $0) } ?? .bottom
        let rawIndicatorAnimationSpeed = UserDefaults.standard.string(forKey: Keys.recordingIndicatorAnimationSpeed)
        recordingIndicatorAnimationSpeed = rawIndicatorAnimationSpeed
            .flatMap { RecordingIndicatorAnimationSpeed(rawValue: $0) } ?? .normal

        autoDeleteTranscriptions = UserDefaults.standard.bool(forKey: Keys.autoDeleteTranscriptions)
        let rawDays = UserDefaults.standard.object(forKey: Keys.autoDeletePeriodDays) as? Int
        autoDeletePeriodDays = rawDays ?? 30

        let rawAccentColor = UserDefaults.standard.string(forKey: Keys.appAccentColor)
        appAccentColor = rawAccentColor.flatMap { AppThemeColor(rawValue: $0) } ?? .system

        soundFeedbackEnabled = UserDefaults.standard.bool(forKey: Keys.soundFeedbackEnabled)
        let rawStartSound = UserDefaults.standard.string(forKey: Keys.recordingStartSound)
        recordingStartSound = rawStartSound.flatMap { SoundFeedbackSound(rawValue: $0) } ?? .pop
        let rawStopSound = UserDefaults.standard.string(forKey: Keys.recordingStopSound)
        recordingStopSound = rawStopSound.flatMap { SoundFeedbackSound(rawValue: $0) } ?? .glass

        showInDock = UserDefaults.standard.bool(forKey: Keys.showInDock)

        dictationShortcutDefinition = loadedDictationShortcutDefinition ??
            Self.resolveShortcutDefinition(
                explicitGesture: dictationModifierShortcutGesture,
                legacyPresetKey: dictationSelectedPresetKey,
                activationMode: dictationShortcutActivationMode
            )
        assistantShortcutDefinition = loadedAssistantShortcutDefinition ??
            Self.resolveShortcutDefinition(
                explicitGesture: assistantModifierShortcutGesture,
                legacyPresetKey: assistantSelectedPresetKey,
                activationMode: assistantShortcutActivationMode
            )
        meetingShortcutDefinition = loadedMeetingShortcutDefinition ??
            Self.resolveShortcutDefinition(
                explicitGesture: meetingModifierShortcutGesture,
                legacyPresetKey: meetingSelectedPresetKey,
                activationMode: shortcutActivationMode
            )

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

        if loadedDictationShortcutDefinition == nil {
            save(dictationShortcutDefinition, forKey: Keys.dictationShortcutDefinition)
        }
        if loadedAssistantShortcutDefinition == nil {
            save(assistantShortcutDefinition, forKey: Keys.assistantShortcutDefinition)
        }
        if loadedMeetingShortcutDefinition == nil {
            save(meetingShortcutDefinition, forKey: Keys.meetingShortcutDefinition)
        }

        if let selectedID = assistantSelectedIntegrationId {
            UserDefaults.standard.set(selectedID.uuidString, forKey: Keys.assistantSelectedIntegrationId)
        } else {
            UserDefaults.standard.removeObject(forKey: Keys.assistantSelectedIntegrationId)
        }

        UserDefaults.standard.set(assistantRaycastEnabled, forKey: Keys.assistantRaycastEnabled)
        UserDefaults.standard.set(assistantRaycastDeepLink, forKey: Keys.assistantRaycastDeepLink)

        if hasPersistedLegacyPerTargetBrowsers, !hasGlobalBrowserSetting {
            migrateWebTargetBrowsersToGlobalSettingIfNeeded()
        }

        migrateLegacyMarkdownTargetsToDictationAppRulesIfNeeded()
        migrateLegacyWebTargetBrowsersToDictationAppRulesIfNeeded()
        backfillEnhancementsSelectionModelsIfNeeded()
        applyLanguage(selectedLanguage)
    }

}
