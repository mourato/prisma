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
        if let openWindow = self.openWindow {
            openWindow(id: "settings")
            NSApp.activate(ignoringOtherApps: true)
        } else {
            // Fallback for app startup or when environment isn't bridged yet
            NSApp.activate(ignoringOtherApps: true)
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
    }
}
