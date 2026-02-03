import AppKit
import Foundation

@_silgen_name("AXIsProcessTrusted")
private func AXIsProcessTrusted() -> Bool

@_silgen_name("AXIsProcessTrustedWithOptions")
private func AXIsProcessTrustedWithOptions(_ options: CFDictionary?) -> Bool

@MainActor
public enum AccessibilityPermissionService {
    public static func currentState() -> PermissionState {
        AXIsProcessTrusted() ? .granted : .denied
    }

    public static func requestPermission() {
        let options = ["AXTrustedCheckOptionPrompt" as CFString: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    public static func openSystemSettings() {
        if let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) {
            NSWorkspace.shared.open(url)
        }
    }
}
