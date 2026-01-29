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
                    NavigationService.shared.register(openWindow: openWindow)
                    if AppSettingsStore.shared.showSettingsOnLaunch {
                        openWindow(id: "settings")
                    }
                }
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button(NSLocalizedString("settings.title", bundle: .main, comment: "") + "...") {
                    openWindow(id: "settings")
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
    private lazy var floatingIndicatorController = FloatingRecordingIndicatorController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize Monitoring Services
        CrashReporter.shared.setup()
        PerformanceMonitor.shared.startMonitoring()

        setupMenuBar()
        setupContextMenu()
        setupEventMonitor()
        setupGlobalShortcut()

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
        if recordingManager.isRecording {
            await recordingManager.stopRecording(transcribe: true)
            updateStatusIcon(isRecording: false)
        } else {
            await recordingManager.startRecording()
            updateStatusIcon(isRecording: true)
        }
    }

    // MARK: - Menu Bar Setup

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(
                systemSymbolName: "mic.circle", accessibilityDescription: NSLocalizedString("about.title", bundle: .main, comment: "")
            )
            button.action = #selector(handleStatusItemClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
        }

        popover = NSPopover()
        popover?.contentSize = NSSize(width: 320, height: 400)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(
            rootView: MenuBarView()
                .environmentObject(recordingManager)
        )
    }

    private func setupContextMenu() {
        contextMenu = NSMenu()

        // Start/Stop Recording
        let startStopItem = createMenuItem(
            key: "menubar.start_recording",
            action: #selector(toggleRecordingFromMenu)
        )
        startStopMenuItem = startStopItem
        contextMenu?.addItem(startStopItem)

        contextMenu?.addItem(NSMenuItem.separator())

        contextMenu?.addItem(createMenuItem(
            key: "menubar.settings",
            action: #selector(openSettings),
            keyEquivalent: ","
        ))
        contextMenu?.addItem(createMenuItem(
            key: "menubar.check_updates",
            action: #selector(checkForUpdates)
        ))
        contextMenu?.addItem(createMenuItem(
            key: "menubar.quit",
            action: #selector(quitApp),
            keyEquivalent: "q"
        ))
    }

    /// Creates a localized menu item with the given key and action.
    private func createMenuItem(
        key: String,
        action: Selector,
        keyEquivalent: String = ""
    ) -> NSMenuItem {
        let title = NSLocalizedString(key, bundle: localizationBundle, comment: "")
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    private func setupEventMonitor() {
        // Monitor for clicks outside popover to close it
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [
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
            showContextMenu()
        } else {
            togglePopover()
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
        popover?.performClose(nil)

        // Show context menu
        statusItem?.menu = menu
        button.performClick(nil)
        statusItem?.menu = nil // Reset so left-click works again
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
        Task { @MainActor in
            await self.performGracefulShutdown()
        }
    }

    private func performGracefulShutdown() async {
        AppLogger.info("Starting graceful shutdown...", category: .recordingManager)

        // 1. Stop any active recording without triggering transcription
        if recordingManager.isRecording {
            await recordingManager.stopRecording(transcribe: false)
            // Brief delay to ensure file finalization completes
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }

        // 2. Stop monitoring services
        PerformanceMonitor.shared.stopMonitoring()
        CrashReporter.shared.cleanup()

        // 3. Terminate application
        NSApp.terminate(nil)
    }

    // MARK: - Public Methods

    /// Update menu bar icon and menu item based on recording state.
    func updateStatusIcon(isRecording: Bool) {
        let iconName = isRecording ? "record.circle.fill" : "mic.circle"
        let accessibilityKey = isRecording ? "menubar.accessibility.recording" : "menubar.accessibility.idle"
        let accessibilityDesc = NSLocalizedString(
            accessibilityKey,
            bundle: localizationBundle,
            comment: ""
        )

        let config = NSImage.SymbolConfiguration(paletteColors: isRecording ? [.systemRed] : [.headerTextColor])
        let image = NSImage(systemSymbolName: iconName, accessibilityDescription: accessibilityDesc)?
            .withSymbolConfiguration(config)

        statusItem?.button?.image = image

        // Update menu item title
        let key = isRecording ? "menubar.stop_recording" : "menubar.start_recording"
        startStopMenuItem?.title = NSLocalizedString(
            key,
            bundle: localizationBundle,
            comment: ""
        )

        // Show/hide floating recording indicator
        if isRecording {
            floatingIndicatorController.show()
        } else {
            floatingIndicatorController.hide()
        }
    }
}
