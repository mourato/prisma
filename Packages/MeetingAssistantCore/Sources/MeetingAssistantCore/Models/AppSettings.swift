import AppKit
import Foundation
import SwiftUI

// MARK: - AI Provider Configuration

/// Supported AI providers for post-processing transcriptions.
public enum AIProvider: String, CaseIterable, Codable, Sendable {
    case openai
    case anthropic
    case groq
    case custom

    public var displayName: String {
        switch self {
        case .openai: "OpenAI"
        case .anthropic: "Anthropic"
        case .groq: "Groq"
        case .custom: "ai.provider.custom".localized
        }
    }

    public var defaultBaseURL: String {
        switch self {
        case .openai: "https://api.openai.com/v1"
        case .anthropic: "https://api.anthropic.com/v1"
        case .groq: "https://api.groq.com/openai/v1"
        case .custom: ""
        }
    }

    public var icon: String {
        switch self {
        case .openai: "brain"
        case .anthropic: "sparkles"
        case .groq: "bolt.fill"
        case .custom: "server.rack"
        }
    }

    public var apiKeyURL: URL? {
        switch self {
        case .openai: URL(string: "https://platform.openai.com/api-keys")
        case .anthropic: URL(string: "https://console.anthropic.com/settings/keys")
        case .groq: URL(string: "https://console.groq.com/keys")
        case .custom: nil
        }
    }
}

// MARK: - App Language Configuration

/// Supported app languages for UI localization.
public enum AppLanguage: String, CaseIterable, Codable, Sendable {
    case system
    case english
    case portuguese

    public var displayName: String {
        switch self {
        case .system:
            "settings.general.language.system".localized
        case .english:
            "settings.general.language.english".localized
        case .portuguese:
            "settings.general.language.portuguese".localized
        }
    }
}

// MARK: - Shortcut Activation Mode

/// Modes for how keyboard shortcuts activate recording.
public enum ShortcutActivationMode: String, CaseIterable, Codable, Sendable {
    case holdOrToggle
    case toggle
    case hold
    case doubleTap

    public var localizedName: String {
        switch self {
        case .holdOrToggle:
            NSLocalizedString("settings.shortcuts.activation_mode.hold_or_toggle", bundle: .safeModule, comment: "")
        case .toggle:
            NSLocalizedString("settings.shortcuts.activation_mode.toggle", bundle: .safeModule, comment: "")
        case .hold:
            NSLocalizedString("settings.shortcuts.activation_mode.hold", bundle: .safeModule, comment: "")
        case .doubleTap:
            NSLocalizedString("settings.shortcuts.activation_mode.double_tap", bundle: .safeModule, comment: "")
        }
    }
}

// MARK: - Recording Indicator Configuration

/// Style options for the floating recording indicator.
public enum RecordingIndicatorStyle: String, CaseIterable, Codable, Sendable {
    case classic
    case mini
    case none

    public var displayName: String {
        switch self {
        case .classic:
            NSLocalizedString("settings.general.recording_indicator.style.classic", bundle: .safeModule, comment: "")
        case .mini:
            NSLocalizedString("settings.general.recording_indicator.style.mini", bundle: .safeModule, comment: "")
        case .none:
            NSLocalizedString("settings.general.recording_indicator.style.none", bundle: .safeModule, comment: "")
        }
    }
}

/// Position for the floating recording indicator on screen.
public enum RecordingIndicatorPosition: String, CaseIterable, Codable, Sendable {
    case top
    case bottom

    public var displayName: String {
        switch self {
        case .top:
            NSLocalizedString("settings.general.recording_indicator.position.top", bundle: .safeModule, comment: "")
        case .bottom:
            NSLocalizedString("settings.general.recording_indicator.position.bottom", bundle: .safeModule, comment: "")
        }
    }
}

// MARK: - App Theme Configuration

/// Available colors for the application's accent theme.
public enum AppThemeColor: String, CaseIterable, Codable, Sendable {
    case system
    case orange
    case red
    case pink
    case purple
    case blue
    case cyan
    case green
    case yellow

