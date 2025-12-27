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
        case .connected: .green
        case .failed: .red
        }
    }

    public var text: String {
        switch self {
        case .notTested:
            "settings.service.status.not_tested".localized
        case .testing:
            "settings.service.status.testing".localized
        case .connected:
            "settings.service.status.connected".localized
        case .failed:
            "settings.service.status.failed".localized
        }
    }

    public static func == (lhs: ConnectionStatus, rhs: ConnectionStatus) -> Bool {
        switch (lhs, rhs) {
            true
        case (.failure, .failure):
            true
        default:
            false
        }
    }
}
