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

        if let openWindow = self.openWindow {
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
        alert.messageText = "Meeting Assistant"
        alert.informativeText = """
        Versão 0.1.1

        Transcreva suas reuniões de vídeo automaticamente usando IA.

        © 2025 Todos os direitos reservados.
        """
        alert.alertStyle = .informational
        alert.icon = NSImage(
            systemSymbolName: "waveform.circle.fill", accessibilityDescription: "Meeting Assistant"
        )
        alert.addButton(withTitle: "OK")

        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    /// Checks for updates (static placeholder for now).
    public func checkForUpdates() {
        let alert = NSAlert()
        alert.messageText = "Verificar Atualizações"
        alert.informativeText = "Você está usando a versão mais recente do Meeting Assistant."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")

        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
