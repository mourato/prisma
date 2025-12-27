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
        case .transcriptions: NSLocalizedString("settings.section.transcriptions", bundle: .safeModule, comment: "")
        case .general: NSLocalizedString("settings.section.general", bundle: .safeModule, comment: "")
        case .shortcuts: NSLocalizedString("settings.section.shortcuts", bundle: .safeModule, comment: "")
        case .ai: NSLocalizedString("settings.section.ai", bundle: .safeModule, comment: "")
        case .postProcessing: NSLocalizedString("settings.section.post_processing", bundle: .safeModule, comment: "")
        case .service: NSLocalizedString("settings.section.service", bundle: .safeModule, comment: "")
        case .permissions: NSLocalizedString("settings.section.permissions", bundle: .safeModule, comment: "")
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
