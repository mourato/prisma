import Foundation
import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain

public enum TextContextLogger {
    public static func logFailure(bundleIdentifier: String, reason: ContextAcquisitionError) {
        AppLogger.warning(
            "Text context capture failed",
            category: .recordingManager,
            extra: [
                "bundle_id": bundleIdentifier,
                "reason": reason.logValue,
            ]
        )
    }
}

private extension ContextAcquisitionError {
    var logValue: String {
        switch self {
        case .permissionDenied:
            return "permissionDenied"
        case .noActiveApp:
            return "noActiveApp"
        case .noFocusedElement:
            return "noFocusedElement"
        case .accessibilityUnsupported:
            return "accessibilityUnsupported"
        case .excludedApp:
            return "excludedApp"
        case .providerFailed:
            return "providerFailed"
        }
    }
}
