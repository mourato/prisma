import Foundation

/// Canonical action identifier used for shortcut conflict validation.
public enum ModifierShortcutActionID: Hashable, Sendable {
    case dictation
    case assistant
    case meeting
    case assistantIntegration(UUID)

    var rawIdentifier: String {
        switch self {
        case .dictation:
            "dictation"
        case .assistant:
            "assistant"
        case .meeting:
            "meeting"
        case let .assistantIntegration(id):
            "assistantIntegration.\(id.uuidString)"
        }
    }
}

/// Generic binding entry used by the conflict validator.
public struct ShortcutBinding: Equatable, Sendable {
    public let actionID: ModifierShortcutActionID
    public let actionDisplayName: String
    public let shortcut: ShortcutDefinition

    public init(
        actionID: ModifierShortcutActionID,
        actionDisplayName: String,
        shortcut: ShortcutDefinition
    ) {
        self.actionID = actionID
        self.actionDisplayName = actionDisplayName
        self.shortcut = shortcut
    }
}

/// Binding entry used by the conflict validator for legacy modifier-only flows.
public struct ModifierShortcutBinding: Equatable, Sendable {
    public let actionID: ModifierShortcutActionID
    public let actionDisplayName: String
    public let gesture: ModifierShortcutGesture

    public init(
        actionID: ModifierShortcutActionID,
        actionDisplayName: String,
        gesture: ModifierShortcutGesture
    ) {
        self.actionID = actionID
        self.actionDisplayName = actionDisplayName
        self.gesture = gesture
    }
}

/// Conflict result between two actions sharing the same normalized signature.
public struct ShortcutConflict: Equatable, Sendable {
    public let candidate: ShortcutBinding
    public let conflicting: ShortcutBinding

    public init(candidate: ShortcutBinding, conflicting: ShortcutBinding) {
        self.candidate = candidate
        self.conflicting = conflicting
    }
}

/// Legacy compatibility alias.
public typealias ModifierShortcutConflict = ShortcutConflict

public enum ModifierShortcutConflictService {
    /// Returns the first conflict found for `candidate` against a set of `existing` bindings.
    public static func conflict(
        for candidate: ShortcutBinding,
        in existing: [ShortcutBinding]
    ) -> ShortcutConflict? {
        guard !candidate.shortcut.isEmpty else {
            return nil
        }

        guard let conflicting = existing.first(where: { entry in
            entry.actionID != candidate.actionID &&
                !entry.shortcut.isEmpty &&
                entry.shortcut.normalizedSignature == candidate.shortcut.normalizedSignature
        }) else {
            return nil
        }

        return ShortcutConflict(candidate: candidate, conflicting: conflicting)
    }

    /// Detects all duplicates in a generic bindings collection.
    public static func allConflicts(in bindings: [ShortcutBinding]) -> [ShortcutConflict] {
        var conflicts: [ShortcutConflict] = []

        for index in bindings.indices {
            let candidate = bindings[index]
            let previous = Array(bindings[..<index])
            if let conflict = conflict(for: candidate, in: previous) {
                conflicts.append(conflict)
            }
        }

        return conflicts
    }

    /// Returns the first conflict found for `candidate` against a set of `existing` modifier bindings.
    public static func conflict(
        for candidate: ModifierShortcutBinding,
        in existing: [ModifierShortcutBinding]
    ) -> ModifierShortcutConflict? {
        let genericCandidate = asShortcutBinding(candidate)
        let genericExisting = existing.map(asShortcutBinding)
        return conflict(for: genericCandidate, in: genericExisting)
    }

    /// Detects all duplicates in a modifier bindings collection.
    public static func allConflicts(in bindings: [ModifierShortcutBinding]) -> [ModifierShortcutConflict] {
        allConflicts(in: bindings.map(asShortcutBinding))
    }

    private static func asShortcutBinding(_ modifierBinding: ModifierShortcutBinding) -> ShortcutBinding {
        ShortcutBinding(
            actionID: modifierBinding.actionID,
            actionDisplayName: modifierBinding.actionDisplayName,
            shortcut: modifierBinding.gesture.asShortcutDefinition
        )
    }
}
