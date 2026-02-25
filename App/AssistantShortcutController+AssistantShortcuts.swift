import AppKit
import MeetingAssistantCore

@MainActor
extension AssistantShortcutController {
    func handleFlagsChanged(_ event: NSEvent) {
        if let definition = settings.assistantShortcutDefinition {
            handleInHouseShortcutEvent(
                definition: definition,
                event: event,
                state: presetState,
                handler: shortcutHandler,
                onDown: { [weak self] activationMode in
                    Task { @MainActor [weak self] in await self?.handleShortcutDown(activationModeOverride: activationMode) }
                },
                onUp: { [weak self] activationMode in
                    Task { @MainActor [weak self] in await self?.handleShortcutUp(activationModeOverride: activationMode) }
                }
            )
        } else if let gesture = settings.assistantModifierShortcutGesture {
            let isActive = presetState.isModifierGestureActive(gesture, event: event)
            let wasPressed = shortcutHandler.isPressed
            shortcutHandler.handleModifierChange(isActive: isActive)
            let activationMode = gesture.triggerMode.asShortcutActivationMode

            if isActive, !wasPressed {
                Task { @MainActor [weak self] in await self?.handleShortcutDown(activationModeOverride: activationMode) }
            } else if !isActive, wasPressed {
                Task { @MainActor [weak self] in await self?.handleShortcutUp(activationModeOverride: activationMode) }
            }
        } else if settings.assistantSelectedPresetKey.requiresModifierMonitoring {
            let isActive = presetState.isPresetActive(settings.assistantSelectedPresetKey, event: event)
            let wasPressed = shortcutHandler.isPressed
            shortcutHandler.handleModifierChange(isActive: isActive)

            if isActive, !wasPressed {
                Task { @MainActor [weak self] in await self?.handleShortcutDown() }
            } else if !isActive, wasPressed {
                Task { @MainActor [weak self] in await self?.handleShortcutUp() }
            }
        }

        if !shouldUseAssistantShortcutLayer {
            handleIntegrationFlagsChanged(event)
        }
    }

    func handleKeyDown(_ event: NSEvent) {
        if event.keyCode == PresetShortcutKey.escapeKeyCode {
            AppLogger.debug(
                "ESC keyDown observed (assistant)",
                category: .assistant,
                extra: [
                    "scope": "assistant",
                    "isRepeat": event.isARepeat,
                    "assistantUseEscapeToCancelRecording": settings.assistantUseEscapeToCancelRecording,
                    "assistantIsRecording": assistantService.isRecording,
                    "shortcutLayerEnabled": shouldUseAssistantShortcutLayer,
                    "shortcutLayerArmed": isShortcutLayerArmed,
                    "shouldSuppressKeyDownEvents": shouldSuppressKeyDownEvents,
                ]
            )
        }

        if handleSingleEnterStop(event) {
            return
        }

        if handleShortcutLayerKeyDown(event) {
            return
        }

        if let definition = settings.assistantShortcutDefinition {
            handleInHouseShortcutEvent(
                definition: definition,
                event: event,
                state: presetState,
                handler: shortcutHandler,
                onDown: { [weak self] activationMode in
                    Task { @MainActor [weak self] in await self?.handleShortcutDown(activationModeOverride: activationMode) }
                },
                onUp: { [weak self] activationMode in
                    Task { @MainActor [weak self] in await self?.handleShortcutUp(activationModeOverride: activationMode) }
                }
            )
        }
        handleIntegrationKeyEvent(event)

        guard settings.assistantUseEscapeToCancelRecording else {
            if event.keyCode == PresetShortcutKey.escapeKeyCode {
                AppLogger.debug(
                    "ESC ignored because assistant escape cancel is disabled",
                    category: .assistant,
                    extra: ["scope": "assistant"]
                )
            }
            return
        }

        guard !event.isARepeat else {
            if event.keyCode == PresetShortcutKey.escapeKeyCode {
                AppLogger.debug(
                    "ESC ignored because key event is repeat (assistant)",
                    category: .assistant,
                    extra: ["scope": "assistant"]
                )
            }
            return
        }

        guard event.keyCode == PresetShortcutKey.escapeKeyCode else {
            return
        }

        guard didConfirmDoubleEscapePress() else {
            AppLogger.debug(
                "ESC waiting for second press (assistant)",
                category: .assistant,
                extra: ["scope": "assistant"]
            )
            return
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            let wasRecording = assistantService.isRecording

            AppLogger.info(
                "ESC cancel requested",
                category: .assistant,
                extra: [
                    "scope": "assistant",
                    "wasRecording": wasRecording,
                ]
            )

            await assistantService.cancelRecording()

            AppLogger.info(
                "ESC cancel completed",
                category: .assistant,
                extra: [
                    "scope": "assistant",
                    "isRecording": assistantService.isRecording,
                ]
            )
        }
    }

