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
        case .unknown: NSLocalizedString("connection.status.unknown", bundle: .safeModule, comment: "")
        case .testing: NSLocalizedString("connection.status.testing", bundle: .safeModule, comment: "")
        case .success: NSLocalizedString("connection.status.success", bundle: .safeModule, comment: "")
        case let .failure(message): message ?? NSLocalizedString("connection.status.failure", bundle: .safeModule, comment: "")
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
