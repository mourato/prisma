import AppKit
import Combine
import KeyboardShortcuts
import MeetingAssistantCore

@MainActor
final class GlobalShortcutController {
    private let recordingManager: RecordingManager
    private let settings: AppSettingsStore
    private var cancellables = Set<AnyCancellable>()
    private var flagsMonitor: KeyboardEventMonitor?
    private var keyDownMonitor: KeyboardEventMonitor?
    private var keyUpMonitor: KeyboardEventMonitor?

    private lazy var dictationHandler = SmartShortcutHandler(
        isRecordingProvider: { [weak self] in self?.recordingManager.isRecording ?? false },
        actionHandler: { [weak self] action in
            Task { @MainActor [weak self] in
                await self?.performAction(action, for: .dictation)
            }
        }
    )

    private lazy var meetingHandler = SmartShortcutHandler(
        isRecordingProvider: { [weak self] in self?.recordingManager.isRecording ?? false },
        actionHandler: { [weak self] action in
            Task { @MainActor [weak self] in
                await self?.performAction(action, for: .meeting)
            }
        }
    )

    private let presetState = ShortcutActivationState()
    private let escapeDoublePressInterval: TimeInterval = 1.0
    private var lastEscapePressTime: Date?

    init(
        recordingManager: RecordingManager,
        settings: AppSettingsStore = .shared
    ) {
        self.recordingManager = recordingManager
        self.settings = settings
    }

    func start() {
        setupKeyboardShortcutHandlers()
        observeSettings()
        refreshCustomShortcutRegistration()
        refreshEventMonitors()
    }

    deinit {
        Task { @MainActor [weak self] in
            self?.removeEventMonitors()
        }
    }

    private func setupKeyboardShortcutHandlers() {
        // Dictation
        KeyboardShortcuts.onKeyDown(for: .dictationToggle) { [weak self] in
            Task { @MainActor in
                await self?.handleCustomShortcutDown(for: .dictation)
            }
        }

        KeyboardShortcuts.onKeyUp(for: .dictationToggle) { [weak self] in
            Task { @MainActor in
                await self?.handleCustomShortcutUp(for: .dictation)
            }
        }

        // Meeting
        KeyboardShortcuts.onKeyDown(for: .meetingToggle) { [weak self] in
            Task { @MainActor in
                await self?.handleCustomShortcutDown(for: .meeting)
            }
        }

        KeyboardShortcuts.onKeyUp(for: .meetingToggle) { [weak self] in
            Task { @MainActor in
                await self?.handleCustomShortcutUp(for: .meeting)
            }
        }
    }

    private func observeSettings() {
        settings.$dictationSelectedPresetKey
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.resetShortcutState()
                self?.refreshCustomShortcutRegistration()
                self?.refreshEventMonitors()
            }
            .store(in: &cancellables)

