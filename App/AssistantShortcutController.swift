import AppKit
import Combine
import KeyboardShortcuts
import MeetingAssistantCore

@MainActor
final class AssistantShortcutController {
    private let assistantService: AssistantVoiceCommandService
    private let settings: AppSettingsStore
    private var cancellables = Set<AnyCancellable>()

    private var globalFlagsMonitor: Any?
    private var localFlagsMonitor: Any?
    private var globalKeyDownMonitor: Any?
    private var localKeyDownMonitor: Any?

    private var isPresetPressed = false
    private var shortcutPressStartTime: Date?
    private var shortcutWasRecordingAtPress = false
    private var shortcutStartedRecording = false
    private var lastTapTime: Date?

    private let presetState = ShortcutActivationState()

    private let holdThreshold: TimeInterval = 0.35
    private let doubleTapInterval: TimeInterval = 0.35

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
        refreshEventMonitors()
    }

    deinit {
        Task { @MainActor [weak self] in
            self?.removeEventMonitors()
        }
    }

    private func setupKeyboardShortcutHandlers() {
        KeyboardShortcuts.onKeyDown(for: .assistantCommand) { [weak self] in
            Task { @MainActor in
                await self?.handleCustomShortcutDown()
            }
        }

        KeyboardShortcuts.onKeyUp(for: .assistantCommand) { [weak self] in
            Task { @MainActor in
                await self?.handleCustomShortcutUp()
            }
        }
    }

    private func observeSettings() {
        settings.$assistantSelectedPresetKey
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.resetShortcutState()
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

    private func installFlagsChangedMonitors() {
        if globalFlagsMonitor == nil {
            globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
                self?.handleFlagsChanged(event)
            }
        }

        if localFlagsMonitor == nil {
            localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
                self?.handleFlagsChanged(event)
                return event
            }
        }
    }

    private func removeFlagsChangedMonitors() {
        if let monitor = globalFlagsMonitor {
            NSEvent.removeMonitor(monitor)
            globalFlagsMonitor = nil
        }

        if let monitor = localFlagsMonitor {
            NSEvent.removeMonitor(monitor)
            localFlagsMonitor = nil
        }
    }

    private func installKeyDownMonitors() {
        if globalKeyDownMonitor == nil {
            globalKeyDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
                self?.handleKeyDown(event)
            }
        }

        if localKeyDownMonitor == nil {
            localKeyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                self?.handleKeyDown(event)
                return event
            }
        }
    }

    private func removeKeyDownMonitors() {
        if let monitor = globalKeyDownMonitor {
            NSEvent.removeMonitor(monitor)
            globalKeyDownMonitor = nil
        }

        if let monitor = localKeyDownMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyDownMonitor = nil
        }
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

        if isActive, !isPresetPressed {
            isPresetPressed = true
            Task { @MainActor in
                await self.handleShortcutDown()
            }
        } else if !isActive, isPresetPressed {
            isPresetPressed = false
            Task { @MainActor in
                await self.handleShortcutUp()
            }
        }
    }

    private func handleKeyDown(_ event: NSEvent) {
        guard settings.assistantUseEscapeToCancelRecording else {
            return
        }

        guard event.keyCode == PresetShortcutKey.escapeKeyCode else {
            return
        }

        Task { @MainActor in
            guard self.assistantService.isRecording else {
                return
            }

            await self.assistantService.cancelRecording()
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
        switch settings.assistantShortcutActivationMode {
        case .toggle:
            await toggleAssistant()
        case .hold:
            shortcutPressStartTime = Date()
            shortcutWasRecordingAtPress = assistantService.isRecording
            if !assistantService.isRecording {
                shortcutStartedRecording = true
                await assistantService.startRecording()
            } else {
                shortcutStartedRecording = false
            }
        case .holdOrToggle:
            shortcutPressStartTime = Date()
            shortcutWasRecordingAtPress = assistantService.isRecording
            if assistantService.isRecording {
                await assistantService.stopAndProcess()
                shortcutStartedRecording = false
            } else {
                shortcutStartedRecording = true
                await assistantService.startRecording()
            }
        case .doubleTap:
            let now = Date()
            if let lastTapTime, now.timeIntervalSince(lastTapTime) <= doubleTapInterval {
                self.lastTapTime = nil
                await toggleAssistant()
            } else {
                lastTapTime = now
            }
        }
    }

    private func handleShortcutUp() async {
        switch settings.assistantShortcutActivationMode {
        case .hold:
            if shortcutStartedRecording {
                await assistantService.stopAndProcess()
            }
            resetHoldState()
        case .holdOrToggle:
            guard let startTime = shortcutPressStartTime else {
                return
            }

            if !shortcutWasRecordingAtPress {
                let heldDuration = Date().timeIntervalSince(startTime)
                if heldDuration >= holdThreshold, shortcutStartedRecording {
                    await assistantService.stopAndProcess()
                }
            }
            resetHoldState()
        case .toggle, .doubleTap:
            break
        }
    }

    private func toggleAssistant() async {
        if assistantService.isRecording {
            await assistantService.stopAndProcess()
        } else {
            await assistantService.startRecording()
        }
    }

    private func resetHoldState() {
        shortcutPressStartTime = nil
        shortcutWasRecordingAtPress = false
        shortcutStartedRecording = false
    }

    private func resetShortcutState() {
        isPresetPressed = false
        lastTapTime = nil
        resetHoldState()
        presetState.reset()
    }
}
