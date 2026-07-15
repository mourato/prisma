import Foundation

public enum DictationStyleRoute: Hashable, Sendable {
    case editor(styleID: UUID?)
    case promptEditor(styleID: UUID?)
}

public enum DictationStyleFocusTarget: Hashable, Sendable {
    case addButton
    case style(UUID)

    public static func forStyleID(_ styleID: UUID?) -> Self {
        guard let styleID else { return .addButton }
        return .style(styleID)
    }
}
