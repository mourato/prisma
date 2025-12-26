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
        case .unknown: .secondary
        case .testing: .orange
        case .success: .green
        case .failure: .red
        }
    }

    public var text: String {
        switch self {
        case .unknown: "Não testado"
        case .testing: "Testando..."
        case .success: "Conectado"
        case let .failure(message): message ?? "Falha"
        }
    }

    public static func == (lhs: ConnectionStatus, rhs: ConnectionStatus) -> Bool {
        switch (lhs, rhs) {
        case (.unknown, .unknown), (.testing, .testing), (.success, .success):
            true
        case (.failure, .failure):
            true
        default:
            false
        }
    }
}
