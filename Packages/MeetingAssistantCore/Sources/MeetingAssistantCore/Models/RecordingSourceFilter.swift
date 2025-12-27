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
            "filter.source.all".localized
        case .dictations:
            "filter.source.dictations".localized
        case .manualImports:
            "filter.source.manual_imports".localized
        }
    }
}
