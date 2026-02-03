import SwiftUI

// MARK: - Settings Section Enum

public enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case assistant
    case shortcuts
    case transcriptions
    case aiModels
    case permissions

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .general: NSLocalizedString("settings.section.general", bundle: .safeModule, comment: "")
        case .assistant: NSLocalizedString("settings.section.assistant", bundle: .safeModule, comment: "")
        case .shortcuts: NSLocalizedString("settings.section.shortcuts", bundle: .safeModule, comment: "")
        case .transcriptions: NSLocalizedString("settings.section.transcriptions", bundle: .safeModule, comment: "")
        case .aiModels: NSLocalizedString("settings.section.ai", bundle: .safeModule, comment: "")
        case .permissions: NSLocalizedString("settings.section.permissions", bundle: .safeModule, comment: "")
        }
    }

    public var icon: String {
        switch self {
        case .general: "gear"
        case .assistant: "sparkles"
        case .shortcuts: "command"
        case .transcriptions: "doc.text"
        case .aiModels: "brain"
        case .permissions: "lock.shield"
        }
    }
}
