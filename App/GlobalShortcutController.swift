import AppKit
import Combine
import KeyboardShortcuts
import MeetingAssistantCore

@MainActor
final class GlobalShortcutController {
    private let recordingManager: RecordingManager
    private let settings: AppSettingsStore
    private var cancellables = Set<AnyCancellable>()
    private let inputBackend: ShortcutInputBackend
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

    private let presetState = ShortcutActivationState()
    private let escapeDoublePressInterval: TimeInterval = 1.0
    private var lastEscapePressTime: Date?
    private var hasRequestedAccessibilityPermissionForGlobalCapture = false
    private var hasRequestedInputMonitoringPermissionForGlobalCapture = false
    private var hasOpenedAccessibilitySettingsForGlobalCapture = false
    private var hasOpenedInputMonitoringSettingsForGlobalCapture = false
    private let healthCheckIntervalSeconds: TimeInterval = 15
    private var healthCheckTimer: Timer?
    private(set) var shortcutCaptureHealthSnapshot: ShortcutCaptureHealthSnapshot?

    init(
        recordingManager: RecordingManager,
        settings: AppSettingsStore,
        inputBackend: ShortcutInputBackend? = nil
    ) {
        self.recordingManager = recordingManager
        self.settings = settings
        self.inputBackend = inputBackend ?? Self.makeDefaultInputBackend()
        configureInputBackendHandlers()
    }

    private static func makeDefaultInputBackend() -> ShortcutInputBackend {
        SystemShortcutInputBackend()
    }

    convenience init(recordingManager: RecordingManager) {
        self.init(recordingManager: recordingManager, settings: .shared, inputBackend: nil)
    }

    func start() {
        setupKeyboardShortcutHandlers()
        observeSettings()
        observeLifecycleEvents()
        applyGlobalDoubleTapInterval()
        refreshCustomShortcutRegistration()
        refreshEventMonitors()
        startShortcutCaptureHealthChecks()
    }

    deinit {
        Task { @MainActor [weak self] in
            self?.stopShortcutCaptureHealthChecks()
            self?.removeEventMonitors()
        }
    }

