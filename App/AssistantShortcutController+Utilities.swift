import AppKit
import MeetingAssistantCore

@MainActor
extension AssistantShortcutController {
    func resetShortcutState() {
        lastEscapePressTime = nil
        lastLayerLeaderTapTime = nil
        disarmShortcutLayer(showFeedback: false)
        presetState.reset()
        shortcutHandler.reset()
        integrationPresetStates.values.forEach { $0.reset() }
        integrationShortcutHandlers.values.forEach { $0.reset() }
    }

    var currentDoubleTapInterval: TimeInterval {
        settings.shortcutDoubleTapIntervalMilliseconds / 1_000
    }

    func applyGlobalDoubleTapInterval() {
        let interval = currentDoubleTapInterval
        shortcutHandler.setDoubleTapInterval(interval)
        integrationShortcutHandlers.values.forEach { $0.setDoubleTapInterval(interval) }
    }

    func handleSingleEnterStop(_ event: NSEvent) -> Bool {
        guard settings.assistantUseEnterToStopRecording else {
            return false
        }

        guard assistantService.isRecording else {
            return false
        }

        guard !event.isARepeat else {
            return false
        }

        guard event.keyCode == returnKeyCode || event.keyCode == keypadEnterKeyCode else {
            return false
        }

        let relevantFlags = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .numericPad])

        guard relevantFlags.isEmpty else {
            return false
        }

        Task { @MainActor [weak self] in
            await self?.assistantService.stopAndProcess()
        }

        return true
    }
}
