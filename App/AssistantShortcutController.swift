import Combine
import Foundation
import MeetingAssistantCore

@MainActor
final class AssistantShortcutController {
    let assistantService: AssistantVoiceCommandService
    let settings: AppSettingsStore
    var cancellables = Set<AnyCancellable>()

    var flagsMonitor: KeyboardEventMonitor?
    var keyDownMonitor: KeyboardEventMonitor?
    var keyUpMonitor: KeyboardEventMonitor?
    var integrationShortcutHandlers: [UUID: SmartShortcutHandler] = [:]
    var integrationPresetStates: [UUID: ShortcutActivationState] = [:]
    var registeredIntegrationShortcutIDs = Set<UUID>()
    let layerTimeoutNanoseconds: UInt64 = 1_000_000_000
    var isShortcutLayerArmed = false
    var shortcutLayerTask: Task<Void, Never>?
    var lastLayerLeaderTapTime: Date?
    let shortcutLayerFeedbackController = ShortcutLayerFeedbackController()
    let shortcutLayerKeySuppressor = ShortcutLayerKeySuppressor()
    let returnKeyCode: UInt16 = 0x24
    let keypadEnterKeyCode: UInt16 = 0x4c

    lazy var shortcutHandler = SmartShortcutHandler(
        doubleTapInterval: currentDoubleTapInterval,
        isRecordingProvider: { [weak self] in self?.assistantService.isRecording ?? false },
        actionHandler: { [weak self] (action: SmartShortcutHandler.Action) in
            guard let self else { return }
            Task {
                await self.performAction(action)
            }
        }
    )

    let presetState = ShortcutActivationState()
    let escapeDoublePressInterval: TimeInterval = 1.0
    var lastEscapePressTime: Date?
    var hasRequestedAccessibilityPermissionForGlobalCapture = false
    var hasRequestedInputMonitoringPermissionForGlobalCapture = false
    var hasOpenedAccessibilitySettingsForGlobalCapture = false
    var hasOpenedInputMonitoringSettingsForGlobalCapture = false

    init(
        assistantService: AssistantVoiceCommandService,
        settings: AppSettingsStore
    ) {
        self.assistantService = assistantService
        self.settings = settings
    }

    convenience init(assistantService: AssistantVoiceCommandService) {
        self.init(assistantService: assistantService, settings: .shared)
    }

    deinit {
        Task { @MainActor [weak self] in
            self?.removeEventMonitors()
        }
    }
}
