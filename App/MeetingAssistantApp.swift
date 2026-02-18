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

private extension ShortcutDefinition {
    var menuDisplayString: String {
        let modifierSymbols = modifiers.map { modifier in
            switch modifier {
            case .leftCommand, .rightCommand, .command: "⌘"
            case .leftShift, .rightShift, .shift: "⇧"
            case .leftOption, .rightOption, .option: "⌥"
            case .leftControl, .rightControl, .control: "⌃"
            case .fn: "Fn"
            }
        }

        var tokens = modifierSymbols
        if let primaryKey {
            tokens.append(primaryKey.display)
        } else if trigger == .doubleTap, let first = modifierSymbols.first {
            tokens.append(first)
        }

        return tokens.joined()
    }
}

/// App delegate for menu bar setup and lifecycle management.
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private struct RecordingUIRenderState: Equatable {
        let isRecording: Bool
        let isStarting: Bool
        let isTranscribing: Bool
        let isAssistantRecording: Bool
        let meetingTypeRawValue: String?
    }

    private let logger = Logger(subsystem: "MeetingAssistant", category: "AppDelegate")
    private var statusItem: NSStatusItem?
    private var contextMenu: NSMenu?
    private var dictateMenuItem: NSMenuItem?
    private var recordMeetingMenuItem: NSMenuItem?
    private var assistantMenuItem: NSMenuItem?
    private lazy var recordingManager: RecordingManager = .shared
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
    private var lastRecordingUIRenderState: RecordingUIRenderState?

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
        globalShortcutController.start()
        assistantShortcutController.start()
        setupRecordingObservation()
        floatingIndicatorController.prewarm()
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

    func applicationWillTerminate(_ notification: Notification) {}

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
        Publishers.MergeMany(
            recordingManager.isRecordingPublisher.map { _ in () }.eraseToAnyPublisher(),
            recordingManager.isStartingPublisher.map { _ in () }.eraseToAnyPublisher(),
            recordingManager.isTranscribingPublisher.map { _ in () }.eraseToAnyPublisher(),
            assistantVoiceCommandService.$isRecording.map { _ in () }.eraseToAnyPublisher(),
            recordingManager.currentMeetingPublisher.map { _ in () }.eraseToAnyPublisher()
        )
            .sink { [weak self] _ in
                self?.refreshRecordingUIState()
            }
            .store(in: &cancellables)

        refreshRecordingUIState()
    }

    private func refreshRecordingUIState() {
        let isRecording = recordingManager.isRecording
        let isStarting = recordingManager.isStartingRecording
        let isTranscribing = recordingManager.isTranscribing
        let isAssistantRecording = assistantVoiceCommandService.isRecording
        let currentMeetingType = recordingManager.currentMeeting?.type
        let renderState = RecordingUIRenderState(
            isRecording: isRecording,
            isStarting: isStarting,
            isTranscribing: isTranscribing,
            isAssistantRecording: isAssistantRecording,
            meetingTypeRawValue: currentMeetingType?.rawValue
        )

        guard renderState != lastRecordingUIRenderState else {
            return
        }
        lastRecordingUIRenderState = renderState

        updateStatusIcon(isRecording: isRecording || isAssistantRecording || isStarting)
        updateFloatingIndicator(
            isRecording: isRecording || isAssistantRecording,
            isAssistantRecording: isAssistantRecording,
            isStarting: isStarting,
            isTranscribing: isTranscribing,
            meetingType: currentMeetingType
        )

        if (isRecording || isStarting),
           AppSettingsStore.shared.recordingIndicatorEnabled,
           AppSettingsStore.shared.recordingIndicatorStyle != .none
        {
            recordingManager.noteIndicatorShownForStartIfNeeded()
        }

        updateMenuTitles()
    }

    /// Toggle recording state when global shortcut is activated.
    private func startRecording(source: RecordingSource) async {
        if recordingManager.isRecording {
            await recordingManager.stopRecording(transcribe: true)
        } else {
            let triggerLabel = source == .microphone ? "menu.dictation" : "menu.meeting"
            await recordingManager.startRecording(
                source: source,
                requestedAt: Date(),
                triggerLabel: triggerLabel
            )
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
            key: "menubar.history",
            action: #selector(openHistory),
            systemImage: SettingsSection.transcriptions.icon
        ))

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
        shortcutName: KeyboardShortcuts.Name? = nil,
        systemImage: String? = nil
    ) -> NSMenuItem {
        let title = key.localized
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        if let systemImage {
            item.image = NSImage(
                systemSymbolName: systemImage,
                accessibilityDescription: title
            )
            item.image?.isTemplate = true
        }

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
        var inHouseShortcut: ShortcutDefinition?
        var isCustom = false

        if shortcutName == .dictationToggle {
            if let definition = settings.dictationShortcutDefinition {
                inHouseShortcut = definition
                isCustom = false
            } else if settings.dictationModifierShortcutGesture != nil {
                isCustom = false
            } else if settings.dictationSelectedPresetKey != .custom, settings.dictationSelectedPresetKey != .notSpecified {
                presetString = settings.dictationSelectedPresetKey.displayName
            } else {
                isCustom = true
            }
        } else if shortcutName == .assistantCommand {
            if let definition = settings.assistantShortcutDefinition {
                inHouseShortcut = definition
                isCustom = false
            } else if settings.assistantModifierShortcutGesture != nil {
                isCustom = false
            } else if settings.assistantSelectedPresetKey != .custom, settings.assistantSelectedPresetKey != .notSpecified {
                presetString = settings.assistantSelectedPresetKey.displayName
            } else {
                isCustom = true
            }
        } else if shortcutName == .meetingToggle {
            if let definition = settings.meetingShortcutDefinition {
                inHouseShortcut = definition
                isCustom = false
            } else if settings.meetingModifierShortcutGesture != nil {
                isCustom = false
            } else if settings.meetingSelectedPresetKey != .custom, settings.meetingSelectedPresetKey != .notSpecified {
                presetString = settings.meetingSelectedPresetKey.displayName
            } else {
                isCustom = true
            }
        }

        if let inHouseShortcut {
            if applyShortcutDefinition(inHouseShortcut, to: item, title: title) {
                return
            }
            item.title = "\(title) [\(inHouseShortcut.menuDisplayString)]"
            clearShortcut(from: item)
        } else if let presetString {
            item.title = "\(title) [\(presetString)]"
            clearShortcut(from: item)
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
            clearShortcut(from: item)
        }
    }

    private func applyShortcutDefinition(
        _ shortcut: ShortcutDefinition,
        to item: NSMenuItem,
        title: String
    ) -> Bool {
        guard shortcut.trigger == .singleTap,
              let primaryKey = shortcut.primaryKey,
              let keyEquivalent = keyEquivalent(for: primaryKey)
        else {
            return false
        }

        item.title = title
        item.keyEquivalent = keyEquivalent
        item.keyEquivalentModifierMask = modifierMask(from: shortcut.modifiers)
        return true
    }

    private func keyEquivalent(for primaryKey: ShortcutPrimaryKey) -> String? {
        switch primaryKey.kind {
        case .space:
            return " "
        case .function:
            guard let functionIndex = primaryKey.functionIndex else {
                return nil
            }
            let scalarValue = Int(NSF1FunctionKey) + functionIndex - 1
            guard let scalar = UnicodeScalar(scalarValue) else {
                return nil
            }
            return String(scalar)
        default:
            let normalized = primaryKey.display
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            switch normalized {
            case "return", "enter":
                return "\r"
            case "tab":
                return "\t"
            case "backspace", "delete":
                guard let scalar = UnicodeScalar(NSBackspaceCharacter) else { return nil }
                return String(scalar)
            case "escape", "esc":
                return "\u{1b}"
            case "left":
                guard let scalar = UnicodeScalar(NSLeftArrowFunctionKey) else { return nil }
                return String(scalar)
            case "right":
                guard let scalar = UnicodeScalar(NSRightArrowFunctionKey) else { return nil }
                return String(scalar)
            case "up":
                guard let scalar = UnicodeScalar(NSUpArrowFunctionKey) else { return nil }
                return String(scalar)
            case "down":
                guard let scalar = UnicodeScalar(NSDownArrowFunctionKey) else { return nil }
                return String(scalar)
            default:
                guard let first = normalized.first else {
                    return nil
                }
                return String(first)
            }
        }
    }

    private func modifierMask(from modifiers: [ModifierShortcutKey]) -> NSEvent.ModifierFlags {
        modifiers.reduce(into: NSEvent.ModifierFlags()) { partialResult, modifier in
            switch modifier {
            case .leftCommand, .rightCommand, .command:
                partialResult.insert(.command)
            case .leftShift, .rightShift, .shift:
                partialResult.insert(.shift)
            case .leftOption, .rightOption, .option:
                partialResult.insert(.option)
            case .leftControl, .rightControl, .control:
                partialResult.insert(.control)
            case .fn:
                partialResult.insert(.function)
            }
        }
    }

    private func clearShortcut(from item: NSMenuItem) {
        item.keyEquivalent = ""
        item.keyEquivalentModifierMask = []
    }

    @objc private func handleStatusItemClick() {
        showContextMenu()
    }

    private func showContextMenu() {
        guard let menu = contextMenu, let button = statusItem?.button else { return }

        // Update shortcuts/titles before showing
        updateMenuTitles()

        // Show context menu
        statusItem?.menu = menu
        button.performClick(nil)
        statusItem?.menu = nil // Reset so left-click works again
    }

    // MARK: - Menu Actions

    @objc private func openSettings() {
        NavigationService.shared.openSettings()
    }

    @objc private func openHistory() {
        NavigationService.shared.openSettings(section: SettingsSection.transcriptions.rawValue)
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

    private func updateFloatingIndicator(
        isRecording: Bool,
        isAssistantRecording: Bool,
        isStarting: Bool,
        isTranscribing: Bool,
        meetingType: MeetingType? = nil
    ) {
        let recordingState = indicatorRenderState(mode: .recording, meetingType: meetingType)
        let startingState = indicatorRenderState(mode: .starting, meetingType: meetingType)
        let processingState = indicatorRenderState(mode: .processing, meetingType: meetingType)

        if isRecording {
            if isAssistantRecording {
                floatingIndicatorController.show(
                    renderState: recordingState,
                    onStop: { [weak self] in
                        Task { @MainActor [weak self] in
                            await self?.assistantVoiceCommandService.stopAndProcess()
                        }
                    },
                    onCancel: { [weak self] in
                        Task { @MainActor [weak self] in
                            await self?.assistantVoiceCommandService.cancelRecording()
                        }
                    }
                )
            } else {
                floatingIndicatorController.show(renderState: recordingState)
            }
        } else if isStarting {
            floatingIndicatorController.show(renderState: startingState)
        } else if isTranscribing {
            floatingIndicatorController.show(renderState: processingState)
        } else {
            floatingIndicatorController.hide()
        }
    }

    private func indicatorRenderState(mode: FloatingRecordingIndicatorMode, meetingType: MeetingType?) -> RecordingIndicatorRenderState {
        RecordingIndicatorRenderState.fromLegacy(mode: mode, meetingType: meetingType)
    }

    /// Applies the dock visibility setting by changing the app's activation policy.
    /// - Parameter showInDock: If true, shows the app in Dock and Cmd+Tab switcher.
    private func applyDockVisibility(_ showInDock: Bool) {
        let policy: NSApplication.ActivationPolicy = showInDock ? .regular : .accessory
        NSApp.setActivationPolicy(policy)
        logger.info("Activation policy set to: \(showInDock ? "regular (dock)" : "accessory (menu bar only)")")
    }
}
