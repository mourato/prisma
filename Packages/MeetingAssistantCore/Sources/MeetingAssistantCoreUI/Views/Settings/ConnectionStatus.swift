import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
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
        case .testing: AppDesignSystem.Colors.warning
        case .success: AppDesignSystem.Colors.success
        case .failure: AppDesignSystem.Colors.error
        }
    }

    public var text: String {
        switch self {
        case .unknown:
            "settings.service.status.not_tested".localized
        case .testing:
            "settings.service.status.testing".localized
        case .success:
            "settings.service.status.connected".localized
        case .failure:
            "settings.service.status.failed".localized
        }
    }

    public var detail: String? {
        switch self {
        case let .failure(message):
            message
        case .unknown, .testing, .success:
            nil
        }
    }
}
