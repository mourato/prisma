import AppKit
import Combine
import KeyboardShortcuts
import MeetingAssistantCore

@MainActor
final class GlobalShortcutController {
    private let recordingManager: RecordingManager
    private let settings: AppSettingsStore
    private let hotkeyBackend: GlobalHotkeyBackend
    private var cancellables = Set<AnyCancellable>()
    private let shortcutRouter = ShortcutEventRoutingOrchestrator()

    private lazy var dictationHandler = SmartShortcutHandler(
        doubleTapInterval: currentDoubleTapInterval,
        isRecordingProvider: { [weak self] in self?.recordingManager.isRecording ?? false },
        actionHandler: { [weak self] action in
            Task { @MainActor [weak self] in
                await self?.performAction(action, for: .dictation)
            }
        }
    )

    private lazy var meetingHandler = SmartShortcutHandler(
        doubleTapInterval: currentDoubleTapInterval,
        isRecordingProvider: { [weak self] in self?.recordingManager.isRecording ?? false },
        actionHandler: { [weak self] action in
            Task { @MainActor [weak self] in
                await self?.performAction(action, for: .meeting)
            }
        }
    )

    private let healthCheckIntervalSeconds: TimeInterval = 15
    private var healthCheckTimer: Timer?
    private(set) var shortcutCaptureHealthSnapshot: ShortcutCaptureHealthSnapshot?

    init(
        recordingManager: RecordingManager,
        settings: AppSettingsStore,
        hotkeyBackend: GlobalHotkeyBackend? = nil
    ) {
        self.recordingManager = recordingManager
        self.settings = settings
        self.hotkeyBackend = hotkeyBackend ?? Self.makeDefaultHotkeyBackend()
    }

    private static func makeDefaultHotkeyBackend() -> GlobalHotkeyBackend {
        CarbonGlobalHotkeyBackend()
    }

    convenience init(recordingManager: RecordingManager) {
        self.init(recordingManager: recordingManager, settings: .shared, hotkeyBackend: nil)
    }

    func start() {
        migrateLegacyToggleRecordingShortcutIfNeeded()
        setupKeyboardShortcutHandlers()
        observeSettings()
        observeLifecycleEvents()
        applyGlobalDoubleTapInterval()
        refreshCustomShortcutRegistration()
        refreshEventMonitors()
        startShortcutCaptureHealthChecks()
    }

    private func migrateLegacyToggleRecordingShortcutIfNeeded() {
        guard KeyboardShortcuts.getShortcut(for: .dictationToggle) == nil,
              let legacyShortcut = KeyboardShortcuts.getShortcut(for: .toggleRecording)
        else {
            return
        }

        KeyboardShortcuts.setShortcut(legacyShortcut, for: .dictationToggle)

        AppLogger.info(
            "Migrated legacy toggleRecording shortcut to dictationToggle",
            category: .uiController,
            extra: ["legacyShortcut": legacyShortcut.description]
        )
    }

    deinit {
        Task { @MainActor [weak self] in
            self?.stopShortcutCaptureHealthChecks()
            self?.hotkeyBackend.unregisterAll()
            self?.runShortcutCaptureHealthCheck(
                source: "controller_deinit",
                expectation: ShortcutCaptureBackendExpectation.none
            )
        }
    }

    private func setupKeyboardShortcutHandlers() {
        KeyboardShortcuts.onKeyDown(for: .dictationToggle) { [weak self] in
            Task { @MainActor in
                await self?.handleCustomShortcutDown(for: .dictation)
            }
        }

        KeyboardShortcuts.onKeyUp(for: .dictationToggle) { [weak self] in
            Task { @MainActor in
                await self?.handleCustomShortcutUp(for: .dictation)
            }
        }

        KeyboardShortcuts.onKeyDown(for: .meetingToggle) { [weak self] in
            Task { @MainActor in
                await self?.handleCustomShortcutDown(for: .meeting)
            }
        }

        KeyboardShortcuts.onKeyUp(for: .meetingToggle) { [weak self] in
            Task { @MainActor in
                await self?.handleCustomShortcutUp(for: .meeting)
            }
        }
    }

