import SwiftUI

// MARK: - Connection Status

/// Unified connection status for service health checks.
public enum ConnectionStatus: Equatable {
    case unknown
    case testing
    case success
    case failure(String?)
    
    public var color: Color {
        switch self {
        case .unknown: return .secondary
        case .testing: return .orange
        case .success: return .green
        case .failure: return .red
        }
    }
    
    public var text: String {
        switch self {
        case .unknown: return "Não testado"
        case .testing: return "Testando..."
        case .success: return "Conectado"
        case .failure(let message): return message ?? "Falha"
        }
    }
    
    public static func == (lhs: ConnectionStatus, rhs: ConnectionStatus) -> Bool {
        switch (lhs, rhs) {
        case (.unknown, .unknown), (.testing, .testing), (.success, .success):
            return true
        case (.failure, .failure):
            return true
        default:
            return false
        }
    }
}
