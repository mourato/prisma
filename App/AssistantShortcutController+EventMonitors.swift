import Foundation
import KeyboardShortcuts
import MeetingAssistantCore

@MainActor
extension AssistantShortcutController {
    func refreshEventMonitors() {
        let expectation = expectedShortcutCaptureBackends()

        if shouldUseAssistantShortcutLayer {
            installFlagsChangedMonitors()
            installKeyDownMonitors()
            removeKeyUpMonitors()
            ensureGlobalCapturePermissionsIfNeeded(needsGlobalCapture: expectation.needsGlobalCapture)
            refreshShortcutLayerKeySuppression()
            runShortcutCaptureHealthCheck(source: "refresh_event_monitors", expectation: expectation)
            AppLogger.debug(
                "Assistant monitor refresh",
                category: .assistant,
                extra: [
                    "shortcutLayer": true,
                    "isShortcutLayerArmed": isShortcutLayerArmed,
                    "shouldSuppressKeyDownEvents": shouldSuppressKeyDownEvents,
                    "assistantUseEscapeToCancelRecording": settings.assistantUseEscapeToCancelRecording,
                    "assistantUseEnterToStopRecording": settings.assistantUseEnterToStopRecording,
                ]
            )
            return
        }

        let needsModifierMonitoring = expectation.needsFlagsMonitor
        let needsShortcutKeyMonitoring = expectation.needsKeyUpMonitor
        let needsEscapeMonitoring = settings.assistantUseEscapeToCancelRecording
        let needsEnterStopMonitoring = settings.assistantUseEnterToStopRecording

        if needsModifierMonitoring {
            installFlagsChangedMonitors()
        } else {
            removeFlagsChangedMonitors()
        }

        if needsEscapeMonitoring || needsShortcutKeyMonitoring || needsEnterStopMonitoring {
            installKeyDownMonitors()
        } else {
            removeKeyDownMonitors()
        }

        if needsShortcutKeyMonitoring {
            installKeyUpMonitors()
        } else {
            removeKeyUpMonitors()
        }

        refreshShortcutLayerKeySuppression()

        AppLogger.debug(
            "Assistant monitor refresh",
            category: .assistant,
            extra: [
                "shortcutLayer": false,
                "needsModifierMonitoring": needsModifierMonitoring,
                "needsShortcutKeyMonitoring": needsShortcutKeyMonitoring,
                "needsEscapeMonitoring": needsEscapeMonitoring,
                "needsEnterStopMonitoring": needsEnterStopMonitoring,
                "assistantUseEscapeToCancelRecording": settings.assistantUseEscapeToCancelRecording,
                "assistantUseEnterToStopRecording": settings.assistantUseEnterToStopRecording,
                "shouldSuppressKeyDownEvents": shouldSuppressKeyDownEvents,
            ]
        )

        ensureGlobalCapturePermissionsIfNeeded(needsGlobalCapture: expectation.needsGlobalCapture)
        runShortcutCaptureHealthCheck(source: "refresh_event_monitors", expectation: expectation)
    }

    func refreshCustomShortcutRegistration() {
        switch settings.assistantSelectedPresetKey {
        case .custom where settings.assistantModifierShortcutGesture == nil && settings.assistantShortcutDefinition == nil:
            KeyboardShortcuts.enable(.assistantCommand)
        default:
            KeyboardShortcuts.disable(.assistantCommand)
        }
    }

    func refreshIntegrationCustomShortcutRegistrations() {
        let currentIDs = Set(settings.assistantIntegrations.map(\.id))
        for removedID in registeredIntegrationShortcutIDs.subtracting(currentIDs) {
            KeyboardShortcuts.disable(.assistantIntegration(removedID))
            integrationShortcutHandlers.removeValue(forKey: removedID)
            integrationPresetStates.removeValue(forKey: removedID)
        }

        for integration in settings.assistantIntegrations {
            let shortcutName = KeyboardShortcuts.Name.assistantIntegration(integration.id)

            if !registeredIntegrationShortcutIDs.contains(integration.id) {
                KeyboardShortcuts.onKeyDown(for: shortcutName) { [weak self] in
                    Task { @MainActor in
                        await self?.handleIntegrationCustomShortcutDown(integrationID: integration.id)
                    }
                }

                KeyboardShortcuts.onKeyUp(for: shortcutName) { [weak self] in
                    Task { @MainActor in
                        await self?.handleIntegrationCustomShortcutUp(integrationID: integration.id)
                    }
                }
            }

            if shouldUseAssistantShortcutLayer {
                KeyboardShortcuts.disable(shortcutName)
            } else if integration.isEnabled,
                      integration.shortcutDefinition == nil,
                      integration.modifierShortcutGesture == nil,
                      integration.shortcutPresetKey == .custom
            {
                KeyboardShortcuts.enable(shortcutName)
            } else {
                KeyboardShortcuts.disable(shortcutName)
            }
        }

        registeredIntegrationShortcutIDs = currentIDs
    }

