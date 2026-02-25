import AppKit
import MeetingAssistantCore

@MainActor
extension AssistantShortcutController {
    var shouldUseAssistantShortcutLayer: Bool {
        guard settings.assistantShortcutDefinition != nil else {
            return false
        }

        if !settings.assistantLayerShortcutKey.isEmpty {
            return true
        }

        return settings.assistantIntegrations.contains { integration in
            integration.isEnabled && !(integration.layerShortcutKey ?? "").isEmpty
        }
    }

    var shouldSuppressEnterStopWhileRecording: Bool {
        AssistantShortcutSuppressionPolicy.shouldSuppressEnterStopWhileRecording(
            assistantUseEnterToStopRecording: settings.assistantUseEnterToStopRecording,
            isAssistantRecording: assistantService.isRecording
        )
    }

    var shouldSuppressKeyDownEvents: Bool {
        AssistantShortcutSuppressionPolicy.shouldSuppressKeyDownEvents(
            shouldUseAssistantShortcutLayer: shouldUseAssistantShortcutLayer,
            isShortcutLayerArmed: isShortcutLayerArmed,
            shouldSuppressEnterStopWhileRecording: shouldSuppressEnterStopWhileRecording
        )
    }

    private var shouldPropagateEscapeForDoublePressCancel: Bool {
        settings.assistantUseEscapeToCancelRecording || settings.useEscapeToCancelRecording
    }

    func refreshShortcutLayerKeySuppression() {
        guard shouldSuppressKeyDownEvents else {
            shortcutLayerKeySuppressor.stop()
            AppLogger.debug(
                "Shortcut layer key suppressor disabled",
                category: .assistant,
                extra: [
                    "shouldSuppressKeyDownEvents": shouldSuppressKeyDownEvents,
                    "shortcutLayerEnabled": shouldUseAssistantShortcutLayer,
                    "shortcutLayerArmed": isShortcutLayerArmed,
                    "assistantIsRecording": assistantService.isRecording,
                ]
            )
            return
        }

        let accessibilityTrusted = AccessibilityPermissionService.isTrusted()
        let inputMonitoringTrusted = InputMonitoringPermissionService.isTrusted()
        guard inputMonitoringTrusted else {
            shortcutLayerKeySuppressor.stop()
            emitPermissionBlocked(
                permission: "input_monitoring",
                accessibilityTrusted: accessibilityTrusted,
                inputMonitoringTrusted: inputMonitoringTrusted
            )
            emitEventTapFallback(
                fallbackMode: "monitor_only",
                reason: "input_monitoring_denied",
                inputMonitoringTrusted: inputMonitoringTrusted
            )
            AppLogger.warning(
                "Shortcut layer key suppressor unavailable due to Input Monitoring permission",
                category: .assistant,
                extra: [
                    "shortcutLayerEnabled": shouldUseAssistantShortcutLayer,
                    "shortcutLayerArmed": isShortcutLayerArmed,
                    "accessibilityTrusted": accessibilityTrusted,
                    "inputMonitoringTrusted": inputMonitoringTrusted,
                ]
            )
            return
        }

        AppLogger.debug(
            "Shortcut layer key suppressor enabled",
            category: .assistant,
            extra: [
                "shouldSuppressKeyDownEvents": shouldSuppressKeyDownEvents,
                "shortcutLayerEnabled": shouldUseAssistantShortcutLayer,
                "shortcutLayerArmed": isShortcutLayerArmed,
                "assistantIsRecording": assistantService.isRecording,
            ]
        )

        let didStartSuppressor = shortcutLayerKeySuppressor.start { [weak self] event in
            guard let self else { return false }
            if handleShortcutLayerKeyDown(event) {
                return true
            }
            return handleSingleEnterStop(event)
        }

        if !didStartSuppressor {
            let reason = shortcutLayerKeySuppressor.lastStartFailureReason?.rawValue ?? "event_tap_unavailable"
            emitEventTapFallback(
                fallbackMode: "monitor_only",
                reason: reason,
                inputMonitoringTrusted: inputMonitoringTrusted
            )
            AppLogger.warning(
                "Shortcut layer key suppressor unavailable; using monitor-only fallback",
                category: .assistant,
                extra: [
                    "shortcutLayerEnabled": shouldUseAssistantShortcutLayer,
                    "shortcutLayerArmed": isShortcutLayerArmed,
                    "accessibilityTrusted": accessibilityTrusted,
                    "inputMonitoringTrusted": inputMonitoringTrusted,
                ]
            )
        }
    }

