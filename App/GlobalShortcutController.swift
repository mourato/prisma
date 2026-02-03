import AppKit
import Combine
import KeyboardShortcuts
import MeetingAssistantCore

@MainActor
final class GlobalShortcutController {
    private let recordingManager: RecordingManager
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
    private let doubleTapInterval: TimeInterval = 0.5

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
        KeyboardShortcuts.onKeyDown(for: .toggleRecording) { [weak self] in
            Task { @MainActor in
                await self?.handleCustomShortcutDown()
            }
        }

        KeyboardShortcuts.onKeyUp(for: .toggleRecording) { [weak self] in
            Task { @MainActor in
                await self?.handleCustomShortcutUp()
            }
        }
    }

    private func observeSettings() {
        settings.$selectedPresetKey
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

        settings.$useEscapeToCancelRecording
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshEventMonitors()
            }
            .store(in: &cancellables)
    }

    private func refreshEventMonitors() {
        let needsModifierMonitoring = settings.selectedPresetKey.requiresModifierMonitoring
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
        switch settings.selectedPresetKey {
        case .custom:
            KeyboardShortcuts.enable(.toggleRecording)
        default:
            KeyboardShortcuts.disable(.toggleRecording)
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
        guard settings.selectedPresetKey.requiresModifierMonitoring else {
            return
        }

        let isActive = isPresetActive(settings.selectedPresetKey, event: event)

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
        guard settings.useEscapeToCancelRecording else {
            return
        }

        guard event.keyCode == PresetShortcutKey.escapeKeyCode else {
            return
        }

        Task { @MainActor in
            guard self.recordingManager.isRecording else {
                return
            }

            await self.recordingManager.stopRecording(transcribe: false)
        }
    }

    private func handleCustomShortcutDown() async {
        guard settings.selectedPresetKey == .custom else {
            return
        }

        await handleShortcutDown()
    }

    private func handleCustomShortcutUp() async {
        guard settings.selectedPresetKey == .custom else {
            return
        }

        await handleShortcutUp()
    }

    private func handleShortcutDown() async {
        switch settings.shortcutActivationMode {
        case .toggle:
            await toggleRecording()
        case .hold:
            shortcutPressStartTime = Date()
            shortcutWasRecordingAtPress = recordingManager.isRecording
            if !recordingManager.isRecording {
                shortcutStartedRecording = true
                await recordingManager.startRecording(source: .microphone)
            } else {
                shortcutStartedRecording = false
            }
        case .holdOrToggle:
            shortcutPressStartTime = Date()
            shortcutWasRecordingAtPress = recordingManager.isRecording
            if recordingManager.isRecording {
                await recordingManager.stopRecording()
                shortcutStartedRecording = false
            } else {
                shortcutStartedRecording = true
                await recordingManager.startRecording(source: .microphone)
            }
        case .doubleTap:
            break
        }
    }

    private func handleShortcutUp() async {
        switch settings.shortcutActivationMode {
        case .hold:
            if shortcutStartedRecording {
                await recordingManager.stopRecording()
            }
            resetHoldState()
        case .holdOrToggle:
            guard let startTime = shortcutPressStartTime else {
                return
            }

            if !shortcutWasRecordingAtPress {
                let heldDuration = Date().timeIntervalSince(startTime)
                if heldDuration >= holdThreshold, shortcutStartedRecording {
                    await recordingManager.stopRecording()
                }
            }
            resetHoldState()
        case .doubleTap:
            let now = Date()
            if let lastTapTime, now.timeIntervalSince(lastTapTime) <= doubleTapInterval {
                self.lastTapTime = nil
                await toggleRecording()
            } else {
                lastTapTime = now
            }
        case .toggle:
            break
        }
    }

    private func toggleRecording() async {
        if recordingManager.isRecording {
            await recordingManager.stopRecording()
        } else {
            await recordingManager.startRecording(source: .microphone)
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

    private func isPresetActive(_ preset: PresetShortcutKey, event: NSEvent) -> Bool {
        presetState.isPresetActive(preset, event: event)
    }
}
