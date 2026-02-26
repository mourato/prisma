import AppKit
import Combine
import MeetingAssistantCoreCommon

/// Service to handle navigation and window management across the app.
@MainActor
public class NavigationService: ObservableObject {
    public static let shared = NavigationService()

    @Published public var requestedSettingsSection: String?

    private init() {}

    /// Opens the settings/dashboard window.
    public func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    /// Opens the settings window and requests a specific section.
    public func openSettings(section: String) {
        requestedSettingsSection = section
        openSettings()
    }

    /// Shows the About alert.
    public func showAbout() {
        let alert = NSAlert()
        alert.messageText = "about.title".localized
        alert.informativeText =
            "about.version".localized(with: AppVersion.current) + "\n\n" +
            "about.description".localized + "\n\n" +
            "about.copyright".localized(with: 2_025)
        alert.alertStyle = .informational
        alert.icon = NSImage(
            systemSymbolName: "waveform.circle.fill",
            accessibilityDescription: "about.title".localized
        )
        alert.addButton(withTitle: "common.ok".localized)

        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    /// Checks for updates (static placeholder for now).
    public func checkForUpdates() {
        let alert = NSAlert()
        alert.messageText = "updates.check_title".localized
        alert.informativeText = "updates.latest_version".localized
        alert.alertStyle = .informational
        alert.addButton(withTitle: "common.ok".localized)

        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
