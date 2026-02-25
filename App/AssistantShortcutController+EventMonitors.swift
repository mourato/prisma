import KeyboardShortcuts
import MeetingAssistantCore

@MainActor
extension AssistantShortcutController {
    func refreshEventMonitors() {
        if shouldUseAssistantShortcutLayer {
            installFlagsChangedMonitors()
            installKeyDownMonitors()
            removeKeyUpMonitors()
            ensureAccessibilityPermissionForGlobalCaptureIfNeeded(needsGlobalCapture: true)
            refreshShortcutLayerKeySuppression()
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

        let needsGlobalCapture = needsModifierMonitoring || needsShortcutKeyMonitoring || needsEscapeMonitoring || needsEnterStopMonitoring
        ensureAccessibilityPermissionForGlobalCaptureIfNeeded(needsGlobalCapture: needsGlobalCapture)
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
        if flagsMonitor == nil {
            flagsMonitor = KeyboardEventMonitor(mask: .flagsChanged) { [weak self] event in
                Task { @MainActor in
                    self?.handleFlagsChanged(event)
                }
            }
            flagsMonitor?.start()
        }
    }

    private func ensureAccessibilityPermissionForGlobalCaptureIfNeeded(needsGlobalCapture: Bool) {
        guard needsGlobalCapture else { return }
        guard !AccessibilityPermissionService.isTrusted() else { return }

        if !hasRequestedAccessibilityPermissionForGlobalCapture {
            hasRequestedAccessibilityPermissionForGlobalCapture = true
            AccessibilityPermissionService.requestPermission()
        }

        AppLogger.warning(
            "Assistant shortcut capture requires Accessibility permission",
            category: .assistant,
            extra: [
                "scope": "assistant",
                "needsGlobalCapture": needsGlobalCapture,
            ]
        )
    }

    private func removeFlagsChangedMonitors() {
        flagsMonitor?.stop()
        flagsMonitor = nil
    }

    private func installKeyDownMonitors() {
        if keyDownMonitor == nil {
            keyDownMonitor = KeyboardEventMonitor(
                mask: .keyDown,
                shouldReturnLocalEvent: { [weak self] event in
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
            ) { [weak self] event in
                Task { @MainActor in
                    self?.handleKeyDown(event)
                }
            }
            keyDownMonitor?.start()
        }
    }

    private func installKeyUpMonitors() {
        if keyUpMonitor == nil {
            keyUpMonitor = KeyboardEventMonitor(mask: .keyUp) { [weak self] event in
                Task { @MainActor in
                    self?.handleKeyUp(event)
                }
            }
            keyUpMonitor?.start()
        }
    }

    private func removeKeyDownMonitors() {
        keyDownMonitor?.stop()
        keyDownMonitor = nil
    }

    private func removeKeyUpMonitors() {
        keyUpMonitor?.stop()
        keyUpMonitor = nil
    }

    func removeEventMonitors() {
        removeFlagsChangedMonitors()
        removeKeyDownMonitors()
        removeKeyUpMonitors()
        shortcutLayerKeySuppressor.stop()
    }
}
