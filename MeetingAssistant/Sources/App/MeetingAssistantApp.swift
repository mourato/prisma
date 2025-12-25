import SwiftUI

/// Main entry point for the Meeting Assistant app.
/// Runs as a menu bar application without a dock icon.
@main
struct MeetingAssistantApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Menu bar app - no main window
        Settings {
            SettingsView()
        }
    }
}

/// App delegate for menu bar setup and lifecycle management.
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var recordingManager = RecordingManager.shared
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        
        // Hide dock icon for menu bar only app
        NSApp.setActivationPolicy(.accessory)
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "mic.circle", accessibilityDescription: "Meeting Assistant")
            button.action = #selector(togglePopover)
        }
        
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 320, height: 400)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(
            rootView: MenuBarView()
                .environmentObject(recordingManager)
        )
    }
    
    @objc private func togglePopover() {
        guard let popover = popover, let button = statusItem?.button else { return }
        
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
    
    /// Update menu bar icon based on recording state.
    func updateStatusIcon(isRecording: Bool) {
        let iconName = isRecording ? "record.circle.fill" : "mic.circle"
        statusItem?.button?.image = NSImage(
            systemSymbolName: iconName,
            accessibilityDescription: isRecording ? "Recording" : "Meeting Assistant"
        )
    }
}
