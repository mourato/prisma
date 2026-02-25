import Combine
import Foundation
import MeetingAssistantCore

@MainActor
final class AssistantShortcutController {
    let assistantService: AssistantVoiceCommandService
    let settings: AppSettingsStore
    var cancellables = Set<AnyCancellable>()

    let inputBackend: ShortcutInputBackend
    let shortcutRouter = ShortcutEventRoutingOrchestrator()
    var integrationShortcutHandlers: [UUID: SmartShortcutHandler] = [:]
    var integrationPresetStates: [UUID: ShortcutActivationState] = [:]
    var registeredIntegrationShortcutIDs = Set<UUID>()
    let layerTimeoutNanoseconds: UInt64 = 1_000_000_000
    var shortcutLayerStateMachine = AssistantShortcutLayerStateMachine()
    var shortcutLayerTask: Task<Void, Never>?
    var lastLayerLeaderTapTime: Date?
    let shortcutLayerFeedbackController = ShortcutLayerFeedbackController()
    let shortcutLayerKeySuppressor = ShortcutLayerKeySuppressor()
    let returnKeyCode: UInt16 = 0x24
    let keypadEnterKeyCode: UInt16 = 0x4c

    // MARK: - Integration Leader Mode (P2.2)
    /// State machine for integration leader mode
    var integrationLeaderModeStateMachine = IntegrationLeaderModeStateMachine()
    /// Task for integration leader mode timeout
    var integrationLeaderModeTask: Task<Void, Never>?
    /// Timeout for integration leader mode action waiting (2 seconds as per P2.2)
    let integrationLeaderModeTimeoutSeconds: TimeInterval = 2.0

    var isShortcutLayerArmed: Bool {
        shortcutLayerStateMachine.state == .armed
    }

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
    let healthCheckIntervalSeconds: TimeInterval = 15
    var healthCheckTimer: Timer?
    var shortcutCaptureHealthSnapshot: ShortcutCaptureHealthSnapshot?

    init(
        assistantService: AssistantVoiceCommandService,
        settings: AppSettingsStore,
        inputBackend: ShortcutInputBackend? = nil
    ) {
        self.assistantService = assistantService
        self.settings = settings
        self.inputBackend = inputBackend ?? Self.makeDefaultInputBackend()
        configureInputBackendHandlers()
    }

    private static func makeDefaultInputBackend() -> ShortcutInputBackend {
        SystemShortcutInputBackend()
    }

    func emitShortcutDetected(
        shortcutTarget: String,
        source: String,
        trigger: ShortcutActivationMode
    ) {
        emitShortcutDetected(
            shortcutTarget: shortcutTarget,
            source: source,
            triggerToken: trigger.rawValue
        )
    }

    func emitShortcutDetected(
        shortcutTarget: String,
        source: String,
        triggerToken: String
    ) {
        ShortcutTelemetry.emit(
            .shortcutDetected(
                pipeline: "assistant_shortcuts",
                scope: "assistant",
                shortcutTarget: shortcutTarget,
                source: source,
                trigger: triggerToken
            ),
            category: .assistant
        )
    }

    func emitShortcutRejected(
        shortcutTarget: String,
        source: String,
        trigger: ShortcutActivationMode? = nil,
        reason: String
    ) {
        emitShortcutRejected(
            shortcutTarget: shortcutTarget,
            source: source,
            triggerToken: triggerToken(for: trigger),
            reason: reason
        )
    }

    func emitShortcutRejected(
        shortcutTarget: String,
        source: String,
        triggerToken: String,
        reason: String
    ) {
        ShortcutTelemetry.emit(
            .shortcutRejected(
                pipeline: "assistant_shortcuts",
                scope: "assistant",
                shortcutTarget: shortcutTarget,
                source: source,
                trigger: triggerToken,
                reason: reason
            ),
            category: .assistant
        )
    }

    func emitPermissionBlocked(
        permission: String,
        accessibilityTrusted: Bool,
        inputMonitoringTrusted: Bool
    ) {
        ShortcutTelemetry.emit(
            .permissionBlocked(
                pipeline: "assistant_shortcuts",
                scope: "assistant",
                permission: permission,
                accessibilityTrusted: accessibilityTrusted,
                inputMonitoringTrusted: inputMonitoringTrusted
            ),
            category: .assistant
        )
    }

    func emitLayerArmed(source: String, trigger: String) {
        ShortcutTelemetry.emit(
            .layerArmed(
                pipeline: "assistant_shortcuts",
                scope: "assistant",
                source: source,
                trigger: trigger,
                timeoutMs: layerTimeoutMilliseconds
            ),
            category: .assistant
        )
    }

    func emitLayerTimeout(source: String) {
        ShortcutTelemetry.emit(
            .layerTimeout(
                pipeline: "assistant_shortcuts",
                scope: "assistant",
                source: source,
                timeoutMs: layerTimeoutMilliseconds
            ),
            category: .assistant
        )
    }

    func emitEventTapFallback(
        fallbackMode: String,
        reason: String,
        inputMonitoringTrusted: Bool?
    ) {
        ShortcutTelemetry.emit(
            .eventTapFallback(
                pipeline: "assistant_shortcuts",
                scope: "assistant",
                fallbackMode: fallbackMode,
                reason: reason,
                inputMonitoringTrusted: inputMonitoringTrusted
            ),
            category: .assistant
        )
    }

    var layerTimeoutMilliseconds: Int {
        Int(layerTimeoutNanoseconds / 1_000_000)
    }

    func triggerToken(for mode: ShortcutActivationMode?) -> String {
        mode?.rawValue ?? "unknown"
    }

    convenience init(assistantService: AssistantVoiceCommandService) {
        self.init(
            assistantService: assistantService,
            settings: .shared,
            inputBackend: nil
        )
    }

    private func configureInputBackendHandlers() {
        inputBackend.setFlagsChangedHandler { [weak self] event in
            self?.handleFlagsChanged(event)
        }

        inputBackend.setKeyDownHandler { [weak self] event in
            self?.handleKeyDown(event)
        }

        inputBackend.setKeyUpHandler { [weak self] event in
            self?.handleKeyUp(event)
        }
    }

    deinit {
        Task { @MainActor [weak self] in
            self?.stopShortcutCaptureHealthChecks()
            self?.removeEventMonitors()
        }
    }
}
