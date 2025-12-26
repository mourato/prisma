import Foundation

/// Filter for transcription source type.
public enum RecordingSourceFilter: String, CaseIterable, Sendable {
    case all
    case dictations
    case manualImports

    /// Display name for the filter option.
    public var displayName: String {
        switch self {
        case .all:
            "All"
        case .dictations:
            "Dictations"
        case .manualImports:
            "Manual Imports"
        }
    }
}
