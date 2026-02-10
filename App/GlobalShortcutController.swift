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
    private let escapeDoublePressInterval: TimeInterval = 0.5
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
        let needsModifierMonitoring = settings.dictationSelectedPresetKey.requiresModifierMonitoring ||
            settings.meetingSelectedPresetKey.requiresModifierMonitoring
        let needsEscapeMonitoring = settings.useEscapeToCancelRecording

        if needsModifierMonitoring {
            installFlagsChangedMonitors()
        } else {
            removeFlagsChangedMonitors()
        }

        if needsEscapeMonitoring {
            installKeyDownMonitors()
        } else {
            removeKeyDownMonitors()
        }
    }

    private func refreshCustomShortcutRegistration() {
        if settings.dictationSelectedPresetKey == .custom {
            KeyboardShortcuts.enable(.dictationToggle)
        } else {
            KeyboardShortcuts.disable(.dictationToggle)
        }

        if settings.meetingSelectedPresetKey == .custom {
            KeyboardShortcuts.enable(.meetingToggle)
        } else {
            KeyboardShortcuts.disable(.meetingToggle)
        }
    }

    private func installFlagsChangedMonitors() {
        if flagsMonitor == nil {
            flagsMonitor = KeyboardEventMonitor(mask: .flagsChanged) { [weak self] event in
                self?.handleFlagsChanged(event)
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
                self?.handleKeyDown(event)
            }
            keyDownMonitor?.start()
        }
    }

    private func removeKeyDownMonitors() {
        keyDownMonitor?.stop()
        keyDownMonitor = nil
    }

    private func removeEventMonitors() {
        removeFlagsChangedMonitors()
        removeKeyDownMonitors()
    }

    // To match the original logic:

    private func handleFlagsChanged(_ event: NSEvent) {
        // Dictation
        if settings.dictationSelectedPresetKey.requiresModifierMonitoring {
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
        if settings.meetingSelectedPresetKey.requiresModifierMonitoring {
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
        guard settings.useEscapeToCancelRecording else { return }
        guard !event.isARepeat else { return }
        guard event.keyCode == PresetShortcutKey.escapeKeyCode else {
            lastEscapePressTime = nil
            return
        }

        let now = Date()
        guard let lastEscapePressTime, now.timeIntervalSince(lastEscapePressTime) <= escapeDoublePressInterval else {
            self.lastEscapePressTime = now
            return
        }
        self.lastEscapePressTime = nil

        Task { @MainActor in
            guard self.recordingManager.isRecording else { return }
            await self.recordingManager.stopRecording(transcribe: false)
        }
    }

    private func handleCustomShortcutDown(for type: ShortcutType) async {
        let presetKey = type == .dictation ? settings.dictationSelectedPresetKey : settings.meetingSelectedPresetKey
        guard presetKey == .custom else { return }
        await handleShortcutDown(for: type)
    }

    private func handleCustomShortcutUp(for type: ShortcutType) async {
        let presetKey = type == .dictation ? settings.dictationSelectedPresetKey : settings.meetingSelectedPresetKey
        guard presetKey == .custom else { return }
        await handleShortcutUp(for: type)
    }

    private func handleShortcutDown(for type: ShortcutType) async {
        let handler = type == .dictation ? dictationHandler : meetingHandler
        handler.handleShortcutDown(activationMode: activationMode(for: type))
    }

    private func handleShortcutUp(for type: ShortcutType) async {
        let handler = type == .dictation ? dictationHandler : meetingHandler
        handler.handleShortcutUp(activationMode: activationMode(for: type))
    }

    private func performAction(_ action: SmartShortcutHandler.Action, for type: ShortcutType) async {
        switch action {
        case .startRecording:
            let source: RecordingSource = type == .dictation ? .microphone : .all
            await recordingManager.startRecording(source: source)
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
}

private enum ShortcutType {
    case dictation
    case meeting
}
