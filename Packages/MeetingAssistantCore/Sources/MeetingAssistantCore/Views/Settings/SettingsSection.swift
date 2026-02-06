import SwiftUI

// MARK: - Settings Section Enum

public enum SettingsSection: String, CaseIterable, Identifiable {
    case metrics
    case general
    case dictation
    case meetings
    case assistant
    case audio
    case transcriptions
    case enhancements
    case service
    case permissions

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .metrics: "settings.section.metrics".localized
        case .general: "settings.section.general".localized
        case .dictation: "settings.section.dictation".localized
        case .meetings: "settings.section.meetings".localized
        case .audio: "settings.section.audio".localized
        case .assistant: "settings.section.assistant".localized
        case .transcriptions: "settings.section.transcriptions".localized
        case .enhancements: "settings.section.ai".localized
        case .service: "settings.section.service".localized
        case .permissions: "settings.section.permissions".localized
        }
    }

    public var icon: String {
        switch self {
        case .metrics: "chart.bar"
        case .general: "gear"
        case .dictation: "mic.fill"
        case .meetings: "person.2.fill"
        case .audio: "speaker.wave.2.fill"
        case .assistant: "sparkles"
        case .transcriptions: "doc.text"
        case .enhancements: "wand.and.stars"
        case .service: "server.rack"
        case .permissions: "lock.shield"
        }
    }
}
