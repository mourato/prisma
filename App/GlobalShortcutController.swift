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

    private struct ShortcutState {
        var isPresetPressed = false
        var pressStartTime: Date?
        var wasRecordingAtPress = false
        var startedRecording = false
        var lastTapTime: Date?
        var lastTapWasRecording = false

        mutating func reset() {
            isPresetPressed = false
            pressStartTime = nil
            wasRecordingAtPress = false
            startedRecording = false
            lastTapTime = nil
            lastTapWasRecording = false
        }
    }

    private var dictationState = ShortcutState()
    private var meetingState = ShortcutState()

    private let presetState = ShortcutActivationState()

    private let holdThreshold: TimeInterval = 0.35
    private let doubleTapInterval: TimeInterval = 0.75
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

    private func handleFlagsChanged(_ event: NSEvent) {
        // Handle Dictation Preset
        if settings.dictationSelectedPresetKey.requiresModifierMonitoring {
            let isActive = isPresetActive(settings.dictationSelectedPresetKey, event: event)
            if isActive, !dictationState.isPresetPressed {
                dictationState.isPresetPressed = true
                Task { @MainActor in await self.handleShortcutDown(for: .dictation) }
            } else if !isActive, dictationState.isPresetPressed {
                dictationState.isPresetPressed = false
                Task { @MainActor in await self.handleShortcutUp(for: .dictation) }
            }
        }

        // Handle Meeting Preset
        if settings.meetingSelectedPresetKey.requiresModifierMonitoring {
            let isActive = isPresetActive(settings.meetingSelectedPresetKey, event: event)
            if isActive, !meetingState.isPresetPressed {
                meetingState.isPresetPressed = true
                Task { @MainActor in await self.handleShortcutDown(for: .meeting) }
            } else if !isActive, meetingState.isPresetPressed {
                meetingState.isPresetPressed = false
                Task { @MainActor in await self.handleShortcutUp(for: .meeting) }
            }
        }
    }

    private enum ShortcutType {
        case dictation
        case meeting
    }

    private func handleKeyDown(_ event: NSEvent) {
        guard settings.useEscapeToCancelRecording else {
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

        Task { @MainActor in
            guard self.recordingManager.isRecording else {
                return
            }

            await self.recordingManager.stopRecording(transcribe: false)
        }
    }

    private func handleCustomShortcutDown(for type: ShortcutType) async {
        let presetKey = type == .dictation ? settings.dictationSelectedPresetKey : settings.meetingSelectedPresetKey
        guard presetKey == .custom else {
            return
        }

        await handleShortcutDown(for: type)
    }

    private func handleCustomShortcutUp(for type: ShortcutType) async {
        let presetKey = type == .dictation ? settings.dictationSelectedPresetKey : settings.meetingSelectedPresetKey
        guard presetKey == .custom else {
            return
        }

        await handleShortcutUp(for: type)
    }

    private func handleShortcutDown(for type: ShortcutType) async {
        switch activationMode(for: type) {
        case .toggle:
            await toggleRecording(for: type)
        case .hold:
            if type == .dictation {
                dictationState.pressStartTime = Date()
                dictationState.wasRecordingAtPress = recordingManager.isRecording
            } else {
                meetingState.pressStartTime = Date()
                meetingState.wasRecordingAtPress = recordingManager.isRecording
            }

            if !recordingManager.isRecording {
                if type == .dictation {
                    dictationState.startedRecording = true
                } else {
                    meetingState.startedRecording = true
                }
                await startRecording(for: type)
            } else {
                if type == .dictation {
                    dictationState.startedRecording = false
                } else {
                    meetingState.startedRecording = false
                }
            }
        case .holdOrToggle:
            if type == .dictation {
                dictationState.pressStartTime = Date()
                dictationState.wasRecordingAtPress = recordingManager.isRecording
            } else {
                meetingState.pressStartTime = Date()
                meetingState.wasRecordingAtPress = recordingManager.isRecording
            }

            if recordingManager.isRecording {
                await recordingManager.stopRecording()
                if type == .dictation {
                    dictationState.startedRecording = false
                } else {
                    meetingState.startedRecording = false
                }
            } else {
                if type == .dictation {
                    dictationState.startedRecording = true
                } else {
                    meetingState.startedRecording = true
                }
                await startRecording(for: type)
            }
        case .doubleTap:
            break
        }
    }

    private func handleShortcutUp(for type: ShortcutType) async {
        switch activationMode(for: type) {
        case .hold:
            let startedRecording = type == .dictation ? dictationState.startedRecording : meetingState.startedRecording
            if startedRecording {
                await recordingManager.stopRecording()
            }
            resetHoldState(for: type)
        case .holdOrToggle:
            let startTime = type == .dictation ? dictationState.pressStartTime : meetingState.pressStartTime
            let wasRecordingAtPress = type == .dictation ? dictationState.wasRecordingAtPress : meetingState.wasRecordingAtPress
            let startedRecording = type == .dictation ? dictationState.startedRecording : meetingState.startedRecording

            guard let startTime else {
                return
            }

            if !wasRecordingAtPress {
                let heldDuration = Date().timeIntervalSince(startTime)
                if heldDuration >= holdThreshold, startedRecording {
                    await recordingManager.stopRecording()
                }
            }
            resetHoldState(for: type)
        case .doubleTap:
            let now = Date()
            let isRecording = recordingManager.isRecording
            let lastTapTime = type == .dictation ? dictationState.lastTapTime : meetingState.lastTapTime
            let lastTapWasRecording = type == .dictation ? dictationState.lastTapWasRecording : meetingState.lastTapWasRecording
            if let lastTapTime,
               now.timeIntervalSince(lastTapTime) <= doubleTapInterval,
               lastTapWasRecording == isRecording
            {
                if type == .dictation {
                    dictationState.lastTapTime = nil
                    dictationState.lastTapWasRecording = false
                } else {
                    meetingState.lastTapTime = nil
                    meetingState.lastTapWasRecording = false
                }
                await toggleRecording(for: type)
            } else {
                if type == .dictation {
                    dictationState.lastTapTime = now
                    dictationState.lastTapWasRecording = isRecording
                } else {
                    meetingState.lastTapTime = now
                    meetingState.lastTapWasRecording = isRecording
                }
            }
        case .toggle:
            break
        }
    }

    private func toggleRecording(for type: ShortcutType) async {
        if recordingManager.isRecording {
            await recordingManager.stopRecording()
        } else {
            await startRecording(for: type)
        }
    }

    private func startRecording(for type: ShortcutType) async {
        let source: RecordingSource = type == .dictation ? .microphone : .all
        await recordingManager.startRecording(source: source)
    }

    private func resetHoldState(for type: ShortcutType) {
        if type == .dictation {
            dictationState.pressStartTime = nil
            dictationState.wasRecordingAtPress = false
            dictationState.startedRecording = false
        } else {
            meetingState.pressStartTime = nil
            meetingState.wasRecordingAtPress = false
            meetingState.startedRecording = false
        }
    }

    private func resetShortcutState() {
        dictationState.reset()
        meetingState.reset()
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
