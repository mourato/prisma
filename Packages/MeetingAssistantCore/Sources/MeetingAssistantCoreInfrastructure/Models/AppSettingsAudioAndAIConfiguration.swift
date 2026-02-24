import Foundation
import MeetingAssistantCoreCommon

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
            "settings.general.sound_feedback.sound.none".localized
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
            "settings.shortcuts.key.not_specified".localized
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
            "settings.shortcuts.key.custom".localized
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

public struct EnhancementsAISelection: Codable, Equatable, Sendable {
    public var provider: AIProvider
    public var selectedModel: String

    public init(provider: AIProvider, selectedModel: String) {
        self.provider = provider
        self.selectedModel = selectedModel
    }

    public static let `default` = EnhancementsAISelection(
        provider: .openai,
        selectedModel: ""
    )
}

public enum EnhancementsInferenceReadinessIssue: String, Sendable {
    case invalidBaseURL = "enhancements.invalid_base_url"
    case missingAPIKey = "enhancements.missing_api_key"
    case missingModel = "enhancements.missing_model"
}
