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
        case .transcriptions: "Transcrições"
        case .general: "Geral"
        case .shortcuts: "Atalhos"
        case .ai: "IA"
        case .postProcessing: "Pós-Processamento"
        case .service: "Serviço"
        case .permissions: "Permissões"
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
