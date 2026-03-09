import Foundation

public extension AppSettingsStore {
    func ignoredCalendarEventIdentifiers() -> Set<String> {
        Self.loadDecoded(Set<String>.self, forKey: Keys.ignoredCalendarEventIdentifiers) ?? []
    }

    func ignoreCalendarEventIdentifier(_ identifier: String) {
        let normalized = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }

        var identifiers = ignoredCalendarEventIdentifiers()
        identifiers.insert(normalized)
        save(identifiers, forKey: Keys.ignoredCalendarEventIdentifiers)
    }

    func unignoreCalendarEventIdentifier(_ identifier: String) {
        let normalized = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }

        var identifiers = ignoredCalendarEventIdentifiers()
        identifiers.remove(normalized)
        save(identifiers, forKey: Keys.ignoredCalendarEventIdentifiers)
    }
}
