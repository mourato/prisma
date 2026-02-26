import Combine
import Foundation
import MeetingAssistantCore

@MainActor
final class AssistantShortcutController {
    let assistantService: AssistantVoiceCommandService
    let settings: AppSettingsStore
    var cancellables = Set<AnyCancellable>()

    let inputBackend: ShortcutInputBackend
    let hotkeyBackend: GlobalHotkeyBackend
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

    // MARK: - Integration Leader Mode (legacy state retained, currently disabled in global path)
    var integrationLeaderModeStateMachine = IntegrationLeaderModeStateMachine()
    var integrationLeaderModeTask: Task<Void, Never>?
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
    let healthCheckIntervalSeconds: TimeInterval = 15
    var healthCheckTimer: Timer?
    var shortcutCaptureHealthSnapshot: ShortcutCaptureHealthSnapshot?

    init(
        assistantService: AssistantVoiceCommandService,
        settings: AppSettingsStore,
        inputBackend: ShortcutInputBackend? = nil,
        hotkeyBackend: GlobalHotkeyBackend? = nil
    ) {
        self.assistantService = assistantService
        self.settings = settings
        self.inputBackend = inputBackend ?? Self.makeDefaultInputBackend()
        self.hotkeyBackend = hotkeyBackend ?? Self.makeDefaultHotkeyBackend()
        configureInputBackendHandlers()
    }

    private static func makeDefaultInputBackend() -> ShortcutInputBackend {
        SystemShortcutInputBackend()
    }

    private static func makeDefaultHotkeyBackend() -> GlobalHotkeyBackend {
        CarbonGlobalHotkeyBackend()
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
            inputBackend: nil,
            hotkeyBackend: nil
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

struct EscapeCancelState: Equatable {
    var isDictationRecordingActive: Bool
    var isAssistantRecordingActive: Bool
    var isDictationEscapeEnabled: Bool
    var isAssistantEscapeEnabled: Bool
}

@MainActor
final class EscapeCancelCoordinator {
    struct Targets: OptionSet, Equatable {
        let rawValue: Int

        static let dictation = Targets(rawValue: 1 << 0)
        static let assistant = Targets(rawValue: 1 << 1)
    }

    private let inputBackend: ShortcutInputBackend
    private let stateProvider: @MainActor () -> EscapeCancelState
    private let cancelDictation: @MainActor () async -> Void
    private let cancelAssistant: @MainActor () async -> Void
    private let escapeKeyCode: UInt16 = 0x35

    private var isStarted = false
    private var isKeyDownMonitoringActive = false
    private var doubleEscapeDetector: AppDoubleEscapePressDetector

    init(
        inputBackend: ShortcutInputBackend,
        doublePressInterval: TimeInterval = 1.0,
        stateProvider: @escaping @MainActor () -> EscapeCancelState,
        cancelDictation: @escaping @MainActor () async -> Void,
        cancelAssistant: @escaping @MainActor () async -> Void
    ) {
        self.inputBackend = inputBackend
        doubleEscapeDetector = AppDoubleEscapePressDetector(interval: doublePressInterval)
        self.stateProvider = stateProvider
        self.cancelDictation = cancelDictation
        self.cancelAssistant = cancelAssistant
        configureInputHandlers()
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        refresh()
    }

    func stop() {
        guard isStarted else { return }
        isStarted = false
        doubleEscapeDetector.reset()
        if isKeyDownMonitoringActive {
            inputBackend.stopKeyDownMonitoring()
            isKeyDownMonitoringActive = false
        }
    }

    func refresh() {
        guard isStarted else { return }

        let targets = activeTargets(for: stateProvider())
        let shouldMonitor = !targets.isEmpty

        if shouldMonitor {
            if !isKeyDownMonitoringActive {
                inputBackend.startKeyDownMonitoring(shouldReturnLocalEvent: nil)
                isKeyDownMonitoringActive = true
            }
        } else if isKeyDownMonitoringActive {
            inputBackend.stopKeyDownMonitoring()
            isKeyDownMonitoringActive = false
            doubleEscapeDetector.reset()
        }
    }

    private func configureInputHandlers() {
        inputBackend.setKeyDownHandler { [weak self] event in
            self?.handleKeyDown(event)
        }
    }

    private func handleKeyDown(_ event: ShortcutInputEvent) {
        guard event.keyCode == escapeKeyCode else { return }
        guard !event.isRepeat else { return }

        let targets = activeTargets(for: stateProvider())
        guard !targets.isEmpty else {
            doubleEscapeDetector.reset()
            return
        }

        let targetToken = String(targets.rawValue)
        guard doubleEscapeDetector.registerPress(token: targetToken) else {
            return
        }

        Task { @MainActor [cancelDictation, cancelAssistant] in
            if targets.contains(.assistant) {
                await cancelAssistant()
            }

            if targets.contains(.dictation) {
                await cancelDictation()
            }
        }
    }

    private func activeTargets(for state: EscapeCancelState) -> Targets {
        var targets: Targets = []

        if state.isAssistantEscapeEnabled, state.isAssistantRecordingActive {
            targets.insert(.assistant)
        }

        if state.isDictationEscapeEnabled, state.isDictationRecordingActive {
            targets.insert(.dictation)
        }

        return targets
    }
}

private struct AppDoubleEscapePressDetector {
    private let interval: TimeInterval
    private var pendingPressAt: Date?
    private var pendingToken: String?

    init(interval: TimeInterval) {
        self.interval = interval
    }

    mutating func registerPress(at now: Date = Date(), token: String) -> Bool {
        guard let pendingPressAt, let pendingToken else {
            self.pendingPressAt = now
            self.pendingToken = token
            return false
        }

        let elapsed = now.timeIntervalSince(pendingPressAt)
        guard elapsed <= interval, pendingToken == token else {
            self.pendingPressAt = now
            self.pendingToken = token
            return false
        }

        reset()
        return true
    }

    mutating func reset() {
        pendingPressAt = nil
        pendingToken = nil
    }
}
