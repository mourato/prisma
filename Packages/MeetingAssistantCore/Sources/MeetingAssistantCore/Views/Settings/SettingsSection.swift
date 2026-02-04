import SwiftUI

// MARK: - Settings Section Enum

public enum SettingsSection: String, CaseIterable, Identifiable {
    case metrics
    case general
    case assistant
    case transcriptions
    case enhancements
    case permissions

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .metrics: NSLocalizedString("settings.section.metrics", bundle: .safeModule, comment: "")
        case .general: NSLocalizedString("settings.section.general", bundle: .safeModule, comment: "")
        case .assistant: NSLocalizedString("settings.section.assistant", bundle: .safeModule, comment: "")
        case .transcriptions: NSLocalizedString("settings.section.transcriptions", bundle: .safeModule, comment: "")
        case .enhancements: NSLocalizedString("settings.section.ai", bundle: .safeModule, comment: "")
        case .permissions: NSLocalizedString("settings.section.permissions", bundle: .safeModule, comment: "")
        }
    }

    public var icon: String {
        switch self {
        case .metrics: "chart.bar"
        case .general: "gear"
        case .assistant: "sparkles"
        case .transcriptions: "doc.text"
        case .enhancements: "wand.and.stars"
        case .permissions: "lock.shield"
        }
    }
}