        settings.$meetingSelectedPresetKey
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.resetShortcutState()
                self?.refreshCustomShortcutRegistration()
                self?.refreshEventMonitors()
            }
            .store(in: &cancellables)

        settings.$dictationModifierShortcutGesture
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.resetShortcutState()
                self?.refreshCustomShortcutRegistration()
                self?.refreshEventMonitors()
            }
            .store(in: &cancellables)

        settings.$dictationShortcutDefinition
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.resetShortcutState()
                self?.refreshCustomShortcutRegistration()
                self?.refreshEventMonitors()
            }
            .store(in: &cancellables)

        settings.$meetingModifierShortcutGesture
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.resetShortcutState()
                self?.refreshCustomShortcutRegistration()
                self?.refreshEventMonitors()
            }
            .store(in: &cancellables)

        settings.$meetingShortcutDefinition
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.resetShortcutState()
                self?.refreshCustomShortcutRegistration()
                self?.refreshEventMonitors()
            }
            .store(in: &cancellables)

        settings.$shortcutActivationMode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.resetShortcutState()
            }
            .store(in: &cancellables)

        settings.$dictationShortcutActivationMode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.resetShortcutState()
            }
            .store(in: &cancellables)

        settings.$useEscapeToCancelRecording
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshEventMonitors()
            }
            .store(in: &cancellables)
    }

    private func refreshEventMonitors() {
        let hasInHouseShortcutDefinitions = settings.dictationShortcutDefinition != nil ||
            settings.meetingShortcutDefinition != nil
        let needsModifierMonitoring = hasInHouseShortcutDefinitions ||
            settings.dictationModifierShortcutGesture != nil ||
            settings.meetingModifierShortcutGesture != nil ||
            settings.dictationSelectedPresetKey.requiresModifierMonitoring ||
            settings.meetingSelectedPresetKey.requiresModifierMonitoring
        let needsShortcutKeyMonitoring = hasInHouseShortcutDefinitions
        let needsEscapeMonitoring = settings.useEscapeToCancelRecording

        if needsModifierMonitoring {
            installFlagsChangedMonitors()
        } else {
            removeFlagsChangedMonitors()
        }

        if needsEscapeMonitoring || needsShortcutKeyMonitoring {
            installKeyDownMonitors()
        } else {
            removeKeyDownMonitors()
        }

        if needsShortcutKeyMonitoring {
            installKeyUpMonitors()
        } else {
            removeKeyUpMonitors()
        }
    }

    private func refreshCustomShortcutRegistration() {
        if settings.dictationShortcutDefinition == nil,
           settings.dictationModifierShortcutGesture == nil,
           settings.dictationSelectedPresetKey == .custom
        {
            KeyboardShortcuts.enable(.dictationToggle)
        } else {
            KeyboardShortcuts.disable(.dictationToggle)
        }

        if settings.meetingShortcutDefinition == nil,
           settings.meetingModifierShortcutGesture == nil,
           settings.meetingSelectedPresetKey == .custom
        {
            KeyboardShortcuts.enable(.meetingToggle)
        } else {
            KeyboardShortcuts.disable(.meetingToggle)
        }
    }

    private func installFlagsChangedMonitors() {
        if flagsMonitor == nil {
            flagsMonitor = KeyboardEventMonitor(mask: .flagsChanged) { [weak self] event in
                Task { @MainActor [weak self] in
                    self?.handleFlagsChanged(event)
                }
            }
            flagsMonitor?.start()
        }
    }

    private func removeFlagsChangedMonitors() {
        flagsMonitor?.stop()
        flagsMonitor = nil
    }

    private func installKeyDownMonitors() {
        if keyDownMonitor == nil {
            keyDownMonitor = KeyboardEventMonitor(mask: .keyDown) { [weak self] event in
                Task { @MainActor [weak self] in
                    self?.handleKeyDown(event)
                }
            }
            keyDownMonitor?.start()
        }
    }

    private func installKeyUpMonitors() {
        if keyUpMonitor == nil {
            keyUpMonitor = KeyboardEventMonitor(mask: .keyUp) { [weak self] event in
                Task { @MainActor [weak self] in
                    self?.handleKeyUp(event)
                }
            }
            keyUpMonitor?.start()
        }
    }

    private func removeKeyDownMonitors() {
        keyDownMonitor?.stop()
        keyDownMonitor = nil
    }

    private func removeKeyUpMonitors() {
        keyUpMonitor?.stop()
        keyUpMonitor = nil
    }

    private func removeEventMonitors() {
        removeFlagsChangedMonitors()
        removeKeyDownMonitors()
        removeKeyUpMonitors()
    }

    // To match the original logic:

    private func handleFlagsChanged(_ event: NSEvent) {
        // Dictation
        if let definition = settings.dictationShortcutDefinition {
            handleInHouseShortcutEvent(
                definition: definition,
                event: event,
                handler: dictationHandler,
                type: .dictation
            )
        } else if let gesture = settings.dictationModifierShortcutGesture {
            let isActive = isModifierGestureActive(gesture, event: event)
            let wasPressed = dictationHandler.isPressed
            dictationHandler.handleModifierChange(isActive: isActive)
            let activationMode = gesture.triggerMode.asShortcutActivationMode

            if isActive, !wasPressed {
                Task { @MainActor in await handleShortcutDown(for: .dictation, activationModeOverride: activationMode) }
            } else if !isActive, wasPressed {
                Task { @MainActor in await handleShortcutUp(for: .dictation, activationModeOverride: activationMode) }
            }
        } else if settings.dictationSelectedPresetKey.requiresModifierMonitoring {
            let isActive = isPresetActive(settings.dictationSelectedPresetKey, event: event)
            let wasPressed = dictationHandler.isPressed
            dictationHandler.handleModifierChange(isActive: isActive)

            if isActive, !wasPressed {
                Task { @MainActor in await handleShortcutDown(for: .dictation) }
            } else if !isActive, wasPressed {
                Task { @MainActor in await handleShortcutUp(for: .dictation) }
            }
        }

        // Meeting
        if let definition = settings.meetingShortcutDefinition {
            handleInHouseShortcutEvent(
                definition: definition,
                event: event,
                handler: meetingHandler,
                type: .meeting
            )
        } else if let gesture = settings.meetingModifierShortcutGesture {
            let isActive = isModifierGestureActive(gesture, event: event)
            let wasPressed = meetingHandler.isPressed
            meetingHandler.handleModifierChange(isActive: isActive)
            let activationMode = gesture.triggerMode.asShortcutActivationMode

            if isActive, !wasPressed {
                Task { @MainActor in await handleShortcutDown(for: .meeting, activationModeOverride: activationMode) }
            } else if !isActive, wasPressed {
                Task { @MainActor in await handleShortcutUp(for: .meeting, activationModeOverride: activationMode) }
            }
        } else if settings.meetingSelectedPresetKey.requiresModifierMonitoring {
            let isActive = isPresetActive(settings.meetingSelectedPresetKey, event: event)
            let wasPressed = meetingHandler.isPressed
            meetingHandler.handleModifierChange(isActive: isActive)

            if isActive, !wasPressed {
                Task { @MainActor in await handleShortcutDown(for: .meeting) }
            } else if !isActive, wasPressed {
                Task { @MainActor in await handleShortcutUp(for: .meeting) }
            }
        }
    }

    private func handleKeyDown(_ event: NSEvent) {
        if let definition = settings.dictationShortcutDefinition {
            handleInHouseShortcutEvent(
                definition: definition,
                event: event,
                handler: dictationHandler,
                type: .dictation
            )
        }

        if let definition = settings.meetingShortcutDefinition {
            handleInHouseShortcutEvent(
                definition: definition,
                event: event,
                handler: meetingHandler,
                type: .meeting
            )
        }

        guard settings.useEscapeToCancelRecording else { return }
        guard !event.isARepeat else { return }
        guard event.keyCode == PresetShortcutKey.escapeKeyCode else {
            return
        }

        guard didConfirmDoubleEscapePress() else { return }

        Task { @MainActor in
            let wasRecording = self.recordingManager.isRecording
            let wasStarting = self.recordingManager.isStartingRecording

            guard wasRecording || wasStarting else {
                AppLogger.debug(
                    "ESC cancel ignored",
                    category: .uiController,
                    extra: [
                        "scope": "global",
                        "reason": "not_recording",
                    ]
                )
                return
            }

            AppLogger.info(
                "ESC cancel requested",
                category: .uiController,
                extra: [
                    "scope": "global",
                    "wasRecording": wasRecording,
                    "wasStarting": wasStarting,
                ]
            )

            await self.recordingManager.cancelRecording()

            AppLogger.info(
                "ESC cancel completed",
                category: .uiController,
                extra: [
                    "scope": "global",
                    "isRecording": self.recordingManager.isRecording,
                    "isStarting": self.recordingManager.isStartingRecording,
                ]
            )
        }
    }

    private func didConfirmDoubleEscapePress() -> Bool {
        let now = Date()
        guard let lastEscapePressTime else {
            self.lastEscapePressTime = now
            AppLogger.debug(
                "ESC first press detected",
                category: .uiController,
                extra: [
                    "scope": "global",
                    "windowSec": escapeDoublePressInterval,
                ]
            )
            return false
        }

        let elapsed = now.timeIntervalSince(lastEscapePressTime)
        guard elapsed <= escapeDoublePressInterval else {
            self.lastEscapePressTime = now
            AppLogger.debug(
                "ESC double-press timeout",
                category: .uiController,
                extra: [
                    "scope": "global",
                    "elapsedSec": elapsed,
                    "windowSec": escapeDoublePressInterval,
                ]
            )
            return false
        }

        self.lastEscapePressTime = nil
        AppLogger.info(
            "ESC double-press confirmed",
            category: .uiController,
            extra: [
                "scope": "global",
                "elapsedSec": elapsed,
            ]
        )
        return true
    }

    private func handleKeyUp(_ event: NSEvent) {
        if let definition = settings.dictationShortcutDefinition {
            handleInHouseShortcutEvent(
                definition: definition,
                event: event,
                handler: dictationHandler,
                type: .dictation
            )
        }

        if let definition = settings.meetingShortcutDefinition {
            handleInHouseShortcutEvent(
                definition: definition,
                event: event,
                handler: meetingHandler,
                type: .meeting
            )
        }
    }

    private func handleCustomShortcutDown(for type: ShortcutType) async {
        let presetKey = type == .dictation ? settings.dictationSelectedPresetKey : settings.meetingSelectedPresetKey
        let inHouseDefinition = type == .dictation ? settings.dictationShortcutDefinition : settings.meetingShortcutDefinition
        if inHouseDefinition != nil {
            return
        }
        if type == .dictation, settings.dictationModifierShortcutGesture != nil {
            return
        }
        if type == .meeting, settings.meetingModifierShortcutGesture != nil {
            return
        }
        guard presetKey == .custom else { return }
        await handleShortcutDown(for: type)
    }

    private func handleCustomShortcutUp(for type: ShortcutType) async {
        let presetKey = type == .dictation ? settings.dictationSelectedPresetKey : settings.meetingSelectedPresetKey
        let inHouseDefinition = type == .dictation ? settings.dictationShortcutDefinition : settings.meetingShortcutDefinition
        if inHouseDefinition != nil {
            return
        }
        if type == .dictation, settings.dictationModifierShortcutGesture != nil {
            return
        }
        if type == .meeting, settings.meetingModifierShortcutGesture != nil {
            return
        }
        guard presetKey == .custom else { return }
        await handleShortcutUp(for: type)
    }

    private func handleShortcutDown(
        for type: ShortcutType,
        activationModeOverride: ShortcutActivationMode? = nil
    ) async {
        let handler = type == .dictation ? dictationHandler : meetingHandler
        handler.handleShortcutDown(activationMode: activationModeOverride ?? activationMode(for: type))
    }

    private func handleShortcutUp(
        for type: ShortcutType,
        activationModeOverride: ShortcutActivationMode? = nil
    ) async {
        let handler = type == .dictation ? dictationHandler : meetingHandler
        handler.handleShortcutUp(activationMode: activationModeOverride ?? activationMode(for: type))
    }

    private func performAction(_ action: SmartShortcutHandler.Action, for type: ShortcutType) async {
        switch action {
        case .startRecording:
            let source: RecordingSource = type == .dictation ? .microphone : .all
            let triggerLabel = type == .dictation ? "shortcut.dictation" : "shortcut.meeting"
            await recordingManager.startRecording(
                source: source,
                requestedAt: Date(),
                triggerLabel: triggerLabel
            )
        case .stopRecording:
            await recordingManager.stopRecording()
        }
    }

    private func resetShortcutState() {
        dictationHandler.reset()
        meetingHandler.reset()
        lastEscapePressTime = nil
        presetState.reset()
    }

    private func activationMode(for type: ShortcutType) -> ShortcutActivationMode {
        switch type {
        case .dictation:
            settings.dictationShortcutActivationMode
        case .meeting:
            settings.shortcutActivationMode
        }
    }

    private func isPresetActive(_ preset: PresetShortcutKey, event: NSEvent) -> Bool {
        presetState.isPresetActive(preset, event: event)
    }

    private func isModifierGestureActive(_ gesture: ModifierShortcutGesture, event: NSEvent) -> Bool {
        presetState.isModifierGestureActive(gesture, event: event)
    }

    private func isShortcutActive(_ definition: ShortcutDefinition, event: NSEvent) -> Bool {
        presetState.isShortcutActive(definition, event: event)
    }

    private func handleInHouseShortcutEvent(
        definition: ShortcutDefinition,
        event: NSEvent,
        handler: SmartShortcutHandler,
        type: ShortcutType
    ) {
        let isActive = isShortcutActive(definition, event: event)
        let wasPressed = handler.isPressed
        handler.handleModifierChange(isActive: isActive)
        let activationMode = definition.trigger.asShortcutActivationMode

        if isActive, !wasPressed {
            Task { @MainActor in
                await handleShortcutDown(for: type, activationModeOverride: activationMode)
            }
        } else if !isActive, wasPressed {
            Task { @MainActor in
                await handleShortcutUp(for: type, activationModeOverride: activationMode)
            }
        }
    }
}

private enum ShortcutType {
    case dictation
    case meeting
}
