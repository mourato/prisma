import SwiftUI

// MARK: - Settings Section Enum

public enum SettingsSection: String, CaseIterable, Identifiable {
    case transcriptions
    case general
    case shortcuts
    case ai
    case postProcessing
    case service
    case permissions

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .transcriptions: NSLocalizedString("settings.section.transcriptions", comment: "")
        case .general: NSLocalizedString("settings.section.general", comment: "")
        case .shortcuts: NSLocalizedString("settings.section.shortcuts", comment: "")
        case .ai: NSLocalizedString("settings.section.ai", comment: "")
        case .postProcessing: NSLocalizedString("settings.section.post_processing", comment: "")
        case .service: NSLocalizedString("settings.section.service", comment: "")
        case .permissions: NSLocalizedString("settings.section.permissions", comment: "")
        }
    }

    public var icon: String {
        switch self {
        case .transcriptions: "doc.text"
        case .general: "gear"
        case .shortcuts: "command"
        case .ai: "brain"
        case .postProcessing: "text.magnifyingglass"
        case .service: "server.rack"
        case .permissions: "lock.shield"
        }
    }
}
