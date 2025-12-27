import SwiftUI

// MARK: - Settings Section Enum

public enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case transcriptions
    case postProcessing
    case aiModels
    case permissions

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .general: NSLocalizedString("settings.section.general", bundle: .safeModule, comment: "")
        case .transcriptions: NSLocalizedString("settings.section.transcriptions", bundle: .safeModule, comment: "")
        case .postProcessing: NSLocalizedString("settings.section.post_processing", bundle: .safeModule, comment: "")
        case .aiModels: NSLocalizedString("settings.section.ai", bundle: .safeModule, comment: "")
        case .permissions: NSLocalizedString("settings.section.permissions", bundle: .safeModule, comment: "")
        }
    }

    public var icon: String {
        switch self {
        case .general: "gear"
        case .transcriptions: "doc.text"
        case .postProcessing: "text.magnifyingglass"
        case .aiModels: "brain"
        case .permissions: "lock.shield"
        }
    }
}
