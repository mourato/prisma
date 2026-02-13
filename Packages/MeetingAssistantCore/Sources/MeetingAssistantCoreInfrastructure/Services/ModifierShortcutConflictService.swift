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

/// Binding entry used by the conflict validator.
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
public struct ModifierShortcutConflict: Equatable, Sendable {
    public let candidate: ModifierShortcutBinding
    public let conflicting: ModifierShortcutBinding

    public init(candidate: ModifierShortcutBinding, conflicting: ModifierShortcutBinding) {
        self.candidate = candidate
        self.conflicting = conflicting
    }
}

public enum ModifierShortcutConflictService {
    /// Returns the first conflict found for `candidate` against a set of `existing` bindings.
    public static func conflict(
        for candidate: ModifierShortcutBinding,
        in existing: [ModifierShortcutBinding]
    ) -> ModifierShortcutConflict? {
        guard !candidate.gesture.isEmpty else {
            return nil
        }

        guard let conflicting = existing.first(where: { entry in
            entry.actionID != candidate.actionID &&
                !entry.gesture.isEmpty &&
                entry.gesture.normalizedSignature == candidate.gesture.normalizedSignature
        }) else {
            return nil
        }

        return ModifierShortcutConflict(candidate: candidate, conflicting: conflicting)
    }

    /// Detects all duplicates in a bindings collection.
    public static func allConflicts(in bindings: [ModifierShortcutBinding]) -> [ModifierShortcutConflict] {
        var conflicts: [ModifierShortcutConflict] = []

        for index in bindings.indices {
            let candidate = bindings[index]
            let previous = Array(bindings[..<index])
            if let conflict = conflict(for: candidate, in: previous) {
                conflicts.append(conflict)
            }
        }

        return conflicts
    }
}
