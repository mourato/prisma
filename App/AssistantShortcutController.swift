import AppKit
import Combine
import KeyboardShortcuts
import MeetingAssistantCore

@MainActor
final class AssistantShortcutController {
    private let assistantService: AssistantVoiceCommandService
    private let settings: AppSettingsStore
    private var cancellables = Set<AnyCancellable>()

    private var flagsMonitor: KeyboardEventMonitor?
    private var keyDownMonitor: KeyboardEventMonitor?

    private lazy var shortcutHandler = SmartShortcutHandler(
        isRecordingProvider: { [weak self] in self?.assistantService.isRecording ?? false },
        actionHandler: { [weak self] (action: SmartShortcutHandler.Action) in
            Task { @MainActor [weak self] in
                await self?.performAction(action)
            }
        }
    )

    private let presetState = ShortcutActivationState()
    private let escapeDoublePressInterval: TimeInterval = 0.5
    private var lastEscapePressTime: Date?

    init(
        assistantService: AssistantVoiceCommandService,
        settings: AppSettingsStore = .shared
    ) {
        self.assistantService = assistantService
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
        KeyboardShortcuts.onKeyDown(for: .assistantCommand) { [weak self] in
            Task { @MainActor [weak self] in
                await self?.handleCustomShortcutDown()
            }
        }

        KeyboardShortcuts.onKeyUp(for: .assistantCommand) { [weak self] in
            Task { @MainActor [weak self] in
                await self?.handleCustomShortcutUp()
            }
        }
    }

    private func observeSettings() {
        settings.$assistantSelectedPresetKey
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.resetShortcutState()
                self?.refreshCustomShortcutRegistration()
                self?.refreshEventMonitors()
            }
            .store(in: &cancellables)

        settings.$assistantShortcutActivationMode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.resetShortcutState()
            }
            .store(in: &cancellables)

        settings.$assistantUseEscapeToCancelRecording
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshEventMonitors()
            }
            .store(in: &cancellables)
    }

    private func refreshEventMonitors() {
        let needsModifierMonitoring = settings.assistantSelectedPresetKey.requiresModifierMonitoring
        let needsEscapeMonitoring = settings.assistantUseEscapeToCancelRecording

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
        switch settings.assistantSelectedPresetKey {
        case .custom:
            KeyboardShortcuts.enable(.assistantCommand)
        default:
            KeyboardShortcuts.disable(.assistantCommand)
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

    private func handleFlagsChanged(_ event: NSEvent) {
        guard settings.assistantSelectedPresetKey.requiresModifierMonitoring else {
            return
        }

        let isActive = presetState.isPresetActive(settings.assistantSelectedPresetKey, event: event)
        let wasPressed = shortcutHandler.isPressed
        shortcutHandler.handleModifierChange(isActive: isActive)

        if isActive, !wasPressed {
            Task { @MainActor [weak self] in await self?.handleShortcutDown() }
        } else if !isActive, wasPressed {
            Task { @MainActor [weak self] in await self?.handleShortcutUp() }
        }
    }

    private func handleKeyDown(_ event: NSEvent) {
        guard settings.assistantUseEscapeToCancelRecording else {
            return
        }

        guard !event.isARepeat else {
            return
        }

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

        Task { @MainActor [weak self] in
            guard let self else { return }
            guard assistantService.isRecording else {
                return
            }

            await assistantService.cancelRecording()
        }
    }

    private func handleCustomShortcutDown() async {
        guard settings.assistantSelectedPresetKey == .custom else {
            return
        }

        await handleShortcutDown()
    }

    private func handleCustomShortcutUp() async {
        guard settings.assistantSelectedPresetKey == .custom else {
            return
        }

        await handleShortcutUp()
    }

    private func handleShortcutDown() async {
        shortcutHandler.handleShortcutDown(activationMode: settings.assistantShortcutActivationMode)
    }

    private func handleShortcutUp() async {
        shortcutHandler.handleShortcutUp(activationMode: settings.assistantShortcutActivationMode)
    }

    private func performAction(_ action: SmartShortcutHandler.Action) async {
        switch action {
        case .startRecording:
            await assistantService.startRecording()
        case .stopRecording:
            await assistantService.stopAndProcess()
        }
    }

    private func resetShortcutState() {
        lastEscapePressTime = nil
        presetState.reset()
        shortcutHandler.reset()
    }
}
