import AppKit
import Combine
import KeyboardShortcuts
import MeetingAssistantCore
import os
import SwiftUI

/// Main entry point for the Meeting Assistant app.
/// Runs as a menu bar application without a dock icon.
@main
struct MeetingAssistantApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup("settings.title".localized, id: "settings") {
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
                Button("settings.title".localized + "...") {
                    if let existingWindow = NSApp.windows.first(where: { $0.identifier?.rawValue == "settings" }) {
                        existingWindow.makeKeyAndOrderFront(nil)
                        NSApp.activate(ignoringOtherApps: true)
                    } else {
                        openWindow(id: "settings")
                        NSApp.activate(ignoringOtherApps: true)
                    }
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
    private var dictateMenuItem: NSMenuItem?
    private var recordMeetingMenuItem: NSMenuItem?
    private var assistantMenuItem: NSMenuItem?
    private lazy var recordingManager: RecordingManager = .shared
    private var eventMonitor: Any?
    private lazy var floatingIndicatorController = FloatingRecordingIndicatorController()
    private lazy var globalShortcutController = GlobalShortcutController(recordingManager: RecordingManager.shared)
    private lazy var assistantVoiceCommandService = AssistantVoiceCommandService(
        indicator: floatingIndicatorController
    )
    private lazy var assistantShortcutController = AssistantShortcutController(
        assistantService: assistantVoiceCommandService
    )
    private var cancellables = Set<AnyCancellable>()
    private var dockObserver: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize Monitoring Services
        CrashReporter.shared.setup()
        PerformanceMonitor.shared.startMonitoring()

        // One-time migration: legacy JSON → Core Data
        Task {
            await FileSystemStorageService.shared.migrateLegacyJSONTranscriptionsToCoreDataIfNeeded()
        }

        setupMenuBar()
        setupContextMenu()
        setupEventMonitor()
        globalShortcutController.start()
        assistantShortcutController.start()
        setupRecordingObservation()
        updateMenuTitles() // Initial update

        // Warmup transcription model
        Task { @MainActor in
            do {
                try await TranscriptionClient.shared.warmupModel()
            } catch {
                self.logger.error("Failed to warmup model: \(error.localizedDescription)")
            }
        }

        // Run auto-cleanup logic
        Task {
            await performCleanup()
        }

        // Set initial activation policy based on user settings
        applyDockVisibility(AppSettingsStore.shared.showInDock)

        // Observe changes to dock visibility setting
        dockObserver = AppSettingsStore.shared.$showInDock
            .dropFirst() // Skip initial value (already applied above)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] showInDock in
                self?.applyDockVisibility(showInDock)
            }
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