    private func installFlagsChangedMonitors() {
        inputBackend.startFlagsChangedMonitoring()
    }

    private func ensureGlobalCapturePermissionsIfNeeded(needsGlobalCapture: Bool) {
        guard needsGlobalCapture else { return }

        let accessibilityTrusted = AccessibilityPermissionService.isTrusted()
        let inputMonitoringTrusted = InputMonitoringPermissionService.isTrusted()

        if !accessibilityTrusted,
           !hasRequestedAccessibilityPermissionForGlobalCapture
        {
            hasRequestedAccessibilityPermissionForGlobalCapture = true
            AccessibilityPermissionService.requestPermission()
            if !hasOpenedAccessibilitySettingsForGlobalCapture {
                hasOpenedAccessibilitySettingsForGlobalCapture = true
                AccessibilityPermissionService.openSystemSettings()
            }
        }

        if !inputMonitoringTrusted,
           !hasRequestedInputMonitoringPermissionForGlobalCapture
        {
            hasRequestedInputMonitoringPermissionForGlobalCapture = true
            let didRequest = InputMonitoringPermissionService.requestPermission()
            if !didRequest,
               !hasOpenedInputMonitoringSettingsForGlobalCapture
            {
                hasOpenedInputMonitoringSettingsForGlobalCapture = true
                InputMonitoringPermissionService.openSystemSettings()
            }
        }

        if !accessibilityTrusted || !inputMonitoringTrusted {
            emitPermissionBlocked(
                permission: "global_capture",
                accessibilityTrusted: accessibilityTrusted,
                inputMonitoringTrusted: inputMonitoringTrusted
            )
        }

        guard !accessibilityTrusted || !inputMonitoringTrusted else { return }

        AppLogger.warning(
            "Assistant shortcut capture missing required permissions",
            category: .assistant,
            extra: [
                "scope": "assistant",
                "needsGlobalCapture": needsGlobalCapture,
                "accessibilityTrusted": accessibilityTrusted,
                "inputMonitoringTrusted": inputMonitoringTrusted,
            ]
        )
    }

    private func removeFlagsChangedMonitors() {
        inputBackend.stopFlagsChangedMonitoring()
    }

    private func installKeyDownMonitors() {
        inputBackend.startKeyDownMonitoring { [weak self] event in
            guard let self else { return true }
            // Always allow Escape to propagate so GlobalShortcutController
            // can handle double-press cancel for Dictation mode
            if event.keyCode == PresetShortcutKey.escapeKeyCode {
                AppLogger.debug(
                    "ESC local propagation allowed (assistant keyDown monitor)",
                    category: .assistant,
                    extra: [
                        "scope": "assistant",
                        "shouldSuppressKeyDownEvents": self.shouldSuppressKeyDownEvents,
                        "shortcutLayerArmed": self.isShortcutLayerArmed,
                    ]
                )
                return true
            }

            let shouldReturn = !self.shouldSuppressKeyDownEvents
            if !shouldReturn {
                AppLogger.debug(
                    "Local keyDown suppressed by assistant policy",
                    category: .assistant,
                    extra: [
                        "scope": "assistant",
                        "keyCode": event.keyCode,
                        "shortcutLayerArmed": self.isShortcutLayerArmed,
                        "shouldSuppressEnterStopWhileRecording": self.shouldSuppressEnterStopWhileRecording,
                    ]
                )
            }
            return shouldReturn
        }
    }

    private func installKeyUpMonitors() {
        inputBackend.startKeyUpMonitoring()
    }

    private func removeKeyDownMonitors() {
        inputBackend.stopKeyDownMonitoring()
    }

    private func removeKeyUpMonitors() {
        inputBackend.stopKeyUpMonitoring()
    }

    func removeEventMonitors() {
        removeFlagsChangedMonitors()
        removeKeyDownMonitors()
        removeKeyUpMonitors()
        shortcutLayerKeySuppressor.stop()
        runShortcutCaptureHealthCheck(
            source: "event_monitors_removed",
            expectation: ShortcutCaptureBackendExpectation.none
        )
    }

    func expectedShortcutCaptureBackends() -> ShortcutCaptureBackendExpectation {
        let hasInHouseDefinitions = settings.assistantShortcutDefinition != nil
            || settings.assistantIntegrations.contains { integration in
                integration.isEnabled && integration.shortcutDefinition != nil
            }
        let needsModifierMonitoring = hasInHouseDefinitions
            || settings.assistantModifierShortcutGesture != nil
            || settings.assistantSelectedPresetKey.requiresModifierMonitoring
            || settings.assistantIntegrations.contains { integration in
                integration.isEnabled && (integration.modifierShortcutGesture != nil || integration.shortcutPresetKey.requiresModifierMonitoring)
            }
        let needsShortcutKeyMonitoring = hasInHouseDefinitions
        let needsEscapeMonitoring = settings.assistantUseEscapeToCancelRecording
        let needsEnterStopMonitoring = settings.assistantUseEnterToStopRecording

        if shouldUseAssistantShortcutLayer {
            return ShortcutCaptureBackendExpectation(
                needsGlobalCapture: true,
                needsFlagsMonitor: true,
                needsKeyDownMonitor: true,
                needsKeyUpMonitor: false,
                needsEventTap: shouldSuppressKeyDownEvents
            )
        }

        return ShortcutCaptureBackendExpectation(
            needsGlobalCapture: needsModifierMonitoring || needsShortcutKeyMonitoring || needsEscapeMonitoring || needsEnterStopMonitoring,
            needsFlagsMonitor: needsModifierMonitoring,
            needsKeyDownMonitor: needsEscapeMonitoring || needsShortcutKeyMonitoring || needsEnterStopMonitoring,
            needsKeyUpMonitor: needsShortcutKeyMonitoring,
            needsEventTap: false
        )
    }

