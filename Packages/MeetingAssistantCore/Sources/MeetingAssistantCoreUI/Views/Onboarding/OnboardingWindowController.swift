import AppKit
import MeetingAssistantCoreAI
import SwiftUI

// MARK: - Onboarding Window Controller

/// Manages the dedicated onboarding window with modal presentation.
@MainActor
public class OnboardingWindowController {
    private var window: NSWindow?

    public init() {}

    /// Shows the onboarding window as a modal sheet over the main app.
    public func showOnboarding(
        viewModel: OnboardingViewModel,
        permissionViewModel: PermissionViewModel,
        shortcutViewModel: ShortcutSettingsViewModel,
        assistantShortcutViewModel: AssistantShortcutSettingsViewModel,
        modelManager: FluidAIModelManager,
        refreshPermissions: @escaping @MainActor () async -> Void,
        completion: @escaping () -> Void
    ) {
        // Create the onboarding view with all dependencies
        let onboardingView = OnboardingView(
            viewModel: viewModel,
            permissionViewModel: permissionViewModel,
            shortcutViewModel: shortcutViewModel,
            assistantShortcutViewModel: assistantShortcutViewModel,
            modelManager: modelManager,
            refreshPermissions: refreshPermissions,
            onComplete: { [weak self] in
                self?.closeOnboarding()
                completion()
            }
        )

        // Create window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 650, height: 550),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = "onboarding.title".localized
        window.contentView = NSHostingView(rootView: onboardingView)
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = WindowDelegate.shared

        // Style the window
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)

        // Prevent resizing
        window.styleMask.remove(.resizable)

        // Make it modal
        if let mainWindow = NSApplication.shared.mainWindow {
            mainWindow.beginSheet(window) { _ in
                // Sheet closed
            }
        } else {
            window.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
        }

        self.window = window
    }

    /// Closes the onboarding window.
    public func closeOnboarding() {
        guard let window else { return }

        if let mainWindow = NSApplication.shared.mainWindow {
            if mainWindow.sheets.contains(window) {
                mainWindow.endSheet(window)
            } else {
                window.close()
            }
        } else {
            window.close()
        }

        self.window = nil
    }
}

// MARK: - Window Delegate

@MainActor
private class WindowDelegate: NSObject, NSWindowDelegate, @unchecked Sendable {
    static let shared = WindowDelegate()

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Prevent closing via the red button during onboarding
        // User must complete or skip all steps
        false
    }
}
