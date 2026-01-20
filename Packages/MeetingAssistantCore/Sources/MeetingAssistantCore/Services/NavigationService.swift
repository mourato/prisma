import SwiftUI

/// Service to handle navigation and window management across the app.
@MainActor
public class NavigationService: ObservableObject {
    public static let shared = NavigationService()

    /// Reference to the SwiftUI openWindow action.
    public private(set) var openWindow: OpenWindowAction?

    private init() {}

    /// Registers the openWindow action from the SwiftUI environment.
    public func register(openWindow: OpenWindowAction) {
        self.openWindow = openWindow
    }

    /// Opens the settings/dashboard window.
    public func openSettings() {
        // First check if the window is already open
        if let existingWindow = NSApp.windows.first(where: { $0.identifier?.rawValue == "settings" }) {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        if let openWindow {
            openWindow(id: "settings")
            NSApp.activate(ignoringOtherApps: true)
        } else {
            // Fallback for app startup or when environment isn't bridged yet
            NSApp.activate(ignoringOtherApps: true)
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
    }

    /// Shows the About alert.
    public func showAbout() {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("about.title", bundle: .safeModule, comment: "")
        alert.informativeText = String(
            format: NSLocalizedString("about.version", bundle: .safeModule, comment: ""),
            AppVersion.current
        ) + "\n\n" +
            NSLocalizedString("about.description", bundle: .safeModule, comment: "") + "\n\n" +
            String(format: NSLocalizedString("about.copyright", bundle: .safeModule, comment: ""), 2_025)
        alert.alertStyle = .informational
        alert.icon = NSImage(
            systemSymbolName: "waveform.circle.fill",
            accessibilityDescription: NSLocalizedString("about.title", bundle: .safeModule, comment: "")
        )
        alert.addButton(withTitle: NSLocalizedString("common.ok", bundle: .safeModule, comment: ""))

        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    /// Checks for updates (static placeholder for now).
    public func checkForUpdates() {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("updates.check_title", bundle: .safeModule, comment: "")
        alert.informativeText = NSLocalizedString("updates.latest_version", bundle: .safeModule, comment: "")
        alert.alertStyle = .informational
        alert.addButton(withTitle: NSLocalizedString("common.ok", bundle: .safeModule, comment: ""))

        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
