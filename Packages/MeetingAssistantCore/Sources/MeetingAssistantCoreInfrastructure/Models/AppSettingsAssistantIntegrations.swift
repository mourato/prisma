import Foundation
import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain

// MARK: - Assistant Integrations Configuration

public enum AssistantIntegrationPreset: String, Codable, CaseIterable, Sendable {
    case googleSearch
    case launchApps
    case closeApps
    case askChatGPT
    case askClaude
    case youtubeSearch
    case openWebsite
    case appleShortcuts
    case shellCommand
    case pressKeys

    public var localizedName: String {
        switch self {
        case .googleSearch:
            "settings.assistant.integrations.presets.google_search".localized
        case .launchApps:
            "settings.assistant.integrations.presets.launch_apps".localized
        case .closeApps:
            "settings.assistant.integrations.presets.close_apps".localized
        case .askChatGPT:
            "settings.assistant.integrations.presets.ask_chatgpt".localized
        case .askClaude:
            "settings.assistant.integrations.presets.ask_claude".localized
        case .youtubeSearch:
            "settings.assistant.integrations.presets.youtube_search".localized
        case .openWebsite:
            "settings.assistant.integrations.presets.open_website".localized
        case .appleShortcuts:
            "settings.assistant.integrations.presets.apple_shortcuts".localized
        case .shellCommand:
            "settings.assistant.integrations.presets.shell_command".localized
        case .pressKeys:
            "settings.assistant.integrations.presets.press_keys".localized
        }
    }
}

public struct AssistantIntegrationScriptConfig: Codable, Equatable, Sendable {
    public enum Stage: String, Codable, CaseIterable, Sendable {
        case beforeAI
        case afterAI

        public var localizedName: String {
            switch self {
            case .beforeAI:
                "settings.assistant.integrations.script.stage.before_ai".localized
            case .afterAI:
                "settings.assistant.integrations.script.stage.after_ai".localized
            }
        }
    }

    public var stage: Stage
    public var script: String

    public init(stage: Stage, script: String) {
        self.stage = stage
        self.script = script
    }
}