    private func setupKeyboardShortcutHandlers() {
        // Dictation
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

        // Meeting
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

        settings.$dictationModifierShortcutGesture
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

        settings.$meetingModifierShortcutGesture
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

        settings.$useEscapeToCancelRecording
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshEventMonitors()
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
        let expectation = expectedShortcutCaptureBackends()
        let needsModifierMonitoring = expectation.needsFlagsMonitor
        let needsShortcutKeyMonitoring = expectation.needsKeyUpMonitor
        let needsEscapeMonitoring = settings.useEscapeToCancelRecording

        if needsModifierMonitoring {
            installFlagsChangedMonitors()
        } else {
            removeFlagsChangedMonitors()
        }

        if needsEscapeMonitoring || needsShortcutKeyMonitoring {
            installKeyDownMonitors()
        } else {
            removeKeyDownMonitors()
        }

        if needsShortcutKeyMonitoring {
            installKeyUpMonitors()
        } else {
            removeKeyUpMonitors()
        }

        let needsGlobalCapture = expectation.needsGlobalCapture
        ensureGlobalCapturePermissionsIfNeeded(needsGlobalCapture: needsGlobalCapture)
        runShortcutCaptureHealthCheck(source: "refresh_event_monitors", expectation: expectation)

        AppLogger.debug(
            "Global shortcut monitor refresh",
            category: .uiController,
            extra: [
                "needsModifierMonitoring": needsModifierMonitoring,
                "needsShortcutKeyMonitoring": needsShortcutKeyMonitoring,
                "needsEscapeMonitoring": needsEscapeMonitoring,
                "useEscapeToCancelRecording": settings.useEscapeToCancelRecording,
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

    private func installFlagsChangedMonitors() {
        inputBackend.startFlagsChangedMonitoring()
    }

    private func removeFlagsChangedMonitors() {
        inputBackend.stopFlagsChangedMonitoring()
    }

    private func installKeyDownMonitors() {
        inputBackend.startKeyDownMonitoring(shouldReturnLocalEvent: nil)
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

    private func removeEventMonitors() {
        removeFlagsChangedMonitors()
        removeKeyDownMonitors()
        removeKeyUpMonitors()
        runShortcutCaptureHealthCheck(
            source: "event_monitors_removed",
            expectation: ShortcutCaptureBackendExpectation.none
        )
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
            "Global shortcut capture missing required permissions",
            category: .uiController,
            extra: [
                "scope": "global",
                "needsGlobalCapture": needsGlobalCapture,
                "accessibilityTrusted": accessibilityTrusted,
                "inputMonitoringTrusted": inputMonitoringTrusted,
            ]
        )
    }

    // To match the original logic:

    private func handleFlagsChanged(_ event: ShortcutInputEvent) {
        routeShortcutMonitorEvent(
            for: .dictation,
            event: event,
            mode: .allSources,
            handler: dictationHandler
        )
        routeShortcutMonitorEvent(
            for: .meeting,
            event: event,
            mode: .allSources,
            handler: meetingHandler
        )
    }

    private func handleKeyDown(_ event: ShortcutInputEvent) {
        if event.keyCode == PresetShortcutKey.escapeKeyCode {
            AppLogger.debug(
                "ESC keyDown observed (global)",
                category: .uiController,
                extra: [
                    "scope": "global",
                    "isRepeat": event.isRepeat,
                    "useEscapeToCancelRecording": settings.useEscapeToCancelRecording,
                    "isRecording": recordingManager.isRecording,
                    "isStarting": recordingManager.isStartingRecording,
                ]
            )
        }

        routeShortcutMonitorEvent(
            for: .dictation,
            event: event,
            mode: .inHouseDefinitionOnly,
            handler: dictationHandler
        )
        routeShortcutMonitorEvent(
            for: .meeting,
            event: event,
            mode: .inHouseDefinitionOnly,
            handler: meetingHandler
        )

        guard settings.useEscapeToCancelRecording else {
            if event.keyCode == PresetShortcutKey.escapeKeyCode {
                AppLogger.debug(
                    "ESC ignored because global escape cancel is disabled",
                    category: .uiController,
                    extra: ["scope": "global"]
                )
            }
            return
        }
        guard !event.isRepeat else {
            if event.keyCode == PresetShortcutKey.escapeKeyCode {
                AppLogger.debug(
                    "ESC ignored because key event is repeat (global)",
                    category: .uiController,
                    extra: ["scope": "global"]
                )
            }
            return
        }
        guard event.keyCode == PresetShortcutKey.escapeKeyCode else {
            return
        }

        guard didConfirmDoubleEscapePress() else {
            AppLogger.debug(
                "ESC waiting for second press (global)",
                category: .uiController,
                extra: ["scope": "global"]
            )
            return
        }

        Task { @MainActor in
            let wasRecording = self.recordingManager.isRecording
            let wasStarting = self.recordingManager.isStartingRecording

            guard wasRecording || wasStarting else {
                AppLogger.debug(
                    "ESC cancel ignored",
                    category: .uiController,
                    extra: [
                        "scope": "global",
                        "reason": "not_recording",
                    ]
                )
                return
            }

            AppLogger.info(
                "ESC cancel requested",
                category: .uiController,
                extra: [
                    "scope": "global",
                    "wasRecording": wasRecording,
                    "wasStarting": wasStarting,
                ]
            )

            await self.recordingManager.cancelRecording()

            AppLogger.info(
                "ESC cancel completed",
                category: .uiController,
                extra: [
                    "scope": "global",
                    "isRecording": self.recordingManager.isRecording,
                    "isStarting": self.recordingManager.isStartingRecording,
                ]
            )
        }
    }

    private func didConfirmDoubleEscapePress() -> Bool {
        let now = Date()
        guard let lastEscapePressTime else {
            self.lastEscapePressTime = now
            AppLogger.debug(
                "ESC first press detected",
                category: .uiController,
                extra: [
                    "scope": "global",
                    "windowSec": escapeDoublePressInterval,
                ]
            )
            return false
        }

        let elapsed = now.timeIntervalSince(lastEscapePressTime)
        guard elapsed <= escapeDoublePressInterval else {
            self.lastEscapePressTime = now
            AppLogger.debug(
                "ESC double-press timeout",
                category: .uiController,
                extra: [
                    "scope": "global",
                    "elapsedSec": elapsed,
                    "windowSec": escapeDoublePressInterval,
                ]
            )
            return false
        }

        self.lastEscapePressTime = nil
        AppLogger.info(
            "ESC double-press confirmed",
            category: .uiController,
            extra: [
                "scope": "global",
                "elapsedSec": elapsed,
            ]
        )
        return true
    }

    private func handleKeyUp(_ event: ShortcutInputEvent) {
        routeShortcutMonitorEvent(
            for: .dictation,
            event: event,
            mode: .inHouseDefinitionOnly,
            handler: dictationHandler
        )
        routeShortcutMonitorEvent(
            for: .meeting,
            event: event,
            mode: .inHouseDefinitionOnly,
            handler: meetingHandler
        )
    }
}

private extension GlobalShortcutController {
    func expectedShortcutCaptureBackends() -> ShortcutCaptureBackendExpectation {
        let hasInHouseShortcutDefinitions = settings.dictationShortcutDefinition != nil ||
            settings.meetingShortcutDefinition != nil
        let needsModifierMonitoring = hasInHouseShortcutDefinitions ||
            settings.dictationModifierShortcutGesture != nil ||
            settings.meetingModifierShortcutGesture != nil ||
            settings.dictationSelectedPresetKey.requiresModifierMonitoring ||
            settings.meetingSelectedPresetKey.requiresModifierMonitoring
        let needsShortcutKeyMonitoring = hasInHouseShortcutDefinitions
        let needsEscapeMonitoring = settings.useEscapeToCancelRecording

        return ShortcutCaptureBackendExpectation(
            needsGlobalCapture: needsModifierMonitoring || needsShortcutKeyMonitoring || needsEscapeMonitoring,
            needsFlagsMonitor: needsModifierMonitoring,
            needsKeyDownMonitor: needsEscapeMonitoring || needsShortcutKeyMonitoring,
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
            pipeline: "global_shortcuts",
            scope: "global",
            source: source,
            expectation: expectedBackends,
            accessibilityTrusted: AccessibilityPermissionService.isTrusted(),
            inputMonitoringTrusted: InputMonitoringPermissionService.isTrusted(),
            flagsMonitorActive: inputBackend.isFlagsChangedMonitoringActive,
            keyDownMonitorActive: inputBackend.isKeyDownMonitoringActive,
            keyUpMonitorActive: inputBackend.isKeyUpMonitoringActive,
            eventTapActive: false
        )

        shortcutCaptureHealthSnapshot = snapshot
        ShortcutCaptureHealthStore.updateHealth(
            scope: .global,
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
            category: .uiController
        )

        let message = current.result == .degraded
            ? "Global shortcut capture health degraded"
            : "Global shortcut capture health updated"
        let log: (_ message: String, _ category: LogCategory, _ extra: [String: Any]) -> Void = current.result == .degraded
            ? AppLogger.warning
            : AppLogger.info
        log(
            message,
            .uiController,
            [
                "scope": current.scope,
                "source": current.source,
                "result": current.result.rawValue,
                "previousResult": previous?.result.rawValue ?? "unknown",
                "reason": current.result == .degraded ? current.reasonToken : "none",
                "requiresGlobalCapture": current.requiresGlobalCapture,
            ]
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
        lastEscapePressTime = nil
        presetState.reset()
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

    func isPresetActive(_ preset: PresetShortcutKey, event: NSEvent) -> Bool {
        presetState.isPresetActive(preset, event: event)
    }

    func isPresetActive(_ preset: PresetShortcutKey, inputEvent: ShortcutInputEvent) -> Bool {
        presetState.isPresetActive(preset, inputEvent: inputEvent)
    }

    func isModifierGestureActive(_ gesture: ModifierShortcutGesture, event: NSEvent) -> Bool {
        presetState.isModifierGestureActive(gesture, event: event)
    }

    func isModifierGestureActive(_ gesture: ModifierShortcutGesture, inputEvent: ShortcutInputEvent) -> Bool {
        presetState.isModifierGestureActive(gesture, inputEvent: inputEvent)
    }

    func isShortcutActive(_ definition: ShortcutDefinition, event: NSEvent) -> Bool {
        presetState.isShortcutActive(definition, event: event)
    }

    func isShortcutActive(_ definition: ShortcutDefinition, inputEvent: ShortcutInputEvent) -> Bool {
        presetState.isShortcutActive(definition, inputEvent: inputEvent)
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

    func routeShortcutMonitorEvent(
        for type: ShortcutType,
        event: ShortcutInputEvent,
        mode: ShortcutEventRoutingMode,
        handler: SmartShortcutHandler
    ) {
        let result = shortcutRouter.routeMonitorEvent(
            configuration: routingConfiguration(for: type),
            mode: mode,
            wasPressed: handler.isPressed,
            isDefinitionActive: { [weak self] definition in
                guard let self else { return false }
                return self.isShortcutActive(definition, inputEvent: event)
            },
            isModifierGestureActive: { [weak self] gesture in
                guard let self else { return false }
                return self.isModifierGestureActive(gesture, inputEvent: event)
            },
            isPresetActive: { [weak self] presetKey in
                guard let self else { return false }
                return self.isPresetActive(presetKey, inputEvent: event)
            }
        )

        if let nextPressedState = result.nextPressedState {
            handler.handleModifierChange(isActive: nextPressedState)
        }

        applyRoutingOutcomes(result.outcomes, for: type)
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

    func emitPermissionBlocked(
        permission: String,
        accessibilityTrusted: Bool,
        inputMonitoringTrusted: Bool
    ) {
        ShortcutTelemetry.emit(
            .permissionBlocked(
                pipeline: "global_shortcuts",
                scope: "global",
                permission: permission,
                accessibilityTrusted: accessibilityTrusted,
                inputMonitoringTrusted: inputMonitoringTrusted
            ),
            category: .uiController
        )
    }

    func shortcutTarget(for type: ShortcutType) -> String {
        switch type {
        case .dictation:
            return "dictation"
        case .meeting:
            return "meeting"
        }
    }
}

private enum ShortcutType {
    case dictation
    case meeting
}
