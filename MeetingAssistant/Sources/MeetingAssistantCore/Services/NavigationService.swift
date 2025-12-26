import SwiftUI

/// Service to handle navigation and window management across the app.
@MainActor
public class NavigationService: ObservableObject {
    public static let shared = NavigationService()

    /// Reference to the SwiftUI openWindow action.
    /// This is injected by a view that has access to the environment.
    public var openWindow: OpenWindowAction?

    private init() {}

    /// Opens the settings/dashboard window.
    public func openSettings() {
        if let openWindow = self.openWindow {
            openWindow(id: "settings")
        } else {
            // Fallback for when the environment action is not yet available
            // This can happen if called before the first view appears.
            // In AppKit, we can try to send the action to the responder chain as a last resort.
            NSApp.activate(ignoringOtherApps: true)
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
    }
}