    private func observeSettings() {
        settings.$dictationSelectedPresetKey
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.resetShortcutState()
                self?.refreshCustomShortcutRegistration()
                self?.refreshEventMonitors()
            }
            .store(in: &cancellables)

        settings.$meetingSelectedPresetKey
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.resetShortcutState()
                self?.refreshCustomShortcutRegistration()
                self?.refreshEventMonitors()
            }
            .store(in: &cancellables)

        settings.$dictationShortcutDefinition
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.resetShortcutState()
                self?.refreshCustomShortcutRegistration()
                self?.refreshEventMonitors()
            }
            .store(in: &cancellables)

        settings.$meetingShortcutDefinition
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.resetShortcutState()
                self?.refreshCustomShortcutRegistration()
                self?.refreshEventMonitors()
            }
            .store(in: &cancellables)

        settings.$dictationModifierShortcutGesture
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.resetShortcutState()
                self?.refreshCustomShortcutRegistration()
                self?.refreshEventMonitors()
            }
            .store(in: &cancellables)

        settings.$meetingModifierShortcutGesture
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.resetShortcutState()
                self?.refreshCustomShortcutRegistration()
                self?.refreshEventMonitors()
            }
            .store(in: &cancellables)

        settings.$shortcutActivationMode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.resetShortcutState()
            }
            .store(in: &cancellables)

        settings.$dictationShortcutActivationMode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.resetShortcutState()
            }
            .store(in: &cancellables)

        settings.$shortcutDoubleTapIntervalMilliseconds
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.applyGlobalDoubleTapInterval()
                self?.resetShortcutState()
            }
            .store(in: &cancellables)
    }

    private func observeLifecycleEvents() {
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.runShortcutCaptureHealthCheck(source: "app_became_active")
            }
            .store(in: &cancellables)
    }

    private func refreshEventMonitors() {
        refreshDirectHotkeys()
        runShortcutCaptureHealthCheck(source: "refresh_event_monitors", expectation: expectedShortcutCaptureBackends())

        AppLogger.debug(
            "Global shortcut hotkey refresh",
            category: .uiController,
            extra: [
                "inHouseHotkeys": hotkeyBackend.registeredHotkeyCount,
                "customDictationEnabled": isCustomShortcutEnabled(for: .dictation),
                "customMeetingEnabled": isCustomShortcutEnabled(for: .meeting),
            ]
        )
    }

    private func refreshCustomShortcutRegistration() {
        if settings.dictationShortcutDefinition == nil,
           settings.dictationModifierShortcutGesture == nil,
           settings.dictationSelectedPresetKey == .custom
        {
            KeyboardShortcuts.enable(.dictationToggle)
        } else {
            KeyboardShortcuts.disable(.dictationToggle)
        }

        if settings.meetingShortcutDefinition == nil,
           settings.meetingModifierShortcutGesture == nil,
           settings.meetingSelectedPresetKey == .custom
        {
            KeyboardShortcuts.enable(.meetingToggle)
        } else {
            KeyboardShortcuts.disable(.meetingToggle)
        }
    }

    private func refreshDirectHotkeys() {
        var registrations: [HotkeyRegistration] = []

        if let dictationRegistration = inHouseRegistration(for: .dictation) {
            registrations.append(dictationRegistration)
        }

        if let meetingRegistration = inHouseRegistration(for: .meeting) {
            registrations.append(meetingRegistration)
        }

        hotkeyBackend.registerAll(registrations)
    }

    private func inHouseRegistration(for type: ShortcutType) -> HotkeyRegistration? {
        let definition: ShortcutDefinition? = switch type {
        case .dictation:
            settings.dictationShortcutDefinition
        case .meeting:
            settings.meetingShortcutDefinition
        }

        guard let definition,
              let descriptor = GlobalHotkeyMapper.descriptor(for: definition)
        else {
            return nil
        }

        let activationMode = definition.trigger.asShortcutActivationMode
        let target = shortcutTarget(for: type)
        return HotkeyRegistration(
            id: "global.\(target)",
            keyCode: descriptor.keyCode,
            modifiers: descriptor.modifiers,
            onKeyDown: { [weak self] in
                guard let self else { return }
                emitShortcutDetected(
                    for: type,
                    source: "in_house_hotkey",
                    trigger: activationMode
                )
                Task { @MainActor [weak self] in
                    await self?.handleShortcutDown(for: type, activationModeOverride: activationMode)
                }
            },
            onKeyUp: { [weak self] in
                guard let self else { return }
                Task { @MainActor [weak self] in
                    await self?.handleShortcutUp(for: type, activationModeOverride: activationMode)
                }
            }
        )
    }

    func expectedShortcutCaptureBackends() -> ShortcutCaptureBackendExpectation {
        let hasAnyGlobalShortcut = hotkeyBackend.registeredHotkeyCount > 0
            || isCustomShortcutEnabled(for: .dictation)
            || isCustomShortcutEnabled(for: .meeting)

        return ShortcutCaptureBackendExpectation(
            needsGlobalCapture: hasAnyGlobalShortcut,
            needsFlagsMonitor: false,
            needsKeyDownMonitor: false,
            needsKeyUpMonitor: false,
            needsEventTap: false
        )
    }

    private func isCustomShortcutEnabled(for type: ShortcutType) -> Bool {
        switch type {
        case .dictation:
            settings.dictationShortcutDefinition == nil
                && settings.dictationModifierShortcutGesture == nil
                && settings.dictationSelectedPresetKey == .custom
        case .meeting:
            settings.meetingShortcutDefinition == nil
                && settings.meetingModifierShortcutGesture == nil
                && settings.meetingSelectedPresetKey == .custom
        }
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
            pipeline: "global_shortcuts",
            scope: "global",
            source: source,
            expectation: expectedBackends,
            accessibilityTrusted: true,
            flagsMonitorActive: false,
            keyDownMonitorActive: false,
            keyUpMonitorActive: false,
            eventTapActive: false
        )

        shortcutCaptureHealthSnapshot = snapshot
        ShortcutCaptureHealthStore.updateHealth(
            scope: .global,
            result: snapshot.result.rawValue,
            reasonToken: snapshot.result == .degraded ? snapshot.reasonToken : "",
            requiresGlobalCapture: snapshot.requiresGlobalCapture,
            accessibilityTrusted: snapshot.accessibilityTrusted,
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
            category: .uiController
        )
    }

    func handleCustomShortcutDown(for type: ShortcutType) async {
        let outcomes = shortcutRouter.routeCustomShortcutDown(
            configuration: routingConfiguration(for: type)
        )
        applyRoutingOutcomes(outcomes, for: type)
    }

    func handleCustomShortcutUp(for type: ShortcutType) async {
        let outcomes = shortcutRouter.routeCustomShortcutUp(
            configuration: routingConfiguration(for: type)
        )
        applyRoutingOutcomes(outcomes, for: type)
    }

    func handleShortcutDown(
        for type: ShortcutType,
        activationModeOverride: ShortcutActivationMode? = nil
    ) async {
        let handler = type == .dictation ? dictationHandler : meetingHandler
        handler.handleShortcutDown(activationMode: activationModeOverride ?? activationMode(for: type))
    }

    func handleShortcutUp(
        for type: ShortcutType,
        activationModeOverride: ShortcutActivationMode? = nil
    ) async {
        let handler = type == .dictation ? dictationHandler : meetingHandler
        handler.handleShortcutUp(activationMode: activationModeOverride ?? activationMode(for: type))
    }

    func performAction(_ action: SmartShortcutHandler.Action, for type: ShortcutType) async {
        switch action {
        case .startRecording:
            let source: RecordingSource = type == .dictation ? .microphone : .all
            let triggerLabel = type == .dictation ? "shortcut.dictation" : "shortcut.meeting"
            await recordingManager.startRecording(
                source: source,
                requestedAt: Date(),
                triggerLabel: triggerLabel
            )
        case .stopRecording:
            await recordingManager.stopRecording()
        }
    }

    func resetShortcutState() {
        dictationHandler.reset()
        meetingHandler.reset()
    }

    var currentDoubleTapInterval: TimeInterval {
        settings.shortcutDoubleTapIntervalMilliseconds / 1_000
    }

    func applyGlobalDoubleTapInterval() {
        let interval = currentDoubleTapInterval
        dictationHandler.setDoubleTapInterval(interval)
        meetingHandler.setDoubleTapInterval(interval)
    }

    func activationMode(for type: ShortcutType) -> ShortcutActivationMode {
        switch type {
        case .dictation:
            settings.dictationShortcutActivationMode
        case .meeting:
            settings.shortcutActivationMode
        }
    }

    func routingConfiguration(for type: ShortcutType) -> ShortcutEventRoutingConfiguration {
        let definition: ShortcutDefinition?
        let modifierGesture: ModifierShortcutGesture?
        let presetKey: PresetShortcutKey

        switch type {
        case .dictation:
            definition = settings.dictationShortcutDefinition
            modifierGesture = settings.dictationModifierShortcutGesture
            presetKey = settings.dictationSelectedPresetKey
        case .meeting:
            definition = settings.meetingShortcutDefinition
            modifierGesture = settings.meetingModifierShortcutGesture
            presetKey = settings.meetingSelectedPresetKey
        }

        return ShortcutEventRoutingConfiguration(
            definition: definition,
            modifierGesture: modifierGesture,
            presetKey: presetKey,
            presetRequiresModifierMonitoring: presetKey.requiresModifierMonitoring,
            defaultActivationMode: activationMode(for: type),
            sources: ShortcutEventRoutingSources(
                inHouseDefinition: "in_house_definition",
                modifierGesture: "modifier_gesture",
                preset: "preset",
                customKeyboardShortcut: "keyboardshortcuts_custom"
            )
        )
    }

    func applyRoutingOutcomes(
        _ outcomes: [ShortcutEventRoutingOutcome],
        for type: ShortcutType
    ) {
        for outcome in outcomes {
            switch outcome {
            case let .detected(source, trigger):
                emitShortcutDetected(for: type, source: source, trigger: trigger)
            case let .rejected(source, trigger, reason):
                emitShortcutRejected(for: type, source: source, trigger: trigger, reason: reason)
            case let .dispatchDown(activationMode):
                Task { @MainActor [weak self] in
                    await self?.handleShortcutDown(
                        for: type,
                        activationModeOverride: activationMode
                    )
                }
            case let .dispatchUp(activationMode):
                Task { @MainActor [weak self] in
                    await self?.handleShortcutUp(
                        for: type,
                        activationModeOverride: activationMode
                    )
                }
            }
        }
    }

    func emitShortcutDetected(
        for type: ShortcutType,
        source: String,
        trigger: ShortcutActivationMode
    ) {
        ShortcutTelemetry.emit(
            .shortcutDetected(
                pipeline: "global_shortcuts",
                scope: "global",
                shortcutTarget: shortcutTarget(for: type),
                source: source,
                trigger: trigger.rawValue
            ),
            category: .uiController
        )
    }

    func emitShortcutRejected(
        for type: ShortcutType,
        source: String,
        trigger: ShortcutActivationMode,
        reason: String
    ) {
        ShortcutTelemetry.emit(
            .shortcutRejected(
                pipeline: "global_shortcuts",
                scope: "global",
                shortcutTarget: shortcutTarget(for: type),
                source: source,
                trigger: trigger.rawValue,
                reason: reason
            ),
            category: .uiController
        )
    }

    func shortcutTarget(for type: ShortcutType) -> String {
        switch type {
        case .dictation:
            "dictation"
        case .meeting:
            "meeting"
        }
    }
}

enum ShortcutType {
    case dictation
    case meeting
}
