import SwiftUI

// MARK: - Settings Section Enum

public enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case shortcuts
    case ai
    case service
    case permissions
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .general: return "Geral"
        case .shortcuts: return "Atalhos"
        case .ai: return "IA"
        case .service: return "Serviço"
        case .permissions: return "Permissões"
        }
    }
    
    public var icon: String {
        switch self {
        case .general: return "gear"
        case .shortcuts: return "command"
        case .ai: return "brain"
        case .service: return "server.rack"
        case .permissions: return "lock.shield"
        }
    }
}
