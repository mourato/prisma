import Foundation

/// Defines the source of audio to be recorded.
public enum RecordingSource: String, CaseIterable, Sendable {
    case microphone
    case system
    case all

    /// Display name for the source option.
    public var displayName: String {
        switch self {
        case .microphone:
            "Microphone Only" // "Microfone Apenas" - Should be localized later
        case .system:
            "System Audio Only" // "Áudio do Sistema Apenas"
        case .all:
            "All Sources (Mic + System)" // "Todos (Mic + Sistema)"
        }
    }
}
