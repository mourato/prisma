import AppKit
import Combine
import MeetingAssistantCoreCommon

/// Service to handle navigation and window management across the app.
@MainActor
public class NavigationService: ObservableObject {
    public static let shared = NavigationService()

    @Published public var requestedSettingsSection: String?
    private var openSettingsHandler: (@MainActor () -> Void)?

    private init() {}

    /// Registers an explicit settings opener provided by the app target.
    public func registerOpenSettingsHandler(_ handler: @escaping @MainActor () -> Void) {
        openSettingsHandler = handler
    }

    /// Opens the settings/dashboard window.
    public func openSettings() {
        if let openSettingsHandler {
            openSettingsHandler()
            return
        }

        let previousPolicy = NSApp.activationPolicy()
        if previousPolicy == .accessory {
            NSApp.setActivationPolicy(.regular)
        }

        NSApp.activate(ignoringOtherApps: true)

        let openSettingsSelector = Selector(("openSettings:"))
        let legacySettingsSelector = Selector(("show" + "SettingsWindow:"))
        let legacyPreferencesSelector = Selector(("show" + "PreferencesWindow:"))

        let opened = NSApp.sendAction(openSettingsSelector, to: nil, from: nil)
            || NSApp.sendAction(legacySettingsSelector, to: nil, from: nil)
            || NSApp.sendAction(legacyPreferencesSelector, to: nil, from: nil)

        if previousPolicy == .accessory {
            let restoreDelay: TimeInterval = opened ? 0.5 : 0.1
            DispatchQueue.main.asyncAfter(deadline: .now() + restoreDelay) {
                NSApp.setActivationPolicy(.accessory)
            }
        }
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

    /// Triggers a user-initiated update check via Sparkle.
    public func checkForUpdates() {
        UpdateService.shared.checkForUpdates()
    }
}
