import Foundation
import MeetingAssistantCoreCommon

enum MeetingNotesEditorEngine: String {
    case textual
    case native
}

struct MeetingNotesEditorEngineResolver {
    static let environmentKey = "MA_MEETING_NOTES_EDITOR_ENGINE"
    static let userDefaultsKey = "internal.meetingNotesEditorEngine"

    private let environmentProvider: () -> [String: String]
    private let userDefaults: UserDefaults

    init(
        environmentProvider: @escaping () -> [String: String] = { ProcessInfo.processInfo.environment },
        userDefaults: UserDefaults = .standard
    ) {
        self.environmentProvider = environmentProvider
        self.userDefaults = userDefaults
    }

    func resolve() -> MeetingNotesEditorEngine {
        if let environmentValue = normalized(environmentProvider()[Self.environmentKey]) {
            return resolveCandidate(environmentValue, source: "environment")
        }

        if let persistedValue = normalized(userDefaults.string(forKey: Self.userDefaultsKey)) {
            return resolveCandidate(persistedValue, source: "user_defaults")
        }

        return .textual
    }

    private func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return nil }
        return normalized
    }

    private func resolveCandidate(_ value: String, source: String) -> MeetingNotesEditorEngine {
        if let engine = MeetingNotesEditorEngine(rawValue: value) {
            return engine
        }

        AppLogger.warning(
            "Invalid meeting notes editor engine; falling back to textual",
            category: .uiController,
            extra: [
                "source": source,
                "provided_value": value,
                "fallback_engine": MeetingNotesEditorEngine.textual.rawValue,
            ]
        )
        return .textual
    }
}