    private func setupRecordingObservation() {
        recordingManager.isRecordingPublisher
            .combineLatest(
                recordingManager.isTranscribingPublisher,
                assistantVoiceCommandService.$isRecording,
                recordingManager.currentMeetingPublisher
            )
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRecording, isTranscribing, isAssistantRecording, currentMeeting in
                self?.updateStatusIcon(isRecording: isRecording || isAssistantRecording)
                self?.updateFloatingIndicator(
                    isRecording: isRecording || isAssistantRecording,
                    isTranscribing: isTranscribing,
                    meetingType: currentMeeting?.type
                )
                self?.updateMenuTitles()
            }
            .store(in: &cancellables)
    }

    /// Toggle recording state when global shortcut is activated.
    private func startRecording(source: RecordingSource) async {
        if recordingManager.isRecording {
            await recordingManager.stopRecording(transcribe: true)
        } else {
            await recordingManager.startRecording(source: source)
        }
    }

    // MARK: - Menu Bar Setup

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(
                systemSymbolName: "waveform",
                accessibilityDescription: "about.title".localized
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

        // Dictate (Mic Only)
        let dictateItem = createMenuItem(
            key: "menubar.dictate",
            action: #selector(toggleRecordingFromMenu),
            shortcutName: .dictationToggle
        )
        dictateMenuItem = dictateItem
        contextMenu?.addItem(dictateItem)

        // Record Meeting (Recorder)
        let meetingItem = createMenuItem(
            key: "menubar.record_meeting",
            action: #selector(startMeetingFromMenu),
            shortcutName: .meetingToggle
        )
        recordMeetingMenuItem = meetingItem
        contextMenu?.addItem(meetingItem)

        // Assistant
        let assistantItem = createMenuItem(
            key: "menubar.assistant",
            action: #selector(startAssistantFromMenu),
            shortcutName: .assistantCommand
        )
        assistantMenuItem = assistantItem
        contextMenu?.addItem(assistantItem)

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
        keyEquivalent: String = "",
        shortcutName: KeyboardShortcuts.Name? = nil
    ) -> NSMenuItem {
        let title = key.localized
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self

        if let shortcutName {
            applyShortcut(to: item, title: title, shortcutName: shortcutName)
        }

        return item
    }

    private func updateMenuTitles() {
        // Update Dictate
        let dictateKey = recordingManager.dictationMenuKey
        updateMenuItem(dictateMenuItem, key: dictateKey, shortcutName: .dictationToggle)

        // Update Meeting
        let meetingKey = recordingManager.meetingMenuKey
        updateMenuItem(recordMeetingMenuItem, key: meetingKey, shortcutName: .meetingToggle)

        // Update Assistant
        let isAssistantRecording = assistantVoiceCommandService.isRecording
        let assistantKey = isAssistantRecording ? "menubar.stop_assistant" : "menubar.assistant"
        updateMenuItem(assistantMenuItem, key: assistantKey, shortcutName: .assistantCommand)
    }

    private func updateMenuItem(_ item: NSMenuItem?, key: String, shortcutName: KeyboardShortcuts.Name) {
        let title = key.localized
        if let item {
            applyShortcut(to: item, title: title, shortcutName: shortcutName)
        }
    }

    private func applyShortcut(to item: NSMenuItem, title: String, shortcutName: KeyboardShortcuts.Name) {
        let settings = AppSettingsStore.shared
        var presetString: String?
        var isCustom = false

        if shortcutName == .dictationToggle {
            if settings.dictationSelectedPresetKey != .custom, settings.dictationSelectedPresetKey != .notSpecified {
                presetString = settings.dictationSelectedPresetKey.displayName
            } else {
                isCustom = true
            }
        } else if shortcutName == .assistantCommand {
            if settings.assistantSelectedPresetKey != .custom, settings.assistantSelectedPresetKey != .notSpecified {
                presetString = settings.assistantSelectedPresetKey.displayName
            } else {
                isCustom = true
            }
        } else if shortcutName == .meetingToggle {
            if settings.meetingSelectedPresetKey != .custom, settings.meetingSelectedPresetKey != .notSpecified {
                presetString = settings.meetingSelectedPresetKey.displayName
            } else {
                isCustom = true
            }
        }

        if let presetString {
            item.title = "\(title) [\(presetString)]"
            item.keyEquivalent = ""
            item.keyEquivalentModifierMask = []
        } else if isCustom, let shortcut = KeyboardShortcuts.Shortcut(name: shortcutName) {
            item.title = title

            // Robust key equivalent handling
            let desc = shortcut.description
            let modifierSymbols = ["⌘", "⌥", "⌃", "⇧"]
            var cleanKey = desc
            for symbol in modifierSymbols {
                cleanKey = cleanKey.replacingOccurrences(of: symbol, with: "")
            }
            cleanKey = cleanKey.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            // Map special key descriptions back to NSMenuItem key equivalents
            switch cleanKey {
            case "space": item.keyEquivalent = " "
            case "return", "enter": item.keyEquivalent = "\r"
            case "tab": item.keyEquivalent = "\t"
            case "backspace", "delete": item.keyEquivalent = String(UnicodeScalar(NSBackspaceCharacter)!)
            case "escape", "esc": item.keyEquivalent = "\u{1b}"
            case "left": item.keyEquivalent = String(UnicodeScalar(NSLeftArrowFunctionKey)!)
            case "right": item.keyEquivalent = String(UnicodeScalar(NSRightArrowFunctionKey)!)
            case "up": item.keyEquivalent = String(UnicodeScalar(NSUpArrowFunctionKey)!)
            case "down": item.keyEquivalent = String(UnicodeScalar(NSDownArrowFunctionKey)!)
            default:
                // For regular keys, use the first character of the stripped string
                item.keyEquivalent = String(cleanKey.prefix(1))
            }

            item.keyEquivalentModifierMask = shortcut.modifiers
        } else {
            item.title = title
            item.keyEquivalent = ""
            item.keyEquivalentModifierMask = []
        }
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

        // Update shortcuts/titles before showing
        updateMenuTitles()

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
            // Default "Dictation" mode (Mic Only)
            await self.startRecording(source: .microphone)
        }
    }

    @objc private func startMeetingFromMenu() {
        Task { @MainActor in
            // Meeting mode (System + Mic) permissions will be checked by manager
            await self.startRecording(source: .all)
        }
    }

    @objc private func startAssistantFromMenu() {
        Task {
            if assistantVoiceCommandService.isRecording {
                await assistantVoiceCommandService.stopAndProcess()
            } else {
                await assistantVoiceCommandService.startRecording()
            }
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

    private func performCleanup() async {
        if AppSettingsStore.shared.autoDeleteTranscriptions {
            let days = AppSettingsStore.shared.autoDeletePeriodDays
            do {
                try await FileSystemStorageService.shared.cleanupOldTranscriptions(olderThanDays: days)
            } catch {
                logger.error("Failed to perform auto-cleanup: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Public Methods

    /// Update menu bar icon and menu item based on recording state.
    func updateStatusIcon(isRecording: Bool) {
        let iconName = isRecording ? "record.circle.fill" : "waveform"
        let accessibilityKey = isRecording ? "menubar.accessibility.recording" : "menubar.accessibility.idle"
        let accessibilityDesc = accessibilityKey.localized

        let config = NSImage.SymbolConfiguration(paletteColors: isRecording ? [.systemRed] : [.headerTextColor])
        let image = NSImage(systemSymbolName: iconName, accessibilityDescription: accessibilityDesc)?
            .withSymbolConfiguration(config)

        statusItem?.button?.image = image
    }

    private func updateFloatingIndicator(isRecording: Bool, isTranscribing: Bool, meetingType: MeetingType? = nil) {
        if isRecording {
            floatingIndicatorController.show(mode: .recording, type: meetingType)
        } else if isTranscribing {
            floatingIndicatorController.show(mode: .processing, type: meetingType)
        } else {
            floatingIndicatorController.hide()
        }
    }

    /// Applies the dock visibility setting by changing the app's activation policy.
    /// - Parameter showInDock: If true, shows the app in Dock and Cmd+Tab switcher.
    private func applyDockVisibility(_ showInDock: Bool) {
        let policy: NSApplication.ActivationPolicy = showInDock ? .regular : .accessory
        NSApp.setActivationPolicy(policy)
        logger.info("Activation policy set to: \(showInDock ? "regular (dock)" : "accessory (menu bar only)")")
    }
}
