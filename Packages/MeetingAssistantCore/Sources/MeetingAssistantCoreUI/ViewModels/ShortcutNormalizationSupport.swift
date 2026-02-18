import Foundation
import MeetingAssistantCoreInfrastructure

enum ShortcutDefinitionNormalizer {
    static func normalized(_ definition: ShortcutDefinition?) -> ShortcutDefinition? {
        guard var definition else {
            return nil
        }

        if definition.primaryKey == nil {
            guard let modifier = definition.modifiers.first else {
                return nil
            }
            definition = ShortcutDefinition(
                modifiers: [modifier],
                primaryKey: nil,
                trigger: .doubleTap
            )
        } else {
            definition = ShortcutDefinition(
                modifiers: definition.modifiers,
                primaryKey: definition.primaryKey,
                trigger: .singleTap
            )
        }

        return definition.isValid ? definition : nil
    }
}

enum LayerShortcutKeyNormalizer {
    static func normalized(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let character = trimmed.first else {
            return ""
        }
        return String(character).uppercased()
    }
}
