import Foundation

public enum DictationStyleRoute: Hashable, Sendable {
    case editor(styleID: UUID?)
    case triggerSelection(styleID: UUID?)
    case promptEditor(styleID: UUID?)
}
