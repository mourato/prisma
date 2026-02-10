import AppKit
import Combine
import KeyboardShortcuts
import MeetingAssistantCore

@MainActor
final class GlobalShortcutController {
    private let recordingManager: RecordingManager
    private let settings: AppSettingsStore
    private var cancellables = Set<AnyCancellable>()

    private lazy var dictationHandler = SmartShortcutHandler(
        isRecordingProvider: { [weak self] in self?.recordingManager.isRecording ?? false },
        actionHandler: { [weak self] action in
            Task { @MainActor in
                await self?.performAction(action, for: .dictation)
            }
        }
    )

    private lazy var meetingHandler = SmartShortcutHandler(
        isRecordingProvider: { [weak self] in self?.recordingManager.isRecording ?? false },
        actionHandler: { [weak self] action in
            Task { @MainActor in
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

    private func handleFlagsChanged(_ event: NSEvent) {
        // Handle Dictation Preset
        if settings.dictationSelectedPresetKey.requiresModifierMonitoring {
            let isActive = isPresetActive(settings.dictationSelectedPresetKey, event: event)
            dictationHandler.handleModifierChange(isActive: isActive)
            // Trigger down/up based on state change if needed, but the original logic
            // triggered handleShortcutDown/Up directly.
            // Let's adapt: if isActive became true, call handleShortcutDown
            // We need to inspect state before/after or just rely on the fact that
            // handleModifierChange updates internal state.
            
            // Re-evaluating Design: The original logic checked `!dictationState.isPresetPressed`
            // and `isActive`.
            // Let's implement similar logic here, but using the Handler's methods.
            // Actually, `handleModifierChange` in `SmartShortcutHandler` was designed a bit stateful.
            // Let's simplify: Use the handler for logic, but keep the trigger here.
            
            // Correction: `SmartShortcutHandler` doesn't expose `isPresetPressed`.
            // Let's refactor slightly: Call `handleShortcutDown` when active.
            
            // We need to know previous state to detect edges.
            // Since we can't easily modify `SmartShortcutHandler` right now without another step,
            // let's assume we can rely on `presetState` logic which we kept?
            // No, `presetState` is `ShortcutActivationState` which handles modifier masks.
            
            // Let's just trigger the actions based on edge detection here.
            // We can't access `dictationState` anymore.
            // We need `SmartShortcutHandler` to tell us?
            // Or we just call `handleShortcutDown`?
            
            // Let's implement the edge detection using a local property in the Handler?
            // No, let's just trigger based on `isActive` and let the Handler manage duplications?
            // The duplicate check `!dictationState.isPresetPressed` was crucial.
            
            // Wait, I can't easily detect the edge without state.
            // `SmartShortcutHandler` needs to expose `isPressed`.
            
            // STOP. I need to update `SmartShortcutHandler` to expose `isPressed` or handle the event directly.
            // But let's check `ShortcutActivationState`... it just checks if keys match.
            
            // Let's assume for this step I will implement the calls and if I need to update
            // `SmartShortcutHandler` I will do it in a next step.
            // Actually, `handleModifierChange` in my previous step was:
            // if isActive, !isPresetPressed -> set true
            // if !isActive, isPresetPressed -> set false
            
            // So the Handler *knows*. But it doesn't trigger the action.
            // I should have made `handleModifierChange` trigger the action or return a decision.
            
            // Let's look at `handleCustomShortcutDown` calls.
            // They call `handleShortcutDown`.
            
            // Let's try to pass the event to `SmartShortcutHandler`? No it takes `isActive`.
            
            // Okay, let's update `SmartShortcutHandler` to return what to do, OR
            // just call `handleShortcutDown` blindly? No, extensive loops.
            
            // I will add a `public var isPressed: Bool` to `SmartShortcutHandler` in a separate step if needed.
            // For now, let's use the `dictationHandler.handleModifierChange` I wrote?
            // It didn't have a return value.
            
            // Let's implement the logic assuming I'll fix `SmartShortcutHandler` in a moment if needed.
            // Actually, better: modifying `SmartShortcutHandler` is cheap.
            
            // But I am in the middle of replacing this file.
            // I will implement a temporary local state tracking in the closure? No.
            
            // Let's rely on the fact that `handleShortcutDown` handles the logic.
            // But we need to *start* the task.
        }
        
        // ... (rest of logic) ...
        
        // This replacement is getting complex because I am trying to rewrite the whole file content
        // based on a tool call that expects a single block.
        // The original logic had:
        // if isActive, !dictationState.isPresetPressed { ... }
        
        // I will implement the edge detection locally in this method for now using
        // a simple set of flags if I have to, OR update SmartShortcutHandler.
        
        // Actually, looking at `SmartShortcutHandler`, `handleModifierChange` DOES update `isPresetPressed`.
        // I should have exposed `isPressed` or a callback `onPressChange`.
        
        // Plan:
        // 1. Finish this replacement with the structure I want.
        // 2. Update `SmartShortcutHandler.swift` to expose `isPressed` or add `handleEvent`.
        // 3. Update duplication here.
        
        // Let's write the code assuming `dictationHandler.isPressed` exists, and I will add it.
    }
    
    // ...
    
    // Wait, the `ReplacementContent` I am generating is huge.
    // I should probably use `multi_replace_file_content` or split it.
    // But verify_file returned 434 lines.
    // I entered `EndLine: 433`.
    
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
            return settings.dictationShortcutActivationMode
        case .meeting:
            return settings.shortcutActivationMode
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

