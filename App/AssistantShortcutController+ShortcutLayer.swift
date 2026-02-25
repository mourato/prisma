import AppKit
import MeetingAssistantCore

@MainActor
extension AssistantShortcutController {
    private typealias ShortcutLayerEvent = AssistantShortcutLayerStateMachine.Event

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

    @discardableResult
    private func transitionShortcutLayer(
        on event: ShortcutLayerEvent,
        source: String
    ) -> AssistantShortcutLayerStateMachine.Transition {
        let transition = shortcutLayerStateMachine.transition(on: event)
        guard !transition.isValid else {
            return transition
        }

        AppLogger.debug(
            "Shortcut layer FSM ignored invalid transition",
            category: .assistant,
            extra: [
                "source": source,
                "event": event.rawValue,
                "state": transition.from.rawValue,
            ]
        )
        return transition
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
        _ = transitionShortcutLayer(on: .leaderTapped, source: source)
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
            self?.handleShortcutLayerTimeout(source: source)
        }
    }

    func disarmShortcutLayer(
        showFeedback: Bool,
        event: AssistantShortcutLayerStateMachine.Event = .disarmedExplicitly,
        transitionSource: String = "unknown"
    ) {
        _ = transitionShortcutLayer(on: event, source: transitionSource)
        if shortcutLayerStateMachine.state != .idle {
            _ = transitionShortcutLayer(on: .disarmedExplicitly, source: "\(transitionSource)_to_idle")
        }

        refreshShortcutLayerKeySuppression()
        shortcutLayerTask?.cancel()
        shortcutLayerTask = nil

        if showFeedback {
            shortcutLayerFeedbackController.showCancelled()
        } else {
            shortcutLayerFeedbackController.hide()
        }
    }

    private func handleShortcutLayerTimeout(source: String) {
        let transition = transitionShortcutLayer(on: .timeoutElapsed, source: source)
        guard transition.isValid else {
            return
        }

        emitLayerTimeout(source: source)
        disarmShortcutLayer(
            showFeedback: false,
            event: .disarmedExplicitly,
            transitionSource: "timeout_finalize"
        )
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
        // First check if integration leader mode is active
        if isIntegrationLeaderModeActive {
            return handleIntegrationLeaderModeKeyDown(event)
        }

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
            return handleShortcutLayerEscapeKey(event)
        }

        let relevantFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            .subtracting(.capsLock)
            .subtracting(.shift)
        guard relevantFlags.isEmpty else {
            return true
        }

        return handleShortcutLayerMatchedKey(event)
    }

    private func handleShortcutLayerEscapeKey(_ event: NSEvent) -> Bool {
        AppLogger.debug(
            "ESC received while shortcut layer is armed",
            category: .assistant,
            extra: [
                "scope": "assistant",
                "propagateForDoublePress": shouldPropagateEscapeForDoublePressCancel,
                "assistantIsRecording": assistantService.isRecording,
            ]
        )

        if shouldPropagateEscapeForDoublePressCancel {
            if assistantService.isRecording {
                disarmShortcutLayer(
                    showFeedback: false,
                    event: .cancelledByEscapeOrBlur,
                    transitionSource: "escape_propagated_recording"
                )
            } else {
                disarmShortcutLayer(
                    showFeedback: true,
                    event: .cancelledByEscapeOrBlur,
                    transitionSource: "escape_propagated_idle"
                )
            }
            AppLogger.debug(
                "ESC propagated from shortcut layer to double-press handlers",
                category: .assistant,
                extra: ["scope": "assistant"]
            )
            return false
        }

        disarmShortcutLayer(
            showFeedback: true,
            event: .cancelledByEscapeOrBlur,
            transitionSource: "escape_consumed"
        )
        AppLogger.debug(
            "ESC consumed by shortcut layer because escape cancel is disabled",
            category: .assistant,
            extra: ["scope": "assistant"]
        )
        return true
    }

    private func handleShortcutLayerMatchedKey(_ event: NSEvent) -> Bool {
        guard let matched = matchedLayerAction(for: event) else {
            emitShortcutRejected(
                shortcutTarget: "assistant",
                source: "shortcut_layer_key",
                triggerToken: "singleTap",
                reason: "no_layer_match"
            )
            disarmShortcutLayer(
                showFeedback: false,
                event: .disarmedExplicitly,
                transitionSource: "layer_key_unmatched"
            )
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
        case .integrationLeaderMode:
            break
        }

        _ = transitionShortcutLayer(on: .layerKeyMatched, source: "layer_key_match")

        switch matched {
        case .assistant, .integration:
            disarmShortcutLayer(
                showFeedback: false,
                event: .disarmedExplicitly,
                transitionSource: "layer_key_match_finalize"
            )
            shortcutLayerFeedbackController.showTriggered()
            Task { @MainActor [weak self] in
                await self?.executeLayerAction(matched)
            }
        case .integrationLeaderMode(let integrationID):
            disarmShortcutLayer(
                showFeedback: false,
                event: .disarmedExplicitly,
                transitionSource: "layer_key_match_leader_mode"
            )
            armIntegrationLeaderMode(for: integrationID, source: "layer_key_match")
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
        /// Integration that should wait for leader mode action
        case integrationLeaderMode(UUID)
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
            // Check if this integration has leader mode enabled
            if integration.leaderModeEnabled {
                return .integrationLeaderMode(integration.id)
            }
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
        case .integration(let integrationID):
            guard integration(for: integrationID)?.isEnabled == true else {
                return
            }
            settings.assistantSelectedIntegrationId = integrationID
            if assistantService.isRecording {
                await assistantService.stopAndProcess()
            } else {
                await assistantService.startRecording(flow: .integrationDispatch)
            }
        case .integrationLeaderMode:
            // Leader mode actions are handled separately in handleIntegrationLeaderModeActionKey
            break
        }
    }

    // MARK: - Integration Leader Mode (P2.2)

    /// Check if any integration has leader mode enabled
    var anyIntegrationLeaderModeEnabled: Bool {
        settings.assistantIntegrations.contains { integration in
            integration.isEnabled && integration.leaderModeEnabled
        }
    }

    /// Check if the shortcut layer should also handle integration leader mode
    var shouldUseIntegrationLeaderMode: Bool {
        shouldUseAssistantShortcutLayer && anyIntegrationLeaderModeEnabled
    }

    /// Get integrations that have leader mode enabled
    var leaderModeEnabledIntegrations: [AssistantIntegrationConfig] {
        settings.assistantIntegrations.filter { integration in
            integration.isEnabled && integration.leaderModeEnabled
        }
    }

    /// Arm integration leader mode for a specific integration
    func armIntegrationLeaderMode(for integrationID: UUID, source: String = "unknown") {
        // Configure FSM with timeout
        integrationLeaderModeStateMachine.actionTimeoutSeconds = integrationLeaderModeTimeoutSeconds

        let transition = integrationLeaderModeStateMachine.leaderPressed(for: integrationID)

        guard transition.isValid else {
            AppLogger.debug(
                "Integration leader mode FSM ignored invalid transition",
                category: .assistant,
                extra: [
                    "source": source,
                    "integrationID": integrationID.uuidString,
                    "event": transition.event.rawValue,
                    "state": transition.from.rawValue,
                ]
            )
            return
        }

        emitIntegrationLeaderArmed(integrationID: integrationID, source: source)

        // Start timeout task
        integrationLeaderModeTask?.cancel()
        integrationLeaderModeTask = Task { @MainActor [weak self] in
            do {
                let timeoutNS = self?.integrationLeaderModeStateMachine.actionTimeoutNanoseconds ?? 2_000_000_000
                try await Task.sleep(nanoseconds: timeoutNS)
            } catch {
                return
            }
            self?.handleIntegrationLeaderModeTimeout(integrationID: integrationID)
        }

        // Show visual feedback that we're waiting for action
        shortcutLayerFeedbackController.showArmed()
    }

    /// Handle key down event while integration leader mode is active
    func handleIntegrationLeaderModeKeyDown(_ event: NSEvent) -> Bool {
        guard integrationLeaderModeStateMachine.isWaitingForAction else {
            return false
        }

        guard !event.isARepeat else {
            return true
        }

        // Handle ESC key - cancel leader mode
        if event.keyCode == PresetShortcutKey.escapeKeyCode {
            cancelIntegrationLeaderMode(cancelledByEscape: true)
            return true
        }

        // Ignore modifier keys
        if isModifierKeyCode(event.keyCode) {
            return true
        }

        // Check for relevant modifiers (should be none for action key)
        let relevantFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            .subtracting(.capsLock)
            .subtracting(.shift)
        guard relevantFlags.isEmpty else {
            // Modifier pressed while waiting - treat as action key
            return handleIntegrationLeaderModeActionKey(integrationID: nil, event: event)
        }

        // Any non-modifier key can be the action key
        return handleIntegrationLeaderModeActionKey(integrationID: nil, event: event)
    }

    /// Handle action key pressed during integration leader mode
    private func handleIntegrationLeaderModeActionKey(integrationID: UUID?, event: NSEvent) -> Bool {
        let transition = integrationLeaderModeStateMachine.actionKeyPressed()

        guard transition.isValid else {
            AppLogger.debug(
                "Integration leader mode action key ignored",
                category: .assistant,
                extra: [
                    "keyCode": event.keyCode,
                    "state": integrationLeaderModeStateMachine.state.rawValue,
                ]
            )
            return false
        }

        // Get the active integration ID from FSM
        guard let triggeredIntegrationID = integrationLeaderModeStateMachine.activeIntegrationID else {
            AppLogger.warning(
                "Integration leader mode triggered but no integration ID",
                category: .assistant
            )
            cancelIntegrationLeaderMode(cancelledByEscape: false)
            return true
        }

        // Cancel timeout task
        integrationLeaderModeTask?.cancel()
        integrationLeaderModeTask = nil

        // Emit telemetry
        emitIntegrationLeaderActionTriggered(integrationID: triggeredIntegrationID)

        // Execute the integration action
        Task { @MainActor [weak self] in
            await self?.executeIntegrationLeaderAction(integrationID: triggeredIntegrationID)
        }

        // Reset FSM
        integrationLeaderModeStateMachine.reset()

        return true
    }

    /// Handle timeout during integration leader mode
    private func handleIntegrationLeaderModeTimeout(integrationID: UUID) {
        let transition = integrationLeaderModeStateMachine.timeoutElapsed()

        guard transition.isValid else {
            return
        }

        emitIntegrationLeaderTimeout(integrationID: integrationID)
        cancelIntegrationLeaderMode(cancelledByEscape: false)
    }

    /// Cancel integration leader mode
    func cancelIntegrationLeaderMode(cancelledByEscape: Bool) {
        integrationLeaderModeTask?.cancel()
        integrationLeaderModeTask = nil

        let event: IntegrationLeaderModeStateMachine.IntegrationEvent = cancelledByEscape
            ? .cancelledByEscapeOrBlur
            : .disarmedExplicitly

        _ = integrationLeaderModeStateMachine.transition(on: event)

        shortcutLayerFeedbackController.showCancelled()
    }

    /// Check if integration leader mode is currently active
    var isIntegrationLeaderModeActive: Bool {
        integrationLeaderModeStateMachine.isWaitingForAction
    }

    /// Execute the integration action after leader mode triggers
    private func executeIntegrationLeaderAction(integrationID: UUID) async {
        guard let integration = integration(for: integrationID),
              integration.isEnabled else {
            emitShortcutRejected(
                shortcutTarget: "integration",
                source: "integration_leader_mode",
                triggerToken: "leaderAction",
                reason: "integration_unavailable"
            )
            return
        }

        settings.assistantSelectedIntegrationId = integrationID

        emitShortcutDetected(
            shortcutTarget: "integration",
            source: "integration_leader_mode",
            triggerToken: "leaderAction"
        )

        if assistantService.isRecording {
            await assistantService.stopAndProcess()
        } else {
            await assistantService.startRecording(flow: .integrationDispatch)
        }
    }

    // MARK: - Integration Leader Mode Telemetry

    private func emitIntegrationLeaderArmed(integrationID: UUID, source: String) {
        ShortcutTelemetry.emit(
            .layerArmed(
                pipeline: "assistant_shortcuts",
                scope: "integration_leader_mode",
                source: source,
                trigger: "leaderPress",
                timeoutMs: Int(integrationLeaderModeTimeoutSeconds * 1000)
            ),
            category: .assistant
        )
    }

    private func emitIntegrationLeaderActionTriggered(integrationID: UUID) {
        ShortcutTelemetry.emit(
            .shortcutDetected(
                pipeline: "assistant_shortcuts",
                scope: "integration_leader_mode",
                shortcutTarget: integrationID.uuidString,
                source: "leaderAction",
                trigger: "actionKey"
            ),
            category: .assistant
        )
    }

    private func emitIntegrationLeaderTimeout(integrationID: UUID) {
        ShortcutTelemetry.emit(
            .layerTimeout(
                pipeline: "assistant_shortcuts",
                scope: "integration_leader_mode",
                source: "leaderMode",
                timeoutMs: Int(integrationLeaderModeTimeoutSeconds * 1000)
            ),
            category: .assistant
        )
    }
}