    /// The NSColor representation for use in AppKit.
    public var nsColor: NSColor {
        switch self {
        case .system: .controlAccentColor
        case .orange: .systemOrange
        case .red: .systemRed
        case .pink: .systemPink
        case .purple: .systemPurple
        case .blue: .systemBlue
        case .cyan: .systemCyan
        case .green: .systemGreen
        case .yellow: .systemYellow
        }
    }

    /// A color that contrasts well with the theme color, for use as text or icons on top of it.
    public var adaptiveForegroundColor: Color {
        switch self {
        case .system:
            // Dynamic check for system accent color luminance if needed,
            // but usually system colors work well with adaptive themes.
            // For macOS system accent, white usually works best on most except yellow.
            .white
        case .yellow, .cyan: .black
        default: .white
        }
    }
}

// MARK: - Assistant Screen Border Configuration

/// Available colors for the Assistant mode screen border.
/// Reuses AppThemeColor logic for consistency.
public typealias AssistantBorderColor = AppThemeColor

/// Style options for the Assistant mode screen border feedback.
public enum AssistantBorderStyle: String, CaseIterable, Codable, Sendable {
    case stroke
    case glow

    public var displayName: String {
        switch self {
        case .stroke:
            NSLocalizedString("settings.assistant.border_style.stroke", bundle: .safeModule, comment: "")
        case .glow:
            NSLocalizedString("settings.assistant.border_style.glow", bundle: .safeModule, comment: "")
        }
    }
}

// MARK: - Sound Feedback Configuration

/// Available sounds for recording feedback notifications.
/// Uses macOS built-in system sounds. Extensible for future custom sounds.
public enum SoundFeedbackSound: String, CaseIterable, Codable, Sendable {
    case none
    // macOS System Sounds
    case glass
    case ping
    case pop
    case purr
    case submarine
    case tink
    case basso
    case blow
    case bottle
    case frog
    case funk
    case hero
    case morse
    case sosumi

    /// Localized display name for the sound.
    public var displayName: String {
        switch self {
        case .none:
            NSLocalizedString("settings.general.sound_feedback.sound.none", bundle: .safeModule, comment: "")
        case .glass:
            "Glass"
        case .ping:
            "Ping"
        case .pop:
            "Pop"
        case .purr:
            "Purr"
        case .submarine:
            "Submarine"
        case .tink:
            "Tink"
        case .basso:
            "Basso"
        case .blow:
            "Blow"
        case .bottle:
            "Bottle"
        case .frog:
            "Frog"
        case .funk:
            "Funk"
        case .hero:
            "Hero"
        case .morse:
            "Morse"
        case .sosumi:
            "Sosumi"
        }
    }

    /// The macOS system sound name for NSSound.
    /// Returns nil for `.none` or custom sounds.
    public var systemSoundName: String? {
        switch self {
        case .none:
            nil
        case .glass:
            "Glass"
        case .ping:
            "Ping"
        case .pop:
            "Pop"
        case .purr:
            "Purr"
        case .submarine:
            "Submarine"
        case .tink:
            "Tink"
        case .basso:
            "Basso"
        case .blow:
            "Blow"
        case .bottle:
            "Bottle"
        case .frog:
            "Frog"
        case .funk:
            "Funk"
        case .hero:
            "Hero"
        case .morse:
            "Morse"
        case .sosumi:
            "Sosumi"
        }
    }

    /// Whether this is a system sound (vs. custom bundled sound).
    public var isSystemSound: Bool {
        self != .none
    }
}

// MARK: - Preset Shortcut Key

/// Predefined shortcut keys for quick recording activation.
/// Based on Spokenly's keyboard controls interface.
public enum PresetShortcutKey: String, CaseIterable, Codable, Sendable {
    case notSpecified
    case rightCommand
    case rightOption
    case rightShift
    case rightControl
    case optionCommand
    case controlCommand
    case controlOption
    case shiftCommand
    case optionShift
    case controlShift
    case fn
    case custom