    func startShortcutCaptureHealthChecks() {
        stopShortcutCaptureHealthChecks()
        runShortcutCaptureHealthCheck(source: "controller_start")

        let timer = Timer.scheduledTimer(withTimeInterval: healthCheckIntervalSeconds, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.runShortcutCaptureHealthCheck(source: "periodic")
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        healthCheckTimer = timer
    }

    func stopShortcutCaptureHealthChecks() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
    }

    func runShortcutCaptureHealthCheck(
        source: String,
        expectation: ShortcutCaptureBackendExpectation? = nil
    ) {
        let expectedBackends = expectation ?? expectedShortcutCaptureBackends()
        let previousSnapshot = shortcutCaptureHealthSnapshot
        let snapshot = ShortcutCaptureHealthSnapshot(
            pipeline: "assistant_shortcuts",
            scope: "assistant",
            source: source,
            expectation: expectedBackends,
            accessibilityTrusted: AccessibilityPermissionService.isTrusted(),
            inputMonitoringTrusted: InputMonitoringPermissionService.isTrusted(),
            flagsMonitorActive: inputBackend.isFlagsChangedMonitoringActive,
            keyDownMonitorActive: inputBackend.isKeyDownMonitoringActive,
            keyUpMonitorActive: inputBackend.isKeyUpMonitoringActive,
            eventTapActive: shortcutLayerKeySuppressor.isActive
        )

        shortcutCaptureHealthSnapshot = snapshot
        ShortcutCaptureHealthStore.updateHealth(
            scope: .assistant,
            result: snapshot.result.rawValue,
            reasonToken: snapshot.result == .degraded ? snapshot.reasonToken : "",
            requiresGlobalCapture: snapshot.requiresGlobalCapture,
            accessibilityTrusted: snapshot.accessibilityTrusted,
            inputMonitoringTrusted: snapshot.inputMonitoringTrusted,
            eventTapExpected: snapshot.eventTapExpected,
            eventTapActive: snapshot.eventTapActive
        )
        emitShortcutCaptureHealthTransitionIfNeeded(previous: previousSnapshot, current: snapshot)
    }

    func emitShortcutCaptureHealthTransitionIfNeeded(
        previous: ShortcutCaptureHealthSnapshot?,
        current: ShortcutCaptureHealthSnapshot
    ) {
        guard previous?.operationalSignature != current.operationalSignature else {
            return
        }

        ShortcutTelemetry.emit(
            .captureHealthChanged(
                pipeline: current.pipeline,
                scope: current.scope,
                source: current.source,
                result: current.result.rawValue,
                previousResult: previous?.result.rawValue,
                reason: current.result == .degraded ? current.reasonToken : nil,
                requiresGlobalCapture: current.requiresGlobalCapture,
                accessibilityTrusted: current.accessibilityTrusted,
                inputMonitoringTrusted: current.inputMonitoringTrusted,
                flagsMonitorExpected: current.flagsMonitorExpected,
                flagsMonitorActive: current.flagsMonitorActive,
                keyDownMonitorExpected: current.keyDownMonitorExpected,
                keyDownMonitorActive: current.keyDownMonitorActive,
                keyUpMonitorExpected: current.keyUpMonitorExpected,
                keyUpMonitorActive: current.keyUpMonitorActive,
                eventTapExpected: current.eventTapExpected,
                eventTapActive: current.eventTapActive,
                checkedAtEpochMs: Int64(current.checkedAt.timeIntervalSince1970 * 1_000)
            ),
            category: .assistant
        )

        let message = current.result == .degraded
            ? "Assistant shortcut capture health degraded"
            : "Assistant shortcut capture health updated"
        let extra: [String: Any] = [
            "scope": current.scope,
            "source": current.source,
            "result": current.result.rawValue,
            "previousResult": previous?.result.rawValue ?? "unknown",
            "reason": current.result == .degraded ? current.reasonToken : "none",
            "requiresGlobalCapture": current.requiresGlobalCapture,
        ]

        if current.result == .degraded {
            AppLogger.warning(message, category: .assistant, extra: extra)
        } else {
            AppLogger.info(message, category: .assistant, extra: extra)
        }
    }
}