public struct AssistantIntegrationConfig: Codable, Identifiable, Equatable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Sendable {
        case deeplink
    }

    public let id: UUID
    public var name: String
    public var kind: Kind
    public var isEnabled: Bool
    public var deepLink: String
    public var promptInstructions: String?
    public var selectedPreset: AssistantIntegrationPreset?
    public var shortcutDefinition: ShortcutDefinition?
    public var layerShortcutKey: String?
    public var shortcutPresetKey: PresetShortcutKey
    public var shortcutActivationMode: ShortcutActivationMode
    public var modifierShortcutGesture: ModifierShortcutGesture?
    public var advancedScript: AssistantIntegrationScriptConfig?
    /// Enables leader key mode for this integration.
    /// When enabled, the layer shortcut acts as a leader that requires a second action key.
    public var leaderModeEnabled: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        kind: Kind = .deeplink,
        isEnabled: Bool,
        deepLink: String,
        promptInstructions: String? = nil,
        selectedPreset: AssistantIntegrationPreset? = nil,
        shortcutDefinition: ShortcutDefinition? = nil,
        layerShortcutKey: String? = nil,
        shortcutPresetKey: PresetShortcutKey = .notSpecified,
        shortcutActivationMode: ShortcutActivationMode = .holdOrToggle,
        modifierShortcutGesture: ModifierShortcutGesture? = nil,
        advancedScript: AssistantIntegrationScriptConfig? = nil,
        leaderModeEnabled: Bool = false
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.isEnabled = isEnabled
        self.deepLink = deepLink
        self.promptInstructions = promptInstructions
        self.selectedPreset = selectedPreset
        self.shortcutDefinition = shortcutDefinition.flatMap {
            normalizedInHouseShortcutDefinition($0, activationMode: shortcutActivationMode)
        }
        self.layerShortcutKey = Self.normalizedLayerShortcutKey(layerShortcutKey)
        self.shortcutPresetKey = shortcutPresetKey
        self.shortcutActivationMode = shortcutActivationMode
        self.modifierShortcutGesture = modifierShortcutGesture
        self.advancedScript = advancedScript
        self.leaderModeEnabled = leaderModeEnabled
    }

    public init(
        id: UUID = UUID(),
        name: String,
        kind: Kind = .deeplink,
        isEnabled: Bool,
        deepLink: String,
        promptInstructions: String? = nil,
        selectedPreset: AssistantIntegrationPreset? = nil,
        layerShortcutKey: String? = nil,
        shortcutPresetKey: PresetShortcutKey = .notSpecified,
        shortcutActivationMode: ShortcutActivationMode = .holdOrToggle,
        modifierShortcutGesture: ModifierShortcutGesture? = nil,
        advancedScript: AssistantIntegrationScriptConfig? = nil,
        leaderModeEnabled: Bool = false
    ) {
        self.init(
            id: id,
            name: name,
            kind: kind,
            isEnabled: isEnabled,
            deepLink: deepLink,
            promptInstructions: promptInstructions,
            selectedPreset: selectedPreset,
            shortcutDefinition: nil,
            layerShortcutKey: layerShortcutKey,
            shortcutPresetKey: shortcutPresetKey,
            shortcutActivationMode: shortcutActivationMode,
            modifierShortcutGesture: modifierShortcutGesture,
            advancedScript: advancedScript,
            leaderModeEnabled: leaderModeEnabled
        )
    }

    public init(
        id: UUID = UUID(),
        name: String,
        kind: Kind = .deeplink,
        isEnabled: Bool,
        deepLink: String,
        promptInstructions: String? = nil,
        selectedPreset: AssistantIntegrationPreset? = nil,
        shortcutPresetKey: PresetShortcutKey = .notSpecified,
        shortcutActivationMode: ShortcutActivationMode = .holdOrToggle,
        modifierShortcutGesture: ModifierShortcutGesture? = nil,
        advancedScript: AssistantIntegrationScriptConfig? = nil,
        leaderModeEnabled: Bool = false
    ) {
        self.init(
            id: id,
            name: name,
            kind: kind,
            isEnabled: isEnabled,
            deepLink: deepLink,
            promptInstructions: promptInstructions,
            selectedPreset: selectedPreset,
            shortcutDefinition: nil,
            layerShortcutKey: nil,
            shortcutPresetKey: shortcutPresetKey,
            shortcutActivationMode: shortcutActivationMode,
            modifierShortcutGesture: modifierShortcutGesture,
            advancedScript: advancedScript,
            leaderModeEnabled: leaderModeEnabled
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case kind
        case isEnabled
        case deepLink
        case promptInstructions
        case selectedPreset
        case shortcutDefinition
        case layerShortcutKey
        case shortcutPresetKey
        case shortcutActivationMode
        case modifierShortcutGesture
        case advancedScript
        case leaderModeEnabled
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        kind = try container.decodeIfPresent(Kind.self, forKey: .kind) ?? .deeplink
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false
        deepLink = try container.decodeIfPresent(String.self, forKey: .deepLink) ?? Self.defaultRaycastDeepLink

        promptInstructions = try container.decodeIfPresent(String.self, forKey: .promptInstructions)
        selectedPreset = try container.decodeIfPresent(AssistantIntegrationPreset.self, forKey: .selectedPreset)
        shortcutPresetKey = try container.decodeIfPresent(PresetShortcutKey.self, forKey: .shortcutPresetKey) ?? .notSpecified
        shortcutActivationMode = try container.decodeIfPresent(ShortcutActivationMode.self, forKey: .shortcutActivationMode) ?? .holdOrToggle
        modifierShortcutGesture = try container.decodeIfPresent(ModifierShortcutGesture.self, forKey: .modifierShortcutGesture)
        // Initialize leaderModeEnabled early to avoid closure capture issues
        leaderModeEnabled = try container.decodeIfPresent(Bool.self, forKey: .leaderModeEnabled) ?? false

        let decodedShortcutDefinition = try container.decodeIfPresent(ShortcutDefinition.self, forKey: .shortcutDefinition)
        let normalizedDecodedShortcut = decodedShortcutDefinition.flatMap {
            normalizedInHouseShortcutDefinition($0, activationMode: shortcutActivationMode)
        }
        let normalizedGestureShortcut = modifierShortcutGesture.flatMap {
            normalizedInHouseShortcutDefinition($0.asShortcutDefinition, activationMode: shortcutActivationMode)
        }
        let normalizedLegacyShortcut = shortcutPresetKey
            .asLegacyModifierGesture(activationMode: shortcutActivationMode)
            .flatMap {
                normalizedInHouseShortcutDefinition($0.asShortcutDefinition, activationMode: shortcutActivationMode)
            }
        shortcutDefinition = normalizedDecodedShortcut ?? normalizedGestureShortcut ?? normalizedLegacyShortcut
        layerShortcutKey = try Self.normalizedLayerShortcutKey(
            container.decodeIfPresent(String.self, forKey: .layerShortcutKey)
        )

        if modifierShortcutGesture == nil {
            modifierShortcutGesture = shortcutDefinition?.asModifierShortcutGesture
        }
        advancedScript = try container.decodeIfPresent(AssistantIntegrationScriptConfig.self, forKey: .advancedScript)
    }

    private static func normalizedLayerShortcutKey(_ value: String?) -> String? {
        guard let rawValue = value?.trimmingCharacters(in: .whitespacesAndNewlines), !rawValue.isEmpty else {
            return nil
        }

        guard let firstCharacter = rawValue.first else {
            return nil
        }

        return String(firstCharacter).uppercased()
    }

    public static var defaultRaycast: AssistantIntegrationConfig {
        AssistantIntegrationConfig(
            id: raycastDefaultID,
            name: "Raycast",
            kind: .deeplink,
            isEnabled: false,
            deepLink: defaultRaycastDeepLink,
            layerShortcutKey: "R",
            shortcutPresetKey: .custom,
            shortcutActivationMode: .toggle,
            leaderModeEnabled: false
        )
    }

    public static let defaultRaycastDeepLink = "raycast://extensions/raycast/raycast-ai/ai-chat"

    public static var raycastDefaultID: UUID {
        guard let uuid = UUID(uuidString: "00000000-0000-0000-0000-000000000010") else {
            assertionFailure("Invalid UUID for default Raycast integration")
            return UUID()
        }
        return uuid
    }
}
