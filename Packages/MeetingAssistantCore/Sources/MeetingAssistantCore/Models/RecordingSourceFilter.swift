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
            NSLocalizedString("filter.source.all", bundle: .safeModule, comment: "")
        case .dictations:
            NSLocalizedString("filter.source.dictations", bundle: .safeModule, comment: "")
        case .manualImports:
            NSLocalizedString("filter.source.manual_imports", bundle: .safeModule, comment: "")
        }
    }
}