    public var displayName: String {
        switch self {
        case .notSpecified:
            NSLocalizedString("settings.shortcuts.key.not_specified", bundle: .safeModule, comment: "")
        case .rightCommand:
            "Right ⌘"
        case .rightOption:
            "Right ⌥"
        case .rightShift:
            "Right ⇧"
        case .rightControl:
            "Right ⌃"
        case .optionCommand:
            "⌥ + ⌘"
        case .controlCommand:
            "⌃ + ⌘"
        case .controlOption:
            "⌃ + ⌥"
        case .shiftCommand:
            "⇧ + ⌘"
        case .optionShift:
            "⌥ + ⇧"
        case .controlShift:
            "⌃ + ⇧"
        case .fn:
            "Fn"
        case .custom:
            NSLocalizedString("settings.shortcuts.key.custom", bundle: .safeModule, comment: "")
        }
    }

    /// SF Symbol icon for the key
    public var icon: String? {
        switch self {
        case .fn: "fn"
        case .custom: "keyboard"
        default: nil
        }
    }
}

public struct AIConfiguration: Codable, Equatable, Sendable {
    public var provider: AIProvider
    public var baseURL: String
    public var selectedModel: String

    /// Legacy API key for migration purposes only.
    private var _legacyApiKey: String = ""

    public init(provider: AIProvider, baseURL: String, selectedModel: String) {
        self.provider = provider
        self.baseURL = baseURL
        self.selectedModel = selectedModel
    }

    public static let `default` = AIConfiguration(
        provider: .openai,
        baseURL: AIProvider.openai.defaultBaseURL,
        selectedModel: ""
    )

    public var isValid: Bool {
        let hasApiKey = KeychainManager.existsAPIKey(for: provider)
        return hasApiKey && !baseURL.isEmpty
    }

    /// Returns a copy of the configuration with the legacy key cleared.
    public var withoutLegacyKey: AIConfiguration {
        var copy = self
        copy._legacyApiKey = ""
        return copy
    }

    /// Internal accessor for migration logic.
    var legacyApiKey: String {
        _legacyApiKey
    }

    enum CodingKeys: String, CodingKey {
        case provider, baseURL, selectedModel
        case _legacyApiKey = "apiKey"
    }
}

// MARK: - App Settings Store

/// Centralized settings manager using UserDefaults.
@MainActor
public class AppSettingsStore: ObservableObject {
    public static let shared = AppSettingsStore()

    // MARK: - Keys

    private enum Keys {
        static let aiConfiguration = "aiConfiguration"
        static let systemPrompt = "postProcessingSystemPrompt"
        static let userPrompts = "postProcessingUserPrompts"
        static let selectedPromptId = "postProcessingSelectedPromptId"
        static let postProcessingEnabled = "postProcessingEnabled"
        static let isDiarizationEnabled = "isDiarizationEnabled"
        static let minSpeakers = "minSpeakers"
        static let maxSpeakers = "maxSpeakers"
        static let numSpeakers = "numSpeakers"
        static let selectedLanguage = "selectedLanguage"
        static let audioDevicePriority = "audioDevicePriority"
        static let useSystemDefaultInput = "useSystemDefaultInput"
        static let muteOutputDuringRecording = "muteOutputDuringRecording"
        static let deletedPromptIds = "postProcessingDeletedPromptIds"
        static let shortcutActivationMode = "shortcutActivationMode"
        static let useEscapeToCancelRecording = "useEscapeToCancelRecording"
        static let selectedPresetKey = "selectedPresetKey"
        static let dictationSelectedPresetKey = "dictationSelectedPresetKey"
        static let meetingSelectedPresetKey = "meetingSelectedPresetKey"
        static let assistantShortcutActivationMode = "assistantShortcutActivationMode"
        static let assistantUseEscapeToCancelRecording = "assistantUseEscapeToCancelRecording"
        static let assistantSelectedPresetKey = "assistantSelectedPresetKey"
        static let assistantBorderColor = "assistantBorderColor"
        static let assistantBorderStyle = "assistantBorderStyle"
        static let recordingIndicatorEnabled = "recordingIndicatorEnabled"
        static let recordingIndicatorStyle = "recordingIndicatorStyle"
        static let recordingIndicatorPosition = "recordingIndicatorPosition"
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
        static let meetingPrompts = "meetingPrompts"
        static let summaryExportFolder = "summaryExportFolder"
        static let summaryTemplate = "summaryTemplate"
        static let autoExportSummaries = "autoExportSummaries"
        static let createMeetingFolder = "createMeetingFolder"
    }

