import AppKit
@preconcurrency import ApplicationServices
import Foundation
import MeetingAssistantCoreDomain

@MainActor
public enum InputMonitoringPermissionService {
    public static func currentState() -> PermissionState {
        isTrusted() ? .granted : .denied
    }

    @discardableResult
    public static func requestPermission() -> Bool {
        withUnsafeCurrentTask { _ in
            CGRequestListenEventAccess()
        }
    }

    public static func openSystemSettings() {
        if let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
        ) {
            NSWorkspace.shared.open(url)
        }
    }

    public static func isTrusted() -> Bool {
        withUnsafeCurrentTask { _ in
            CGPreflightListenEventAccess()
        }
    }
}
