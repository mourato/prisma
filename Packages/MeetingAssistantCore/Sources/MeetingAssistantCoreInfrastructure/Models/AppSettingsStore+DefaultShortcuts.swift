import Foundation

extension AppSettingsStore {
    public static var defaultDictationShortcutDefinition: ShortcutDefinition {
        ShortcutDefinition(
            modifiers: [.option, .command],
            primaryKey: .letter("D", keyCode: 0x02),
            trigger: .singleTap
        )
    }

    public static var defaultAssistantShortcutDefinition: ShortcutDefinition {
        ShortcutDefinition(
            modifiers: [.option, .command],
            primaryKey: .letter("A", keyCode: 0x00),
            trigger: .singleTap
        )
    }

    public static var defaultMeetingShortcutDefinition: ShortcutDefinition {
        ShortcutDefinition(
            modifiers: [.option, .command],
            primaryKey: .letter("M", keyCode: 0x2e),
            trigger: .singleTap
        )
    }
}
