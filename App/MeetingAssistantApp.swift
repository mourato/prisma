import KeyboardShortcuts
import MeetingAssistantCore
import SwiftUI

import os

/// Main entry point for the Meeting Assistant app.
/// Runs as a menu bar application without a dock icon.
@main
struct MeetingAssistantApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup(NSLocalizedString("settings.title", bundle: .main, comment: ""), id: "settings") {
            SettingsView()
                .onAppear {
                    NavigationService.shared.register(openWindow: self.openWindow)
                    if AppSettingsStore.shared.showSettingsOnLaunch {
                        self.openWindow(id: "settings")
                    }
                }
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button(NSLocalizedString("settings.title", bundle: .main, comment: "") + "...") {
                    self.openWindow(id: "settings")
                    NSApp.activate(ignoringOtherApps: true)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}

/// App delegate for menu bar setup and lifecycle management.
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: "MeetingAssistant", category: "AppDelegate")
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var contextMenu: NSMenu?
    private var startStopMenuItem: NSMenuItem?
    private lazy var recordingManager: RecordingManager = .shared
    private lazy var localizationBundle: Bundle = .safeModule
    private var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        self.setupMenuBar()
        self.setupContextMenu()
        self.setupEventMonitor()
        self.setupGlobalShortcut()

        // Warmup transcription model
        Task {
            do {
                try await TranscriptionClient.shared.warmupModel()
            } catch {
                self.logger.error("Failed to warmup model: \(error.localizedDescription)")
            }
        }

        // Hide dock icon for menu bar only app
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    // MARK: - Document Handling (Disabled for Menu Bar App)

    /// Prevent the app from reopening windows when activated.
    /// This is critical for menu bar-only apps in SPM builds.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Do not create new windows when app is reactivated
        false
    }

    /// Prevent the app from opening untitled files on launch.
    /// Without this, AppKit calls this method and crashes in SPM builds.
    func applicationOpenUntitledFile(_ sender: NSApplication) -> Bool {
        // Menu bar apps don't open documents
        true
    }

    /// Prevent app from prompting to open a new document.
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        false
    }

    // MARK: - Global Shortcut Setup

    private func setupGlobalShortcut() {
        // Configure shortcut callback to toggle recording
        KeyboardShortcuts.onKeyUp(for: .toggleRecording) { [weak self] in
            Task { @MainActor in
                await self?.toggleRecording()
            }
        }
    }

    /// Toggle recording state when global shortcut is activated.
    private func toggleRecording() async {
        if self.recordingManager.isRecording {
            await self.recordingManager.stopRecording(transcribe: true)
            self.updateStatusIcon(isRecording: false)
        } else {
            await self.recordingManager.startRecording()
            self.updateStatusIcon(isRecording: true)
        }
    }

    // MARK: - Menu Bar Setup

    private func setupMenuBar() {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(
                systemSymbolName: "mic.circle", accessibilityDescription: NSLocalizedString("about.title", bundle: .main, comment: "")
            )
            button.action = #selector(self.handleStatusItemClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
        }

        self.popover = NSPopover()
        self.popover?.contentSize = NSSize(width: 320, height: 400)
        self.popover?.behavior = .transient
        self.popover?.contentViewController = NSHostingController(
            rootView: MenuBarView()
                .environmentObject(self.recordingManager)
        )
    }

    private func setupContextMenu() {
        self.contextMenu = NSMenu()

        // Start/Stop Recording
        let startStopItem = self.createMenuItem(
            key: "menubar.start_recording",
            action: #selector(self.toggleRecordingFromMenu)
        )
        self.startStopMenuItem = startStopItem
        self.contextMenu?.addItem(startStopItem)

        self.contextMenu?.addItem(NSMenuItem.separator())

        self.contextMenu?.addItem(self.createMenuItem(
            key: "menubar.settings",
            action: #selector(self.openSettings),
            keyEquivalent: ","
        ))
        self.contextMenu?.addItem(self.createMenuItem(
            key: "menubar.check_updates",
            action: #selector(self.checkForUpdates)
        ))
        self.contextMenu?.addItem(self.createMenuItem(
            key: "menubar.quit",
            action: #selector(self.quitApp),
            keyEquivalent: "q"
        ))
    }

    /// Creates a localized menu item with the given key and action.
    private func createMenuItem(
        key: String,
        action: Selector,
        keyEquivalent: String = ""
    ) -> NSMenuItem {
        let title = NSLocalizedString(key, bundle: self.localizationBundle, comment: "")
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    private func setupEventMonitor() {
        // Monitor for clicks outside popover to close it
        self.eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [
            .leftMouseDown, .rightMouseDown,
        ]) { [weak self] _ in
            if self?.popover?.isShown == true {
                self?.popover?.performClose(nil)
            }
        }
    }

    // MARK: - Click Handling

    @objc private func handleStatusItemClick() {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            self.showContextMenu()
        } else {
            self.togglePopover()
        }
    }

    private func togglePopover() {
        guard let popover, let button = statusItem?.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            DispatchQueue.main.async {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                popover.contentViewController?.view.window?.makeKey()
            }
        }
    }

    private func showContextMenu() {
        guard let menu = contextMenu, let button = statusItem?.button else { return }

        // Close popover if open
        self.popover?.performClose(nil)

        // Show context menu
        self.statusItem?.menu = menu
        button.performClick(nil)
        self.statusItem?.menu = nil // Reset so left-click works again
    }

    // MARK: - Menu Actions

    @objc private func openSettings() {
        NavigationService.shared.openSettings()
    }

    @objc private func toggleRecordingFromMenu() {
        Task { @MainActor in
            await self.toggleRecording()
        }
    }

    @objc private func checkForUpdates() {
        NavigationService.shared.checkForUpdates()
    }

    @objc private func quitApp() {
        // Stop any ongoing recording before quitting
        if self.recordingManager.isRecording {
            Task {
                await self.recordingManager.stopRecording(transcribe: false)
                NSApp.terminate(nil)
            }
        } else {
            NSApp.terminate(nil)
        }
    }

    // MARK: - Public Methods

    /// Update menu bar icon and menu item based on recording state.
    func updateStatusIcon(isRecording: Bool) {
        let iconName = isRecording ? "record.circle.fill" : "mic.circle"
        let accessibilityKey = isRecording ? "menubar.accessibility.recording" : "menubar.accessibility.idle"
        let accessibilityDesc = NSLocalizedString(
            accessibilityKey,
            bundle: self.localizationBundle,
            comment: ""
        )
        self.statusItem?.button?.image = NSImage(
            systemSymbolName: iconName,
            accessibilityDescription: accessibilityDesc
        )

        // Update menu item title
        let key = isRecording ? "menubar.stop_recording" : "menubar.start_recording"
        self.startStopMenuItem?.title = NSLocalizedString(
            key,
            bundle: self.localizationBundle,
            comment: ""
        )
    }
}