    // MARK: - Published Properties

    @Published public var aiConfiguration: AIConfiguration {
        didSet { save(aiConfiguration, forKey: Keys.aiConfiguration) }
    }

    // MARK: - AI Configuration Helpers

    /// Updates the selected model for the current AI provider.
    /// This properly triggers the @Published didSet to persist changes.
    public func updateSelectedModel(_ model: String) {
        var config = aiConfiguration
        config.selectedModel = model
        aiConfiguration = config
    }

    /// Updates the AI configuration for a specific provider.
    /// Properly triggers the @Published didSet to persist changes.
    public func updateAIConfiguration(provider: AIProvider, baseURL: String? = nil, selectedModel: String? = nil) {
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

    /// Whether post-processing is enabled.
    @Published public var postProcessingEnabled: Bool {
        didSet {
            UserDefaults.standard.set(postProcessingEnabled, forKey: Keys.postProcessingEnabled)
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

    /// How keyboard shortcuts activate recording.
    @Published public var shortcutActivationMode: ShortcutActivationMode {
        didSet { UserDefaults.standard.set(shortcutActivationMode.rawValue, forKey: Keys.shortcutActivationMode) }
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

    /// Selected preset shortcut key for Assistant activation.
    @Published public var assistantSelectedPresetKey: PresetShortcutKey {
        didSet { UserDefaults.standard.set(assistantSelectedPresetKey.rawValue, forKey: Keys.assistantSelectedPresetKey) }
    }

    /// Color for the Assistant mode screen border.
    @Published public var assistantBorderColor: AssistantBorderColor {
        didSet { UserDefaults.standard.set(assistantBorderColor.rawValue, forKey: Keys.assistantBorderColor) }
    }

    /// Style for the Assistant mode screen border (stroke or glow).
    @Published public var assistantBorderStyle: AssistantBorderStyle {
        didSet { UserDefaults.standard.set(assistantBorderStyle.rawValue, forKey: Keys.assistantBorderStyle) }
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

    /// Whether auto-delete of old transcriptions is enabled.
    @Published public var autoDeleteTranscriptions: Bool {
        didSet { UserDefaults.standard.set(autoDeleteTranscriptions, forKey: Keys.autoDeleteTranscriptions) }
    }

    /// Number of days to keep transcriptions before auto-deleting.
    @Published public var autoDeletePeriodDays: Int {
        didSet { UserDefaults.standard.set(autoDeletePeriodDays, forKey: Keys.autoDeletePeriodDays) }
    }

    /// Primary accent color for the application.
    @Published public var appAccentColor: AppThemeColor {
        didSet { UserDefaults.standard.set(appAccentColor.rawValue, forKey: Keys.appAccentColor) }
    }

    // MARK: - Sound Feedback Properties

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

    // MARK: - Meeting Prompts & Export

    /// User-created prompts specifically for meetings.
    @Published public var meetingPrompts: [PostProcessingPrompt] {
        didSet { save(meetingPrompts, forKey: Keys.meetingPrompts) }
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

    /// Whether to automatically export summaries after generation.
    @Published public var autoExportSummaries: Bool {
        didSet { UserDefaults.standard.set(autoExportSummaries, forKey: Keys.autoExportSummaries) }
    }
    
    /// Whether to create a subfolder for each meeting inside the export folder.
    @Published public var createMeetingFolder: Bool {
        didSet { UserDefaults.standard.set(createMeetingFolder, forKey: Keys.createMeetingFolder) }
    }

    /// All available prompts (predefined + user-created), filtered by deleted and overrides.
    public var allPrompts: [PostProcessingPrompt] {
        // 1. Start with predefined prompts that are NOT deleted
        let activePredefined = PostProcessingPrompt.allPredefined.filter { !deletedPromptIds.contains($0.id) }

        // 2. Identify which predefined prompts have user overrides (same ID in userPrompts)
        let overrideIds = Set(userPrompts.map(\.id))

        // 3. Filter predefined prompts that are NOT overridden
        let remainingPredefined = activePredefined.filter { !overrideIds.contains($0.id) }

        // 4. Return combined list: predefined (not overridden) + all user prompts (including overrides)
        return remainingPredefined + userPrompts
    }

    /// Currently selected prompt.
    public var selectedPrompt: PostProcessingPrompt? {
        guard let id = selectedPromptId else { return nil }
        return allPrompts.first { $0.id == id }
    }

    // MARK: - Initialization

    private init() {
        // Load AI configuration
        if let data = UserDefaults.standard.data(forKey: Keys.aiConfiguration),
           let config = try? JSONDecoder().decode(AIConfiguration.self, from: data)
        {
            if !config.legacyApiKey.isEmpty {
                // Migrate to Keychain
                let providerKey = KeychainManager.apiKeyKey(for: config.provider)
                try? KeychainManager.store(config.legacyApiKey, for: providerKey)
                aiConfiguration = config.withoutLegacyKey
            } else {
                aiConfiguration = config
            }
        } else {
            aiConfiguration = .default
        }

        systemPrompt = UserDefaults.standard.string(forKey: Keys.systemPrompt)
            ?? AIPromptTemplates.defaultSystemPrompt

        if let data = UserDefaults.standard.data(forKey: Keys.userPrompts),
           let prompts = try? JSONDecoder().decode([PostProcessingPrompt].self, from: data)
        {
            userPrompts = prompts
        } else {
            userPrompts = []
        }

        if let data = UserDefaults.standard.data(forKey: Keys.deletedPromptIds),
           let ids = try? JSONDecoder().decode(Set<UUID>.self, from: data)
        {
            deletedPromptIds = ids
        } else {
            deletedPromptIds = []
        }

        postProcessingEnabled = UserDefaults.standard.bool(forKey: Keys.postProcessingEnabled)
        isDiarizationEnabled = UserDefaults.standard.bool(forKey: Keys.isDiarizationEnabled)

        minSpeakers = UserDefaults.standard.object(forKey: Keys.minSpeakers) as? Int
        maxSpeakers = UserDefaults.standard.object(forKey: Keys.maxSpeakers) as? Int
        numSpeakers = UserDefaults.standard.object(forKey: Keys.numSpeakers) as? Int

        let rawFormat = UserDefaults.standard.string(forKey: PostProcessingKeys.audioFormat)
        audioFormat = rawFormat.flatMap { AudioFormat(rawValue: $0) } ?? .m4a

        selectedPromptId = UserDefaults.standard.string(forKey: Keys.selectedPromptId)
            .flatMap { UUID(uuidString: $0) }

        if UserDefaults.standard.object(forKey: PostProcessingKeys.shouldMergeAudioFiles) == nil {
            shouldMergeAudioFiles = true
        } else {
            shouldMergeAudioFiles = UserDefaults.standard.bool(forKey: PostProcessingKeys.shouldMergeAudioFiles)
        }

        let rawLang = UserDefaults.standard.string(forKey: Keys.selectedLanguage)
        selectedLanguage = rawLang.flatMap { AppLanguage(rawValue: $0) } ?? .system

        audioDevicePriority = UserDefaults.standard.stringArray(forKey: Keys.audioDevicePriority) ?? []
        if UserDefaults.standard.object(forKey: Keys.useSystemDefaultInput) == nil {
            useSystemDefaultInput = true
        } else {
            useSystemDefaultInput = UserDefaults.standard.bool(forKey: Keys.useSystemDefaultInput)
        }
        muteOutputDuringRecording = UserDefaults.standard.bool(forKey: Keys.muteOutputDuringRecording)

        let rawActivationMode = UserDefaults.standard.string(forKey: Keys.shortcutActivationMode)
        shortcutActivationMode = rawActivationMode.flatMap { ShortcutActivationMode(rawValue: $0) } ?? .holdOrToggle
        useEscapeToCancelRecording = UserDefaults.standard.bool(forKey: Keys.useEscapeToCancelRecording)

        let rawPresetKey = UserDefaults.standard.string(forKey: Keys.selectedPresetKey)
        selectedPresetKey = rawPresetKey.flatMap { PresetShortcutKey(rawValue: $0) } ?? .fn

        let rawDictationKey = UserDefaults.standard.string(forKey: Keys.dictationSelectedPresetKey)
        dictationSelectedPresetKey = rawDictationKey.flatMap { PresetShortcutKey(rawValue: $0) } ?? (rawPresetKey.flatMap { PresetShortcutKey(rawValue: $0) } ?? .fn)

        let rawMeetingKey = UserDefaults.standard.string(forKey: Keys.meetingSelectedPresetKey)
        meetingSelectedPresetKey = rawMeetingKey.flatMap { PresetShortcutKey(rawValue: $0) } ?? .notSpecified

        let rawAssistantActivation = UserDefaults.standard.string(forKey: Keys.assistantShortcutActivationMode)
        assistantShortcutActivationMode = rawAssistantActivation
            .flatMap { ShortcutActivationMode(rawValue: $0) } ?? .holdOrToggle
        assistantUseEscapeToCancelRecording = UserDefaults.standard.bool(forKey: Keys.assistantUseEscapeToCancelRecording)

        let rawAssistantPresetKey = UserDefaults.standard.string(forKey: Keys.assistantSelectedPresetKey)
        assistantSelectedPresetKey = rawAssistantPresetKey.flatMap { PresetShortcutKey(rawValue: $0) } ?? .rightOption

        // Load Meeting Prompts
        if let data = UserDefaults.standard.data(forKey: Keys.meetingPrompts),
           let prompts = try? JSONDecoder().decode([PostProcessingPrompt].self, from: data) {
            meetingPrompts = prompts
        } else {
            meetingPrompts = []
        }

        // Load Summary Export Config
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

        summaryTemplate = UserDefaults.standard.string(forKey: Keys.summaryTemplate) ?? """
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
        
        autoExportSummaries = UserDefaults.standard.bool(forKey: Keys.autoExportSummaries)
        createMeetingFolder = UserDefaults.standard.bool(forKey: Keys.createMeetingFolder)

        // Load assistant border settings
        let rawBorderColor = UserDefaults.standard.string(forKey: Keys.assistantBorderColor)
        assistantBorderColor = rawBorderColor.flatMap { AssistantBorderColor(rawValue: $0) } ?? .green
        let rawBorderStyle = UserDefaults.standard.string(forKey: Keys.assistantBorderStyle)
        assistantBorderStyle = rawBorderStyle.flatMap { AssistantBorderStyle(rawValue: $0) } ?? .stroke

        // Load recording indicator settings
        recordingIndicatorEnabled = UserDefaults.standard.bool(forKey: Keys.recordingIndicatorEnabled)
        let rawIndicatorStyle = UserDefaults.standard.string(forKey: Keys.recordingIndicatorStyle)
        recordingIndicatorStyle = rawIndicatorStyle.flatMap { RecordingIndicatorStyle(rawValue: $0) } ?? .mini
        let rawIndicatorPosition = UserDefaults.standard.string(forKey: Keys.recordingIndicatorPosition)
        recordingIndicatorPosition = rawIndicatorPosition.flatMap { RecordingIndicatorPosition(rawValue: $0) } ?? .bottom

        autoDeleteTranscriptions = UserDefaults.standard.bool(forKey: Keys.autoDeleteTranscriptions)
        let rawDays = UserDefaults.standard.object(forKey: Keys.autoDeletePeriodDays) as? Int
        autoDeletePeriodDays = rawDays ?? 30

        let rawAccentColor = UserDefaults.standard.string(forKey: Keys.appAccentColor)
        appAccentColor = rawAccentColor.flatMap { AppThemeColor(rawValue: $0) } ?? .system

        // Load sound feedback settings
        soundFeedbackEnabled = UserDefaults.standard.bool(forKey: Keys.soundFeedbackEnabled)
        let rawStartSound = UserDefaults.standard.string(forKey: Keys.recordingStartSound)
        recordingStartSound = rawStartSound.flatMap { SoundFeedbackSound(rawValue: $0) } ?? .pop
        let rawStopSound = UserDefaults.standard.string(forKey: Keys.recordingStopSound)
        recordingStopSound = rawStopSound.flatMap { SoundFeedbackSound(rawValue: $0) } ?? .glass

        // Load app visibility settings
        showInDock = UserDefaults.standard.bool(forKey: Keys.showInDock)

        applyLanguage(selectedLanguage)
    }

    // MARK: - Private Helpers

    /// Encodes and saves a Codable value to UserDefaults.
    private func save(_ value: some Encodable, forKey key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    /// Apply language preference to the system.
    private func applyLanguage(_ language: AppLanguage) {
        switch language {
        case .system:
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        case .english:
            UserDefaults.standard.set(["en"], forKey: "AppleLanguages")
        case .portuguese:
            UserDefaults.standard.set(["pt"], forKey: "AppleLanguages")
        }
        // UserDefaults synchronizes automatically
    }

    /// Reset all settings to defaults.
    public func resetToDefaults() {
        aiConfiguration = .default
        systemPrompt = AIPromptTemplates.defaultSystemPrompt
        userPrompts = []
        deletedPromptIds = []
        selectedPromptId = nil
        postProcessingEnabled = false
        isDiarizationEnabled = false
        minSpeakers = nil
        maxSpeakers = nil
        numSpeakers = nil
        audioDevicePriority = []
        useSystemDefaultInput = true
        muteOutputDuringRecording = false
        shortcutActivationMode = .holdOrToggle
        useEscapeToCancelRecording = false
        selectedPresetKey = .fn
        assistantShortcutActivationMode = .holdOrToggle
        assistantUseEscapeToCancelRecording = false
        assistantSelectedPresetKey = .rightOption
        assistantBorderColor = .green
        assistantBorderStyle = .stroke
        recordingIndicatorEnabled = false
        recordingIndicatorStyle = .mini
        recordingIndicatorPosition = .bottom
        autoDeleteTranscriptions = false
        autoDeletePeriodDays = 30
        appAccentColor = .system
        soundFeedbackEnabled = false
        recordingStartSound = .pop
        recordingStopSound = .glass
        launchAtLogin = false
        showInDock = false
    }

    // MARK: - Prompt Management

    /// Adds a new user prompt.
    /// - Parameter prompt: The prompt to add.
    public func addPrompt(_ prompt: PostProcessingPrompt) {
        userPrompts.append(prompt)
    }

    /// Updates an existing user prompt or creates a new override if it's predefined.
    /// - Parameter prompt: The prompt with updated values.
    public func updatePrompt(_ prompt: PostProcessingPrompt) {
        // Ensure it's not in the deleted list if we are updating/overriding it
        deletedPromptIds.remove(prompt.id)

        if let index = userPrompts.firstIndex(where: { $0.id == prompt.id }) {
            userPrompts[index] = prompt
        } else {
            // This is either a new prompt or a first-time override of a predefined prompt
            userPrompts.append(prompt)
        }
    }

    /// Deletes a prompt by ID.
    /// - Parameter id: The ID of the prompt to delete.
    public func deletePrompt(id: UUID) {
        // If it's a predefined prompt, mark it as deleted
        if PostProcessingPrompt.allPredefined.contains(where: { $0.id == id }) {
            deletedPromptIds.insert(id)
        }

        // Always remove from userPrompts if present
        userPrompts.removeAll { $0.id == id }

        if selectedPromptId == id {
            selectedPromptId = nil
        }
    }

    /// Resets the system prompt to default.
    public func resetSystemPrompt() {
        systemPrompt = AIPromptTemplates.defaultSystemPrompt
    }
}

// MARK: - General Settings Extension

public extension AppSettingsStore {
    private enum GeneralKeys {
        static let recordingsDirectory = "recordingsDirectory"
        static let autoStartRecording = "autoStartRecording"
        static let showSettingsOnLaunch = "showSettingsOnLaunch"
        static let autoCopyTranscriptionToClipboard = "autoCopyTranscriptionToClipboard"
        static let autoPasteTranscriptionToActiveApp = "autoPasteTranscriptionToActiveApp"
        static let launchAtLogin = "launchAtLogin"
    }

    /// Configured path for saving recordings.
    /// If empty or invalid, services should fallback to the default Application Support directory.
    var recordingsDirectory: String {
        get { UserDefaults.standard.string(forKey: GeneralKeys.recordingsDirectory) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: GeneralKeys.recordingsDirectory) }
    }

    /// Whether to automatically start recording when a meeting is detected.
    var autoStartRecording: Bool {
        get { UserDefaults.standard.bool(forKey: GeneralKeys.autoStartRecording) }
        set { UserDefaults.standard.set(newValue, forKey: GeneralKeys.autoStartRecording) }
    }

    /// Whether to show the settings window on app launch.
    var showSettingsOnLaunch: Bool {
        get { UserDefaults.standard.bool(forKey: GeneralKeys.showSettingsOnLaunch) }
        set { UserDefaults.standard.set(newValue, forKey: GeneralKeys.showSettingsOnLaunch) }
    }

    /// Whether to automatically copy the latest transcription to the clipboard.
    /// Default: true
    var autoCopyTranscriptionToClipboard: Bool {
        get {
            if UserDefaults.standard.object(forKey: GeneralKeys.autoCopyTranscriptionToClipboard) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: GeneralKeys.autoCopyTranscriptionToClipboard)
        }
        set { UserDefaults.standard.set(newValue, forKey: GeneralKeys.autoCopyTranscriptionToClipboard) }
    }

    /// Whether to automatically paste the latest transcription into the active app.
    /// Default: false
    var autoPasteTranscriptionToActiveApp: Bool {
        get { UserDefaults.standard.bool(forKey: GeneralKeys.autoPasteTranscriptionToActiveApp) }
        set { UserDefaults.standard.set(newValue, forKey: GeneralKeys.autoPasteTranscriptionToActiveApp) }
    }

    /// Whether the app should launch automatically at login.
    var launchAtLogin: Bool {
        get { UserDefaults.standard.bool(forKey: GeneralKeys.launchAtLogin) }
        set { UserDefaults.standard.set(newValue, forKey: GeneralKeys.launchAtLogin) }
    }

    // MARK: - Post-Processing Extension

    enum PostProcessingKeys {
        public static let audioFormat = "audioFormat"
        public static let shouldMergeAudioFiles = "shouldMergeAudioFiles"
    }

    /// Supported audio formats for recording.
    enum AudioFormat: String, CaseIterable, Codable, Sendable {
        case m4a
        case wav

        public var fileExtension: String {
            switch self {
            case .m4a: "m4a"
            case .wav: "wav"
            }
        }

        public var displayName: String {
            switch self {
            case .m4a: "AAC (.m4a)"
            case .wav: "WAV (Linear PCM)"
            }
        }
    }

    // Moved to main class body to support @Published storage
}
