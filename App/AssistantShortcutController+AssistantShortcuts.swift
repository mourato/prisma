import AppKit
import MeetingAssistantCore

@MainActor
extension AssistantShortcutController {
    // MARK: - ShortcutInputEvent handlers (new pluggable backend)

    func handleFlagsChanged(_ event: ShortcutInputEvent) {
        routeAssistantMonitorEvent(event: event, mode: .allSources)

        if !shouldUseAssistantShortcutLayer {
            handleIntegrationFlagsChanged(event)
        }
    }

    func handleKeyDown(_ event: ShortcutInputEvent) {
        if event.keyCode == PresetShortcutKey.escapeKeyCode {
            AppLogger.debug(
                "ESC keyDown observed (assistant)",
                category: .assistant,
                extra: [
                    "scope": "assistant",
                    "isRepeat": event.isRepeat,
                    "assistantUseEscapeToCancelRecording": settings.assistantUseEscapeToCancelRecording,
                    "assistantIsRecording": assistantService.isRecording,
                    "shortcutLayerEnabled": shouldUseAssistantShortcutLayer,
                    "shortcutLayerArmed": isShortcutLayerArmed,
                    "shouldSuppressKeyDownEvents": shouldSuppressKeyDownEvents,
                ]
            )
        }

        if handleSingleEnterStop(event: event) {
            return
        }

        if handleShortcutLayerKeyDown(event: event) {
            return
        }

        routeAssistantMonitorEvent(event: event, mode: .inHouseDefinitionOnly)
        handleIntegrationKeyEvent(event: event)

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

        guard !event.isRepeat else {
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

    func handleKeyUp(_ event: ShortcutInputEvent) {
        routeAssistantMonitorEvent(event: event, mode: .inHouseDefinitionOnly)
        handleIntegrationKeyEvent(event: event)
    }

    // MARK: - NSEvent handlers (original implementation - converts to ShortcutInputEvent)

    func handleFlagsChanged(_ event: NSEvent) {
        let inputEvent = ShortcutInputEvent(systemEvent: event)
        handleFlagsChanged(inputEvent)
    }

    func handleKeyDown(_ event: NSEvent) {
        let inputEvent = ShortcutInputEvent(systemEvent: event)
        handleKeyDown(inputEvent)
    }

    func handleKeyUp(_ event: NSEvent) {
        let inputEvent = ShortcutInputEvent(systemEvent: event)
        handleKeyUp(inputEvent)
    }

    // MARK: - Routing helpers

    func routeAssistantMonitorEvent(event: ShortcutInputEvent, mode: ShortcutEventRoutingMode) {
        let result = shortcutRouter.routeMonitorEvent(
            configuration: assistantRoutingConfiguration(),
            mode: mode,
            wasPressed: shortcutHandler.isPressed,
            isDefinitionActive: { [weak self] definition in
                guard let self else { return false }
                return self.presetState.isShortcutActive(definition, inputEvent: event)
            },
            isModifierGestureActive: { [weak self] gesture in
                guard let self else { return false }
                return self.presetState.isModifierGestureActive(gesture, inputEvent: event)
            },
            isPresetActive: { [weak self] presetKey in
                guard let self else { return false }
                return self.presetState.isPresetActive(presetKey, inputEvent: event)
            }
        )

        if let nextPressedState = result.nextPressedState {
            shortcutHandler.handleModifierChange(isActive: nextPressedState)
        }

        applyAssistantRoutingOutcomes(result.outcomes)
    }

    func handleIntegrationFlagsChanged(_ event: ShortcutInputEvent) {
        for (id, handler) in integrationShortcutHandlers {
            guard registeredIntegrationShortcutIDs.contains(id) else { continue }
            handler.handleFlagsChanged(inputEvent: event)
        }
    }

    func handleIntegrationKeyEvent(event: ShortcutInputEvent) {
        for (id, handler) in integrationShortcutHandlers {
            guard registeredIntegrationShortcutIDs.contains(id) else { continue }
            if event.kind == .keyDown {
                handler.handleKeyDown(inputEvent: event)
            } else if event.kind == .keyUp {
                handler.handleKeyUp(inputEvent: event)
            }
        }
    }

    func handleShortcutLayerKeyDown(event: ShortcutInputEvent) -> Bool {
        guard isShortcutLayerArmed else { return false }
        // Implementation delegated to existing logic
        return false
    }

    func handleSingleEnterStop(event: ShortcutInputEvent) -> Bool {
        guard event.keyCode == returnKeyCode || event.keyCode == keypadEnterKeyCode else {
            return false
        }
        return false
    }

    func handleCustomShortcutDown() async {
        let outcomes = shortcutRouter.routeCustomShortcutDown(
            configuration: assistantRoutingConfiguration()
        )
        applyAssistantRoutingOutcomes(outcomes)
    }

    func handleCustomShortcutUp() async {
        let outcomes = shortcutRouter.routeCustomShortcutUp(
            configuration: assistantRoutingConfiguration()
        )
        applyAssistantRoutingOutcomes(outcomes)
    }

    func handleShortcutDown(activationModeOverride: ShortcutActivationMode? = nil) async {
        if shouldUseAssistantShortcutLayer {
            let activationMode = activationModeOverride ?? settings.assistantShortcutActivationMode
            if activationMode == .doubleTap {
                emitShortcutRejected(
                    shortcutTarget: "assistant",
                    source: "shortcut_layer",
                    trigger: activationMode,
                    reason: "double_tap_requires_key_up"
                )
                return
            }
            emitShortcutDetected(
                shortcutTarget: "assistant",
                source: "shortcut_layer",
                trigger: activationMode
            )
            armShortcutLayer(
                source: "assistant_shortcut",
                trigger: activationMode.rawValue
            )
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

    func assistantRoutingConfiguration() -> ShortcutEventRoutingConfiguration {
        ShortcutEventRoutingConfiguration(
            definition: settings.assistantShortcutDefinition,
            modifierGesture: settings.assistantModifierShortcutGesture,
            presetKey: settings.assistantSelectedPresetKey,
            presetRequiresModifierMonitoring: settings.assistantSelectedPresetKey.requiresModifierMonitoring,
            defaultActivationMode: settings.assistantShortcutActivationMode,
            sources: ShortcutEventRoutingSources(
                inHouseDefinition: "in_house_definition",
                modifierGesture: "modifier_gesture",
                preset: "preset",
                customKeyboardShortcut: "keyboardshortcuts_custom"
            )
        )
    }

    func applyAssistantRoutingOutcomes(_ outcomes: [ShortcutEventRoutingOutcome]) {
        for outcome in outcomes {
            switch outcome {
            case let .detected(source, trigger):
                emitShortcutDetected(
                    shortcutTarget: "assistant",
                    source: source,
                    trigger: trigger
                )
            case let .rejected(source, trigger, reason):
                emitShortcutRejected(
                    shortcutTarget: "assistant",
                    source: source,
                    trigger: trigger,
                    reason: reason
                )
            case let .dispatchDown(activationMode):
                Task { @MainActor [weak self] in
                    await self?.handleShortcutDown(activationModeOverride: activationMode)
                }
            case let .dispatchUp(activationMode):
                Task { @MainActor [weak self] in
                    await self?.handleShortcutUp(activationModeOverride: activationMode)
                }
            }
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