    func handleKeyUp(_ event: NSEvent) {
        if let definition = settings.assistantShortcutDefinition {
            handleInHouseShortcutEvent(
                definition: definition,
                event: event,
                state: presetState,
                handler: shortcutHandler,
                onDown: { [weak self] activationMode in
                    Task { @MainActor [weak self] in await self?.handleShortcutDown(activationModeOverride: activationMode) }
                },
                onUp: { [weak self] activationMode in
                    Task { @MainActor [weak self] in await self?.handleShortcutUp(activationModeOverride: activationMode) }
                }
            )
        }
        handleIntegrationKeyEvent(event)
    }

    func handleCustomShortcutDown() async {
        guard settings.assistantShortcutDefinition == nil else {
            return
        }
        guard settings.assistantModifierShortcutGesture == nil else {
            return
        }

        guard settings.assistantSelectedPresetKey == .custom else {
            return
        }

        await handleShortcutDown()
    }

    func handleCustomShortcutUp() async {
        guard settings.assistantShortcutDefinition == nil else {
            return
        }
        guard settings.assistantModifierShortcutGesture == nil else {
            return
        }

        guard settings.assistantSelectedPresetKey == .custom else {
            return
        }

        await handleShortcutUp()
    }

    func handleShortcutDown(activationModeOverride: ShortcutActivationMode? = nil) async {
        if shouldUseAssistantShortcutLayer {
            let activationMode = activationModeOverride ?? settings.assistantShortcutActivationMode
            if activationMode == .doubleTap {
                return
            }
            armShortcutLayer()
            return
        }

        shortcutHandler.handleShortcutDown(activationMode: activationModeOverride ?? settings.assistantShortcutActivationMode)
    }

    func handleShortcutUp(activationModeOverride: ShortcutActivationMode? = nil) async {
        if shouldUseAssistantShortcutLayer {
            let activationMode = activationModeOverride ?? settings.assistantShortcutActivationMode
            if activationMode == .doubleTap {
                registerLayerLeaderTap()
            }
            return
        }

        shortcutHandler.handleShortcutUp(activationMode: activationModeOverride ?? settings.assistantShortcutActivationMode)
    }

    func handleInHouseShortcutEvent(
        definition: ShortcutDefinition,
        event: NSEvent,
        state: ShortcutActivationState,
        handler: SmartShortcutHandler,
        onDown: @escaping (ShortcutActivationMode) -> Void,
        onUp: @escaping (ShortcutActivationMode) -> Void
    ) {
        let isActive = state.isShortcutActive(definition, event: event)
        let wasPressed = handler.isPressed
        handler.handleModifierChange(isActive: isActive)
        let activationMode = definition.trigger.asShortcutActivationMode

        if isActive, !wasPressed {
            onDown(activationMode)
        } else if !isActive, wasPressed {
            onUp(activationMode)
        }
    }

    func performAction(_ action: SmartShortcutHandler.Action) async {
        switch action {
        case .startRecording:
            await assistantService.startRecording(flow: .assistantMode)
        case .stopRecording:
            await assistantService.stopAndProcess()
        }
    }

    private func didConfirmDoubleEscapePress() -> Bool {
        let now = Date()
        guard let lastEscapePressTime else {
            self.lastEscapePressTime = now
            AppLogger.debug(
                "ESC first press detected",
                category: .assistant,
                extra: [
                    "scope": "assistant",
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
                category: .assistant,
                extra: [
                    "scope": "assistant",
                    "elapsedSec": elapsed,
                    "windowSec": escapeDoublePressInterval,
                ]
            )
            return false
        }

        self.lastEscapePressTime = nil
        AppLogger.info(
            "ESC double-press confirmed",
            category: .assistant,
            extra: [
                "scope": "assistant",
                "elapsedSec": elapsed,
            ]
        )
        return true
    }
}
