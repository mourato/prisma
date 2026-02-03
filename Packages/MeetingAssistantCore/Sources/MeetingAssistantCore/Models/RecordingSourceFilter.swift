import Foundation

/// Filter for transcription source type.
public enum RecordingSourceFilter: String, CaseIterable, Sendable {
    case all
    case dictations
    case meetings
    case manualImports

    /// Display name for the filter option.
    public var displayName: String {
        switch self {
        case .all:
            "filter.source.all".localized
        case .dictations:
            "filter.source.dictations".localized
        case .meetings:
            // "Reuniões"
            NSLocalizedString("filter.source.meetings", bundle: .safeModule, value: "Reuniões", comment: "Filter option for meetings")
        case .manualImports:
            "filter.source.manual_imports".localized
        }
    }
}
