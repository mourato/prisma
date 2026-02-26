import Foundation

// MARK: - Onboarding Step

public enum OnboardingStep: Int, CaseIterable, Identifiable, Hashable, Sendable {
    case welcome
    case permissions
    case shortcuts
    case downloadModels
    case completion

    public var id: Int { rawValue }

    /// 1-based index for display purposes.
    public var index: Int { rawValue + 1 }

    /// Whether this step can be skipped.
    public var isSkippable: Bool {
        switch self {
        case .permissions, .shortcuts, .downloadModels: true
        case .welcome, .completion: false
        }
    }
}

// MARK: - Onboarding Permission Type

public enum OnboardingPermissionType: CaseIterable, Hashable, Sendable {
    case microphone
    case screenRecording
    case accessibility
}

// MARK: - Onboarding Permission Item

public struct OnboardingPermissionItem: Hashable, Sendable {
    public let type: OnboardingPermissionType
    public let titleKey: String
    public let descriptionKey: String
    public let iconName: String

    public init(
        type: OnboardingPermissionType,
        titleKey: String,
        descriptionKey: String,
        iconName: String
    ) {
        self.type = type
        self.titleKey = titleKey
        self.descriptionKey = descriptionKey
        self.iconName = iconName
    }

    /// All permissions required for onboarding.
    public static let allPermissions: [OnboardingPermissionItem] = [
        OnboardingPermissionItem(
            type: .microphone,
            titleKey: "onboarding.permissions.microphone.title",
            descriptionKey: "onboarding.permissions.microphone.desc",
            iconName: "mic.fill"
        ),
        OnboardingPermissionItem(
            type: .screenRecording,
            titleKey: "onboarding.permissions.screen_recording.title",
            descriptionKey: "onboarding.permissions.screen_recording.desc",
            iconName: "rectangle.on.rectangle"
        ),
        OnboardingPermissionItem(
            type: .accessibility,
            titleKey: "onboarding.permissions.accessibility.title",
            descriptionKey: "onboarding.permissions.accessibility.desc",
            iconName: "figure.wave"
        ),
    ]
}

// MARK: - Onboarding Shortcut Type

public enum OnboardingShortcutType: CaseIterable, Hashable, Sendable {
    case dictation
    case meeting
    case assistant

    public var titleKey: String {
        switch self {
        case .dictation: "onboarding.shortcuts.dictation"
        case .meeting: "onboarding.shortcuts.meeting"
        case .assistant: "onboarding.shortcuts.assistant"
        }
    }
}

// MARK: - Onboarding Shortcut Item

public struct OnboardingShortcutItem: Hashable, Sendable {
    public let type: OnboardingShortcutType
    public let titleKey: String
    public let descriptionKey: String

    public init(type: OnboardingShortcutType) {
        self.type = type
        titleKey = type.titleKey
        descriptionKey = "onboarding.shortcuts.use_default"
    }

    /// All shortcuts configurable during onboarding.
    public static let allShortcuts: [OnboardingShortcutItem] = OnboardingShortcutType.allCases.map { OnboardingShortcutItem(type: $0) }
}
