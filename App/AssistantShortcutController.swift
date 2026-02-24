import Combine
import Foundation
import MeetingAssistantCore

@MainActor
final class AssistantShortcutController {
    private let assistantService: AssistantVoiceCommandService
    private let settings: AppSettingsStore
    private var cancellables = Set<AnyCancellable>()

    private var flagsMonitor: KeyboardEventMonitor?
    private var keyDownMonitor: KeyboardEventMonitor?
    private var keyUpMonitor: KeyboardEventMonitor?
    private var integrationShortcutHandlers: [UUID: SmartShortcutHandler] = [:]
    private var integrationPresetStates: [UUID: ShortcutActivationState] = [:]
    private var registeredIntegrationShortcutIDs = Set<UUID>()
    private let layerTimeoutNanoseconds: UInt64 = 1_000_000_000
    private var isShortcutLayerArmed = false
    private var shortcutLayerTask: Task<Void, Never>?
    private var lastLayerLeaderTapTime: Date?
    private let shortcutLayerFeedbackController = ShortcutLayerFeedbackController()
    private let shortcutLayerKeySuppressor = ShortcutLayerKeySuppressor()
    private let returnKeyCode: UInt16 = 0x24
    private let keypadEnterKeyCode: UInt16 = 0x4c

    private lazy var shortcutHandler = SmartShortcutHandler(
        doubleTapInterval: currentDoubleTapInterval,
        isRecordingProvider: { [weak self] in self?.assistantService.isRecording ?? false },
        actionHandler: { [weak self] (action: SmartShortcutHandler.Action) in
            guard let self else { return }
            Task {
                await self.performAction(action)
            }
        }
    )

    private let presetState = ShortcutActivationState()
    private let escapeDoublePressInterval: TimeInterval = 1.0
    private var lastEscapePressTime: Date?

    deinit {
        Task { @MainActor [weak self] in
            self?.removeEventMonitors()
        }
    }
}