    func armShortcutLayer(source: String = "unknown", trigger: String = "unknown") {
        isShortcutLayerArmed = true
        emitLayerArmed(source: source, trigger: trigger)
        refreshShortcutLayerKeySuppression()
        shortcutLayerFeedbackController.showArmed()

        let timeoutNanoseconds = layerTimeoutNanoseconds
        shortcutLayerTask?.cancel()
        shortcutLayerTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: timeoutNanoseconds)
            } catch {
                return
            }
            self?.emitLayerTimeout(source: source)
            self?.disarmShortcutLayer(showFeedback: false)
        }
    }

    func disarmShortcutLayer(showFeedback: Bool) {
        isShortcutLayerArmed = false
        refreshShortcutLayerKeySuppression()
        shortcutLayerTask?.cancel()
        shortcutLayerTask = nil

        if showFeedback {
            shortcutLayerFeedbackController.showCancelled()
        } else {
            shortcutLayerFeedbackController.hide()
        }
    }

    func registerLayerLeaderTap() {
        let now = Date()
        guard let previousTap = lastLayerLeaderTapTime else {
            lastLayerLeaderTapTime = now
            return
        }

        let elapsed = now.timeIntervalSince(previousTap)
        guard elapsed <= currentDoubleTapInterval else {
            lastLayerLeaderTapTime = now
            return
        }

        lastLayerLeaderTapTime = nil
        armShortcutLayer(source: "leader_double_tap", trigger: "doubleTap")
    }

    func handleShortcutLayerKeyDown(_ event: NSEvent) -> Bool {
        guard shouldUseAssistantShortcutLayer, isShortcutLayerArmed else {
            return false
        }

        guard !event.isARepeat else {
            return true
        }

        if isModifierKeyCode(event.keyCode) {
            return true
        }

        if event.keyCode == PresetShortcutKey.escapeKeyCode {
            AppLogger.debug(
                "ESC received while shortcut layer is armed",
                category: .assistant,
                extra: [
                    "scope": "assistant",
                    "propagateForDoublePress": shouldPropagateEscapeForDoublePressCancel,
                    "assistantIsRecording": assistantService.isRecording,
                ]
            )
            // Always allow Escape to propagate when double-press cancel is enabled
            // for either Assistant or Dictation mode.
            if shouldPropagateEscapeForDoublePressCancel {
                // If recording, disarm the layer silently
                if assistantService.isRecording {
                    disarmShortcutLayer(showFeedback: false)
                } else {
                    // If not recording, just disarm with feedback
                    disarmShortcutLayer(showFeedback: true)
                }
                // Always allow the event to propagate so GlobalShortcutController
                // (for Dictation) or AssistantShortcuts (for Assistant) can handle it
                AppLogger.debug(
                    "ESC propagated from shortcut layer to double-press handlers",
                    category: .assistant,
                    extra: ["scope": "assistant"]
                )
                return false
            }
            // Escape double-press cancel is disabled for both modes; just disarm the layer
            disarmShortcutLayer(showFeedback: true)
            AppLogger.debug(
                "ESC consumed by shortcut layer because escape cancel is disabled",
                category: .assistant,
                extra: ["scope": "assistant"]
            )
            return true
        }

        let relevantFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            .subtracting(.capsLock)
            .subtracting(.shift)
        guard relevantFlags.isEmpty else {
            return true
        }

        guard let matched = matchedLayerAction(for: event) else {
            emitShortcutRejected(
                shortcutTarget: "assistant",
                source: "shortcut_layer_key",
                triggerToken: "singleTap",
                reason: "no_layer_match"
            )
            disarmShortcutLayer(showFeedback: false)
            return true
        }

        switch matched {
        case .assistant:
            emitShortcutDetected(
                shortcutTarget: "assistant",
                source: "shortcut_layer_key",
                triggerToken: "singleTap"
            )
        case .integration:
            emitShortcutDetected(
                shortcutTarget: "integration",
                source: "shortcut_layer_key",
                triggerToken: "singleTap"
            )
        }

        disarmShortcutLayer(showFeedback: false)
        shortcutLayerFeedbackController.showTriggered()
        Task { @MainActor [weak self] in
            await self?.executeLayerAction(matched)
        }
        return true
    }

    func isModifierKeyCode(_ keyCode: UInt16) -> Bool {
        switch keyCode {
        case PresetShortcutKey.leftCommandKeyCode,
             PresetShortcutKey.rightCommandKeyCode,
             PresetShortcutKey.leftOptionKeyCode,
             PresetShortcutKey.rightOptionKeyCode,
             PresetShortcutKey.leftShiftKeyCode,
             PresetShortcutKey.rightShiftKeyCode,
             PresetShortcutKey.leftControlKeyCode,
             PresetShortcutKey.rightControlKeyCode,
             PresetShortcutKey.fnKeyCode:
            true
        default:
            false
        }
    }

    private enum LayerAction {
        case assistant
        case integration(UUID)
    }

    private func matchedLayerAction(for event: NSEvent) -> LayerAction? {
        guard let rawCharacter = event.charactersIgnoringModifiers?.first else {
            return nil
        }

        let inputKey = String(rawCharacter).uppercased()

        if settings.assistantLayerShortcutKey == inputKey {
            return .assistant
        }

        if let integration = settings.assistantIntegrations.first(where: { integration in
            integration.isEnabled && integration.layerShortcutKey == inputKey
        }) {
            return .integration(integration.id)
        }

        return nil
    }

    private func executeLayerAction(_ action: LayerAction) async {
        switch action {
        case .assistant:
            if assistantService.isRecording {
                await assistantService.stopAndProcess()
            } else {
                await assistantService.startRecording(flow: .assistantMode)
            }
        case let .integration(integrationID):
            guard integration(for: integrationID)?.isEnabled == true else {
                return
            }
            settings.assistantSelectedIntegrationId = integrationID
            if assistantService.isRecording {
                await assistantService.stopAndProcess()
            } else {
                await assistantService.startRecording(flow: .integrationDispatch)
            }
        }
    }
}
