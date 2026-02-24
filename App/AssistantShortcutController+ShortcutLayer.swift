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

    func refreshShortcutLayerKeySuppression() {
        guard shouldSuppressKeyDownEvents else {
            shortcutLayerKeySuppressor.stop()
            return
        }

        shortcutLayerKeySuppressor.start { [weak self] event in
            guard let self else { return false }
            if self.handleShortcutLayerKeyDown(event) {
                return true
            }
            return self.handleSingleEnterStop(event)
        }
    }

    func armShortcutLayer() {
        isShortcutLayerArmed = true
        refreshShortcutLayerKeySuppression()
        shortcutLayerFeedbackController.showArmed()

        let timeoutNanoseconds = layerTimeoutNanoseconds
        shortcutLayerTask?.cancel()
        shortcutLayerTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: timeoutNanoseconds)
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
        armShortcutLayer()
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
            disarmShortcutLayer(showFeedback: true)
            return true
        }

        let relevantFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            .subtracting(.capsLock)
            .subtracting(.shift)
        guard relevantFlags.isEmpty else {
            return true
        }

        guard let matched = matchedLayerAction(for: event) else {
            disarmShortcutLayer(showFeedback: false)
            return true
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
            return true
        default:
            return false
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
