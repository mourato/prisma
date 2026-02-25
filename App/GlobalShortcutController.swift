import AppKit
import Combine
import KeyboardShortcuts
import MeetingAssistantCore

@MainActor
final class GlobalShortcutController {
    private let recordingManager: RecordingManager
    private let settings: AppSettingsStore
    private var cancellables = Set<AnyCancellable>()
    private var flagsMonitor: KeyboardEventMonitor?
    private var keyDownMonitor: KeyboardEventMonitor?
    private var keyUpMonitor: KeyboardEventMonitor?

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
        settings: AppSettingsStore
    ) {
        self.recordingManager = recordingManager
        self.settings = settings
    }

    convenience init(recordingManager: RecordingManager) {
        self.init(recordingManager: recordingManager, settings: .shared)
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
        if flagsMonitor == nil {
            flagsMonitor = KeyboardEventMonitor(mask: .flagsChanged) { [weak self] event in
                Task { @MainActor [weak self] in
                    self?.handleFlagsChanged(event)
                }
            }
            flagsMonitor?.start()
        }
    }

    private func removeFlagsChangedMonitors() {
        flagsMonitor?.stop()
        flagsMonitor = nil
    }

    private func installKeyDownMonitors() {
        if keyDownMonitor == nil {
            keyDownMonitor = KeyboardEventMonitor(mask: .keyDown) { [weak self] event in
                Task { @MainActor [weak self] in
                    self?.handleKeyDown(event)
                }
            }
            keyDownMonitor?.start()
        }
    }

    private func installKeyUpMonitors() {
        if keyUpMonitor == nil {
            keyUpMonitor = KeyboardEventMonitor(mask: .keyUp) { [weak self] event in
                Task { @MainActor [weak self] in
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

    private func handleFlagsChanged(_ event: NSEvent) {
        // Dictation
        if let definition = settings.dictationShortcutDefinition {
            handleInHouseShortcutEvent(
                definition: definition,
                event: event,
                handler: dictationHandler,
                type: .dictation
            )
        } else if let gesture = settings.dictationModifierShortcutGesture {
            let isActive = isModifierGestureActive(gesture, event: event)
            let wasPressed = dictationHandler.isPressed
            dictationHandler.handleModifierChange(isActive: isActive)
            let activationMode = gesture.triggerMode.asShortcutActivationMode

            if isActive, !wasPressed {
                emitShortcutDetected(
                    for: .dictation,
                    source: "modifier_gesture",
                    trigger: activationMode
                )
                Task { @MainActor in await handleShortcutDown(for: .dictation, activationModeOverride: activationMode) }
            } else if !isActive, wasPressed {
                Task { @MainActor in await handleShortcutUp(for: .dictation, activationModeOverride: activationMode) }
            }
        } else if settings.dictationSelectedPresetKey.requiresModifierMonitoring {
            let isActive = isPresetActive(settings.dictationSelectedPresetKey, event: event)
            let wasPressed = dictationHandler.isPressed
            dictationHandler.handleModifierChange(isActive: isActive)

            if isActive, !wasPressed {
                emitShortcutDetected(
                    for: .dictation,
                    source: "preset",
                    trigger: activationMode(for: .dictation)
                )
                Task { @MainActor in await handleShortcutDown(for: .dictation) }
            } else if !isActive, wasPressed {
                Task { @MainActor in await handleShortcutUp(for: .dictation) }
            }
        }

        // Meeting
        if let definition = settings.meetingShortcutDefinition {
            handleInHouseShortcutEvent(
                definition: definition,
                event: event,
                handler: meetingHandler,
                type: .meeting
            )
        } else if let gesture = settings.meetingModifierShortcutGesture {
            let isActive = isModifierGestureActive(gesture, event: event)
            let wasPressed = meetingHandler.isPressed
            meetingHandler.handleModifierChange(isActive: isActive)
            let activationMode = gesture.triggerMode.asShortcutActivationMode

            if isActive, !wasPressed {
                emitShortcutDetected(
                    for: .meeting,
                    source: "modifier_gesture",
                    trigger: activationMode
                )
                Task { @MainActor in await handleShortcutDown(for: .meeting, activationModeOverride: activationMode) }
            } else if !isActive, wasPressed {
                Task { @MainActor in await handleShortcutUp(for: .meeting, activationModeOverride: activationMode) }
            }
        } else if settings.meetingSelectedPresetKey.requiresModifierMonitoring {
            let isActive = isPresetActive(settings.meetingSelectedPresetKey, event: event)
            let wasPressed = meetingHandler.isPressed
            meetingHandler.handleModifierChange(isActive: isActive)

            if isActive, !wasPressed {
                emitShortcutDetected(
                    for: .meeting,
                    source: "preset",
                    trigger: activationMode(for: .meeting)
                )
                Task { @MainActor in await handleShortcutDown(for: .meeting) }
            } else if !isActive, wasPressed {
                Task { @MainActor in await handleShortcutUp(for: .meeting) }
            }
        }
    }

    private func handleKeyDown(_ event: NSEvent) {
        if event.keyCode == PresetShortcutKey.escapeKeyCode {
            AppLogger.debug(
                "ESC keyDown observed (global)",
                category: .uiController,
                extra: [
                    "scope": "global",
                    "isRepeat": event.isARepeat,
                    "useEscapeToCancelRecording": settings.useEscapeToCancelRecording,
                    "isRecording": recordingManager.isRecording,
                    "isStarting": recordingManager.isStartingRecording,
                ]
            )
        }

        if let definition = settings.dictationShortcutDefinition {
            handleInHouseShortcutEvent(
                definition: definition,
                event: event,
                handler: dictationHandler,
                type: .dictation
            )
        }

        if let definition = settings.meetingShortcutDefinition {
            handleInHouseShortcutEvent(
                definition: definition,
                event: event,
                handler: meetingHandler,
                type: .meeting
            )
        }

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
        guard !event.isARepeat else {
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

    private func handleKeyUp(_ event: NSEvent) {
        if let definition = settings.dictationShortcutDefinition {
            handleInHouseShortcutEvent(
                definition: definition,
                event: event,
                handler: dictationHandler,
                type: .dictation
            )
        }

        if let definition = settings.meetingShortcutDefinition {
            handleInHouseShortcutEvent(
                definition: definition,
                event: event,
                handler: meetingHandler,
                type: .meeting
            )
        }
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
            flagsMonitorActive: flagsMonitor != nil,
            keyDownMonitorActive: keyDownMonitor != nil,
            keyUpMonitorActive: keyUpMonitor != nil,
            eventTapActive: false
        )

        shortcutCaptureHealthSnapshot = snapshot
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
        let presetKey = type == .dictation ? settings.dictationSelectedPresetKey : settings.meetingSelectedPresetKey
        let inHouseDefinition = type == .dictation ? settings.dictationShortcutDefinition : settings.meetingShortcutDefinition
        if inHouseDefinition != nil {
            emitShortcutRejected(
                for: type,
                source: "keyboardshortcuts_custom",
                trigger: activationMode(for: type),
                reason: "custom_overridden_by_in_house_definition"
            )
            return
        }
        if type == .dictation, settings.dictationModifierShortcutGesture != nil {
            emitShortcutRejected(
                for: type,
                source: "keyboardshortcuts_custom",
                trigger: activationMode(for: type),
                reason: "custom_overridden_by_modifier_gesture"
            )
            return
        }
        if type == .meeting, settings.meetingModifierShortcutGesture != nil {
            emitShortcutRejected(
                for: type,
                source: "keyboardshortcuts_custom",
                trigger: activationMode(for: type),
                reason: "custom_overridden_by_modifier_gesture"
            )
            return
        }
        guard presetKey == .custom else {
            emitShortcutRejected(
                for: type,
                source: "keyboardshortcuts_custom",
                trigger: activationMode(for: type),
                reason: "preset_not_custom"
            )
            return
        }

        emitShortcutDetected(
            for: type,
            source: "keyboardshortcuts_custom",
            trigger: activationMode(for: type)
        )
        await handleShortcutDown(for: type)
    }

    func handleCustomShortcutUp(for type: ShortcutType) async {
        let presetKey = type == .dictation ? settings.dictationSelectedPresetKey : settings.meetingSelectedPresetKey
        let inHouseDefinition = type == .dictation ? settings.dictationShortcutDefinition : settings.meetingShortcutDefinition
        if inHouseDefinition != nil {
            emitShortcutRejected(
                for: type,
                source: "keyboardshortcuts_custom",
                trigger: activationMode(for: type),
                reason: "custom_overridden_by_in_house_definition"
            )
            return
        }
        if type == .dictation, settings.dictationModifierShortcutGesture != nil {
            emitShortcutRejected(
                for: type,
                source: "keyboardshortcuts_custom",
                trigger: activationMode(for: type),
                reason: "custom_overridden_by_modifier_gesture"
            )
            return
        }
        if type == .meeting, settings.meetingModifierShortcutGesture != nil {
            emitShortcutRejected(
                for: type,
                source: "keyboardshortcuts_custom",
                trigger: activationMode(for: type),
                reason: "custom_overridden_by_modifier_gesture"
            )
            return
        }
        guard presetKey == .custom else {
            emitShortcutRejected(
                for: type,
                source: "keyboardshortcuts_custom",
                trigger: activationMode(for: type),
                reason: "preset_not_custom"
            )
            return
        }
        await handleShortcutUp(for: type)
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

    func isModifierGestureActive(_ gesture: ModifierShortcutGesture, event: NSEvent) -> Bool {
        presetState.isModifierGestureActive(gesture, event: event)
    }

    func isShortcutActive(_ definition: ShortcutDefinition, event: NSEvent) -> Bool {
        presetState.isShortcutActive(definition, event: event)
    }

    func handleInHouseShortcutEvent(
        definition: ShortcutDefinition,
        event: NSEvent,
        handler: SmartShortcutHandler,
        type: ShortcutType
    ) {
        let isActive = isShortcutActive(definition, event: event)
        let wasPressed = handler.isPressed
        handler.handleModifierChange(isActive: isActive)
        let activationMode = definition.trigger.asShortcutActivationMode

        if isActive, !wasPressed {
            emitShortcutDetected(
                for: type,
                source: "in_house_definition",
                trigger: activationMode
            )
            Task { @MainActor in
                await handleShortcutDown(for: type, activationModeOverride: activationMode)
            }
        } else if !isActive, wasPressed {
            Task { @MainActor in
                await handleShortcutUp(for: type, activationModeOverride: activationMode)
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
