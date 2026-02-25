import Foundation
import MeetingAssistantCoreInfrastructure

enum ShortcutDefinitionNormalizer {
    static func normalized(_ definition: ShortcutDefinition?) -> ShortcutDefinition? {
        guard let definition, let primaryKey = definition.primaryKey else {
            return nil
        }

        let normalized = ShortcutDefinition(
            modifiers: definition.modifiers,
            primaryKey: primaryKey,
            trigger: .singleTap
        )

        return normalized.isValid ? normalized : nil
    }
}
