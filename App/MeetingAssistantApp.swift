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

    var body: some Scene {
        Settings {
            SettingsView()
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appSettings) {
                SettingsLink {
                    Text("settings.title".localized + "...")
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
        let isAssistantProcessing: Bool
        let meetingTypeRawValue: String?
    }

    private let logger = Logger(subsystem: "MeetingAssistant", category: "AppDelegate")
    private var statusItem: NSStatusItem?
    private var contextMenu: NSMenu?
    private var dictateMenuItem: NSMenuItem?
    private var recordMeetingMenuItem: NSMenuItem?
    private var assistantMenuItem: NSMenuItem?
    private lazy var recordingManager: RecordingManager = .shared
    private let settingsStore = AppSettingsStore.shared
    private lazy var floatingIndicatorController = FloatingRecordingIndicatorController()
    private lazy var globalShortcutController = GlobalShortcutController(recordingManager: RecordingManager.shared)
    private lazy var assistantVoiceCommandService = AssistantVoiceCommandService(
        indicator: floatingIndicatorController
    )
    private lazy var assistantShortcutController = AssistantShortcutController(
        assistantService: assistantVoiceCommandService
    )
    private lazy var recordingCancelShortcutController = RecordingCancelShortcutController(
        stateProvider: { [weak self] in
            self?.recordingCancelShortcutStateSnapshot() ?? RecordingCancelShortcutState(
                isRecordingManagerCaptureActive: false,
                isAssistantCaptureActive: false
            )
        },
        cancelRecordingManagerCapture: { [weak self] in
            await self?.recordingManager.cancelRecording()
        },
        cancelAssistantCapture: { [weak self] in
            await self?.assistantVoiceCommandService.cancelRecording()
        }
    )
    private lazy var onboardingController = OnboardingWindowController()
    private lazy var settingsWindowController = SettingsWindowController()
    private var cancellables = Set<AnyCancellable>()
    private var dockObserver: AnyCancellable?
    private var lastRecordingUIRenderState: RecordingUIRenderState?
}

extension AppDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize Monitoring Services
        CrashReporter.shared.setup()
        PerformanceMonitor.shared.startMonitoring()
        configureNavigationService()

        // One-time migration: legacy JSON → Core Data
        Task {
            await FileSystemStorageService.shared.migrateLegacyJSONTranscriptionsToCoreDataIfNeeded()
        }
        // Show onboarding if first launch
        if !settingsStore.hasCompletedOnboarding {
            showFirstLaunchOnboarding()
            return // Defer rest of setup until onboarding completes
        }

        setupMenuBar()
        setupContextMenu()
        globalShortcutController.start()
        assistantShortcutController.start()
        recordingCancelShortcutController.start()
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
        applyDockVisibility(settingsStore.showInDock)

        // Observe changes to dock visibility setting
        dockObserver = settingsStore.$showInDock
            .dropFirst() // Skip initial value (already applied above)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] showInDock in
                self?.applyDockVisibility(showInDock)
            }

        openSettingsOnLaunchIfEnabled()
    }

    func applicationWillTerminate(_ notification: Notification) {
        recordingCancelShortcutController.stop()
    }

    // MARK: - Onboarding

    private func showFirstLaunchOnboarding() {
        presentOnboarding { [weak self] in
            self?.completeOnboarding()
        }
    }

    private func presentOnboarding(completion: @escaping () -> Void) {
        let permissionViewModel = PermissionViewModel(
            manager: PermissionStatusManager(),
            requestMicrophone: { [weak self] in
                await self?.recordingManager.requestPermission(for: .microphone)
            },
            requestScreen: { [weak self] in
                await self?.recordingManager.requestPermission(for: .all)
            },
            openMicrophoneSettings: { [weak self] in
                self?.recordingManager.openMicrophoneSettings()
            },
            openScreenSettings: { [weak self] in
                self?.recordingManager.openPermissionSettings()
            },
            requestAccessibility: { [weak self] in
                self?.recordingManager.requestAccessibilityPermission()
            },
            openAccessibilitySettings: { [weak self] in
                self?.recordingManager.openAccessibilitySettings()
            }
        )

        let shortcutViewModel = ShortcutSettingsViewModel()
        let onboardingViewModel = OnboardingViewModel()
        let modelManager = FluidAIModelManager.shared

        onboardingController.showOnboarding(
            viewModel: onboardingViewModel,
            permissionViewModel: permissionViewModel,
            shortcutViewModel: shortcutViewModel,
            modelManager: modelManager,
            refreshPermissions: { [weak self] in
                await self?.recordingManager.checkPermission()
            },
            completion: completion
        )
    }

    private func completeOnboarding() {
        settingsStore.hasCompletedOnboarding = true
        continueAppSetup()
    }

    private func continueAppSetup() {
        configureNavigationService()
        setupMenuBar()
        setupContextMenu()
        globalShortcutController.start()
        assistantShortcutController.start()
        recordingCancelShortcutController.start()
        setupRecordingObservation()
        floatingIndicatorController.prewarm()
        updateMenuTitles()

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
        applyDockVisibility(settingsStore.showInDock)

        // Observe changes to dock visibility setting
        dockObserver = settingsStore.$showInDock
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] showInDock in
                self?.applyDockVisibility(showInDock)
            }

        openSettingsOnLaunchIfEnabled()
    }

    private func openSettingsOnLaunchIfEnabled() {
        guard settingsStore.showSettingsOnLaunch else { return }
        NavigationService.shared.openSettings()
    }

    private func configureNavigationService() {
        NavigationService.shared.registerOpenSettingsHandler { [weak self] in
            self?.settingsWindowController.showSettingsWindow()
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
        Publishers.MergeMany(
            recordingManager.isRecordingPublisher.map { _ in () }.eraseToAnyPublisher(),
            recordingManager.isStartingPublisher.map { _ in () }.eraseToAnyPublisher(),
            recordingManager.isTranscribingPublisher.map { _ in () }.eraseToAnyPublisher(),
            assistantVoiceCommandService.$isRecording.map { _ in () }.eraseToAnyPublisher(),
            assistantVoiceCommandService.$isProcessing.map { _ in () }.eraseToAnyPublisher(),
            recordingManager.currentMeetingPublisher.map { _ in () }.eraseToAnyPublisher(),
            settingsStore.$cancelRecordingShortcutDefinition.map { _ in () }.eraseToAnyPublisher()
        )
        // @Published emits in willSet; schedule refresh so re-reads observe committed values.
        .receive(on: DispatchQueue.main)
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
        let isAssistantProcessing = assistantVoiceCommandService.isProcessing
        let isProcessing = isTranscribing || isAssistantProcessing
        let currentMeetingType = recordingManager.currentMeeting?.type
        let renderState = RecordingUIRenderState(
            isRecording: isRecording,
            isStarting: isStarting,
            isTranscribing: isTranscribing,
            isAssistantRecording: isAssistantRecording,
            isAssistantProcessing: isAssistantProcessing,
            meetingTypeRawValue: currentMeetingType?.rawValue
        )

        guard renderState != lastRecordingUIRenderState else {
            recordingCancelShortcutController.refresh()
            return
        }
        lastRecordingUIRenderState = renderState

        updateStatusIcon(isRecording: isRecording || isAssistantRecording || isStarting)
        updateFloatingIndicator(
            isRecording: isRecording || isAssistantRecording,
            isAssistantRecording: isAssistantRecording,
            isStarting: isStarting,
            isProcessing: isProcessing,
            meetingType: currentMeetingType
        )

        if isRecording || isStarting,
           settingsStore.recordingIndicatorEnabled,
           settingsStore.recordingIndicatorStyle != .none
        {
            recordingManager.noteIndicatorShownForStartIfNeeded()
        }

        updateMenuTitles()
        recordingCancelShortcutController.refresh()
    }

    private func recordingCancelShortcutStateSnapshot() -> RecordingCancelShortcutState {
        RecordingCancelShortcutState(
            isRecordingManagerCaptureActive: recordingManager.isRecording || recordingManager.isStartingRecording,
            isAssistantCaptureActive: assistantVoiceCommandService.isRecording
        )
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
            let image = NSImage(
                systemSymbolName: "waveform",
                accessibilityDescription: "about.title".localized
            )
            image?.isTemplate = true
            button.image = image
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
            key: "menubar.onboarding",
            action: #selector(openOnboarding)
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

    private enum ShortcutDisplaySource {
        case inHouse(ShortcutDefinition)
        case preset(String)
        case custom
        case none
    }

    private func applyShortcut(to item: NSMenuItem, title: String, shortcutName: KeyboardShortcuts.Name) {
        let settings = AppSettingsStore.shared
        switch resolveShortcutDisplaySource(for: shortcutName, settings: settings) {
        case let .inHouse(shortcut):
            if applyShortcutDefinition(shortcut, to: item, title: title) {
                return
            }
            item.title = "\(title) [\(shortcut.menuDisplayString)]"
            clearShortcut(from: item)
        case let .preset(presetString):
            item.title = "\(title) [\(presetString)]"
            clearShortcut(from: item)
        case .custom:
            guard let shortcut = KeyboardShortcuts.Shortcut(name: shortcutName) else {
                item.title = title
                clearShortcut(from: item)
                return
            }
            applyCustomShortcut(shortcut, to: item, title: title)
        case .none:
            item.title = title
            clearShortcut(from: item)
        }
    }

    private func resolveShortcutDisplaySource(
        for shortcutName: KeyboardShortcuts.Name,
        settings: AppSettingsStore
    ) -> ShortcutDisplaySource {
        switch shortcutName {
        case .dictationToggle:
            resolveShortcutDisplaySource(
                definition: settings.dictationShortcutDefinition,
                hasModifierShortcut: settings.dictationModifierShortcutGesture != nil,
                selectedPresetKey: settings.dictationSelectedPresetKey
            )
        case .assistantCommand:
            resolveShortcutDisplaySource(
                definition: settings.assistantShortcutDefinition,
                hasModifierShortcut: settings.assistantModifierShortcutGesture != nil,
                selectedPresetKey: settings.assistantSelectedPresetKey
            )
        case .meetingToggle:
            resolveShortcutDisplaySource(
                definition: settings.meetingShortcutDefinition,
                hasModifierShortcut: settings.meetingModifierShortcutGesture != nil,
                selectedPresetKey: settings.meetingSelectedPresetKey
            )
        default:
            .custom
        }
    }

    private func resolveShortcutDisplaySource(
        definition: ShortcutDefinition?,
        hasModifierShortcut: Bool,
        selectedPresetKey: PresetShortcutKey
    ) -> ShortcutDisplaySource {
        if let definition {
            return .inHouse(definition)
        }
        if hasModifierShortcut {
            return .none
        }
        if selectedPresetKey != .custom, selectedPresetKey != .notSpecified {
            return .preset(selectedPresetKey.displayName)
        }
        return .custom
    }

    private func applyCustomShortcut(
        _ shortcut: KeyboardShortcuts.Shortcut,
        to item: NSMenuItem,
        title: String
    ) {
        item.title = title
        let normalizedKey = normalizedShortcutKey(from: shortcut.description)
        item.keyEquivalent = menuKeyEquivalent(from: normalizedKey) ?? String(normalizedKey.prefix(1))
        item.keyEquivalentModifierMask = shortcut.modifiers
    }

    private func normalizedShortcutKey(from description: String) -> String {
        let modifierSymbols = ["⌘", "⌥", "⌃", "⇧"]
        var cleanKey = description
        for symbol in modifierSymbols {
            cleanKey = cleanKey.replacingOccurrences(of: symbol, with: "")
        }
        return cleanKey.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func menuKeyEquivalent(from normalizedKey: String) -> String? {
        switch normalizedKey {
        case "space":
            return " "
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
            return normalizedKey.first.map(String.init)
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
            return menuKeyEquivalent(from: normalized)
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

    @objc private func openOnboarding() {
        presentOnboarding {}
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
        let accessibilityKey = isRecording ? "menubar.accessibility.recording" : "menubar.accessibility.idle"
        let accessibilityDesc = accessibilityKey.localized
        statusItem?.button?.image = makeStatusBarImage(
            isRecording: isRecording,
            accessibilityDescription: accessibilityDesc
        )
        statusItem?.button?.contentTintColor = nil
    }

    private func makeStatusBarImage(isRecording: Bool, accessibilityDescription: String) -> NSImage? {
        let iconName = isRecording ? "record.circle.fill" : "waveform"
        guard let baseImage = NSImage(
            systemSymbolName: iconName,
            accessibilityDescription: accessibilityDescription
        ) else {
            return nil
        }

        guard isRecording else {
            baseImage.isTemplate = true
            return baseImage
        }

        let redConfig = NSImage.SymbolConfiguration(hierarchicalColor: .systemRed)
        let configuredImage = baseImage.withSymbolConfiguration(redConfig) ?? baseImage
        configuredImage.isTemplate = false
        return configuredImage
    }

    private func updateFloatingIndicator(
        isRecording: Bool,
        isAssistantRecording: Bool,
        isStarting: Bool,
        isProcessing: Bool,
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
        } else if isProcessing {
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

@MainActor
private final class SettingsWindowController {
    private var window: NSWindow?

    func showSettingsWindow() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        settingsWindow.styleMask.insert(.fullSizeContentView)
        settingsWindow.title = "settings.title".localized
        settingsWindow.titleVisibility = .hidden
        settingsWindow.titlebarAppearsTransparent = true
        settingsWindow.toolbarStyle = .unified
        settingsWindow.toolbar = NSToolbar(identifier: "MeetingAssistantSettingsToolbar")
        settingsWindow.isMovableByWindowBackground = true
        settingsWindow.tabbingMode = .disallowed
        if #available(macOS 11.0, *) {
            settingsWindow.titlebarSeparatorStyle = .none
        }
        settingsWindow.setFrameAutosaveName("MeetingAssistantSettingsWindow")
        settingsWindow.isReleasedWhenClosed = false
        settingsWindow.contentView = NSHostingView(rootView: SettingsView())
        settingsWindow.center()
        settingsWindow.makeKeyAndOrderFront(nil)

        window = settingsWindow
        NSApp.activate(ignoringOtherApps: true)
    }
}
