import AppKit
import Combine
import KeyboardShortcuts
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

    init(
        assistantService: AssistantVoiceCommandService,
        settings: AppSettingsStore = .shared
    ) {
        self.assistantService = assistantService
        self.settings = settings
    }

    func start() {
        setupKeyboardShortcutHandlers()
        observeSettings()
        applyGlobalDoubleTapInterval()
        refreshCustomShortcutRegistration()
        refreshIntegrationCustomShortcutRegistrations()
        refreshEventMonitors()
    }

    deinit {
        Task { @MainActor [weak self] in
            self?.removeEventMonitors()
        }
    }

    private func setupKeyboardShortcutHandlers() {
        KeyboardShortcuts.onKeyDown(for: .assistantCommand) { [weak self] in
            Task { @MainActor [weak self] in
                await self?.handleCustomShortcutDown()
            }
        }

        KeyboardShortcuts.onKeyUp(for: .assistantCommand) { [weak self] in
            Task { @MainActor [weak self] in
                await self?.handleCustomShortcutUp()
            }
        }
    }

    private func observeSettings() {
        settings.$assistantSelectedPresetKey
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.resetShortcutState()
                self?.refreshCustomShortcutRegistration()
                self?.refreshEventMonitors()
            }
            .store(in: &cancellables)

        settings.$assistantShortcutActivationMode
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

        settings.$assistantShortcutDefinition
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.resetShortcutState()
                self?.refreshCustomShortcutRegistration()
                self?.refreshEventMonitors()
            }
            .store(in: &cancellables)

        settings.$assistantModifierShortcutGesture
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.resetShortcutState()
                self?.refreshCustomShortcutRegistration()
                self?.refreshEventMonitors()
            }
            .store(in: &cancellables)

        settings.$assistantUseEscapeToCancelRecording
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshEventMonitors()
            }
            .store(in: &cancellables)

        settings.$assistantIntegrations
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.resetShortcutState()
                self?.refreshIntegrationCustomShortcutRegistrations()
                self?.refreshEventMonitors()
            }
            .store(in: &cancellables)
    }

    private func refreshEventMonitors() {
        if shouldUseAssistantShortcutLayer {
            installFlagsChangedMonitors()
            installKeyDownMonitors()
            removeKeyUpMonitors()
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
    }

    private func refreshCustomShortcutRegistration() {
        switch settings.assistantSelectedPresetKey {
        case .custom where settings.assistantModifierShortcutGesture == nil && settings.assistantShortcutDefinition == nil:
            KeyboardShortcuts.enable(.assistantCommand)
        default:
            KeyboardShortcuts.disable(.assistantCommand)
        }
    }

    private func refreshIntegrationCustomShortcutRegistrations() {
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

    private func removeFlagsChangedMonitors() {
        flagsMonitor?.stop()
        flagsMonitor = nil
    }

    private func installKeyDownMonitors() {
        if keyDownMonitor == nil {
            keyDownMonitor = KeyboardEventMonitor(
                mask: .keyDown,
                shouldReturnLocalEvent: { [weak self] _ in
                    guard let self else { return true }
                    return !(self.shouldUseAssistantShortcutLayer && self.isShortcutLayerArmed)
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

    private func removeEventMonitors() {
        removeFlagsChangedMonitors()
        removeKeyDownMonitors()
        removeKeyUpMonitors()
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        if let definition = settings.assistantShortcutDefinition {
            handleInHouseShortcutEvent(
                definition: definition,
                event: event,
                state: presetState,
                handler: shortcutHandler,
                onDown: { [weak self] activationMode in
                    Task { @MainActor [weak self] in await self?.handleShortcutDown(activationModeOverride: activationMode) }
                },
                onUp: { [weak self] activationMode in
                    Task { @MainActor [weak self] in await self?.handleShortcutUp(activationModeOverride: activationMode) }
                }
            )
        } else if let gesture = settings.assistantModifierShortcutGesture {
            let isActive = presetState.isModifierGestureActive(gesture, event: event)
            let wasPressed = shortcutHandler.isPressed
            shortcutHandler.handleModifierChange(isActive: isActive)
            let activationMode = gesture.triggerMode.asShortcutActivationMode

            if isActive, !wasPressed {
                Task { @MainActor [weak self] in await self?.handleShortcutDown(activationModeOverride: activationMode) }
            } else if !isActive, wasPressed {
                Task { @MainActor [weak self] in await self?.handleShortcutUp(activationModeOverride: activationMode) }
            }
        } else if settings.assistantSelectedPresetKey.requiresModifierMonitoring {
            let isActive = presetState.isPresetActive(settings.assistantSelectedPresetKey, event: event)
            let wasPressed = shortcutHandler.isPressed
            shortcutHandler.handleModifierChange(isActive: isActive)

            if isActive, !wasPressed {
                Task { @MainActor [weak self] in await self?.handleShortcutDown() }
            } else if !isActive, wasPressed {
                Task { @MainActor [weak self] in await self?.handleShortcutUp() }
            }
        }

        if !shouldUseAssistantShortcutLayer {
            handleIntegrationFlagsChanged(event)
        }
    }

    private func handleIntegrationFlagsChanged(_ event: NSEvent) {
        for integration in settings.assistantIntegrations where integration.isEnabled {
            let presetState = integrationState(for: integration.id)
            let shortcutHandler = integrationShortcutHandlers[integration.id] ?? makeIntegrationShortcutHandler(for: integration.id)
            integrationShortcutHandlers[integration.id] = shortcutHandler
            if let definition = integration.shortcutDefinition {
                handleInHouseShortcutEvent(
                    definition: definition,
                    event: event,
                    state: presetState,
                    handler: shortcutHandler,
                    onDown: { [weak self] activationMode in
                        Task { @MainActor [weak self] in
                            await self?.handleIntegrationShortcutDown(
                                integrationID: integration.id,
                                activationModeOverride: activationMode
                            )
                        }
                    },
                    onUp: { [weak self] activationMode in
                        Task { @MainActor [weak self] in
                            await self?.handleIntegrationShortcutUp(
                                integrationID: integration.id,
                                activationModeOverride: activationMode
                            )
                        }
                    }
                )
            } else if let gesture = integration.modifierShortcutGesture {
                let isActive = presetState.isModifierGestureActive(gesture, event: event)
                let wasPressed = shortcutHandler.isPressed
                shortcutHandler.handleModifierChange(isActive: isActive)
                let activationMode = gesture.triggerMode.asShortcutActivationMode

                if isActive, !wasPressed {
                    Task { @MainActor [weak self] in
                        await self?.handleIntegrationShortcutDown(
                            integrationID: integration.id,
                            activationModeOverride: activationMode
                        )
                    }
                } else if !isActive, wasPressed {
                    Task { @MainActor [weak self] in
                        await self?.handleIntegrationShortcutUp(
                            integrationID: integration.id,
                            activationModeOverride: activationMode
                        )
                    }
                }
            } else if integration.shortcutPresetKey.requiresModifierMonitoring {
                let isActive = presetState.isPresetActive(integration.shortcutPresetKey, event: event)
                let wasPressed = shortcutHandler.isPressed
                shortcutHandler.handleModifierChange(isActive: isActive)

                if isActive, !wasPressed {
                    Task { @MainActor [weak self] in
                        await self?.handleIntegrationShortcutDown(integrationID: integration.id)
                    }
                } else if !isActive, wasPressed {
                    Task { @MainActor [weak self] in
                        await self?.handleIntegrationShortcutUp(integrationID: integration.id)
                    }
                }
            }
        }
    }

    private func handleKeyDown(_ event: NSEvent) {
        if handleShortcutLayerKeyDown(event) {
            return
        }

        if let definition = settings.assistantShortcutDefinition {
            handleInHouseShortcutEvent(
                definition: definition,
                event: event,
                state: presetState,
                handler: shortcutHandler,
                onDown: { [weak self] activationMode in
                    Task { @MainActor [weak self] in await self?.handleShortcutDown(activationModeOverride: activationMode) }
                },
                onUp: { [weak self] activationMode in
                    Task { @MainActor [weak self] in await self?.handleShortcutUp(activationModeOverride: activationMode) }
                }
            )
        }
        handleIntegrationKeyEvent(event)

        guard settings.assistantUseEscapeToCancelRecording else {
            return
        }

        guard !event.isARepeat else {
            return
        }

        guard event.keyCode == PresetShortcutKey.escapeKeyCode else {
            return
        }

        guard didConfirmDoubleEscapePress() else {
            return
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            let wasRecording = assistantService.isRecording

            AppLogger.info(
                "ESC cancel requested",
                category: .assistant,
                extra: [
                    "scope": "assistant",
                    "wasRecording": wasRecording,
                ]
            )

            await assistantService.cancelRecording()

            AppLogger.info(
                "ESC cancel completed",
                category: .assistant,
                extra: [
                    "scope": "assistant",
                    "isRecording": assistantService.isRecording,
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
                category: .assistant,
                extra: [
                    "scope": "assistant",
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
                category: .assistant,
                extra: [
                    "scope": "assistant",
                    "elapsedSec": elapsed,
                    "windowSec": escapeDoublePressInterval,
                ]
            )
            return false
        }

        self.lastEscapePressTime = nil
        AppLogger.info(
            "ESC double-press confirmed",
            category: .assistant,
            extra: [
                "scope": "assistant",
                "elapsedSec": elapsed,
            ]
        )
        return true
    }

    private func handleKeyUp(_ event: NSEvent) {
        if let definition = settings.assistantShortcutDefinition {
            handleInHouseShortcutEvent(
                definition: definition,
                event: event,
                state: presetState,
                handler: shortcutHandler,
                onDown: { [weak self] activationMode in
                    Task { @MainActor [weak self] in await self?.handleShortcutDown(activationModeOverride: activationMode) }
                },
                onUp: { [weak self] activationMode in
                    Task { @MainActor [weak self] in await self?.handleShortcutUp(activationModeOverride: activationMode) }
                }
            )
        }
        handleIntegrationKeyEvent(event)
    }

    private func handleIntegrationKeyEvent(_ event: NSEvent) {
        guard !shouldUseAssistantShortcutLayer else {
            return
        }

        for integration in settings.assistantIntegrations where integration.isEnabled {
            guard let definition = integration.shortcutDefinition else {
                continue
            }

            let state = integrationState(for: integration.id)
            let handler = integrationShortcutHandlers[integration.id] ?? makeIntegrationShortcutHandler(for: integration.id)
            integrationShortcutHandlers[integration.id] = handler
            handleInHouseShortcutEvent(
                definition: definition,
                event: event,
                state: state,
                handler: handler,
                onDown: { [weak self] activationMode in
                    Task { @MainActor [weak self] in
                        await self?.handleIntegrationShortcutDown(
                            integrationID: integration.id,
                            activationModeOverride: activationMode
                        )
                    }
                },
                onUp: { [weak self] activationMode in
                    Task { @MainActor [weak self] in
                        await self?.handleIntegrationShortcutUp(
                            integrationID: integration.id,
                            activationModeOverride: activationMode
                        )
                    }
                }
            )
        }
    }

    private func handleCustomShortcutDown() async {
        guard settings.assistantShortcutDefinition == nil else {
            return
        }
        guard settings.assistantModifierShortcutGesture == nil else {
            return
        }

        guard settings.assistantSelectedPresetKey == .custom else {
            return
        }

        await handleShortcutDown()
    }

    private func handleCustomShortcutUp() async {
        guard settings.assistantShortcutDefinition == nil else {
            return
        }
        guard settings.assistantModifierShortcutGesture == nil else {
            return
        }

        guard settings.assistantSelectedPresetKey == .custom else {
            return
        }

        await handleShortcutUp()
    }

    private func handleIntegrationCustomShortcutDown(integrationID: UUID) async {
        guard let integration = integration(for: integrationID),
              integration.isEnabled,
              integration.shortcutDefinition == nil,
              integration.modifierShortcutGesture == nil,
              integration.shortcutPresetKey == .custom
        else {
            return
        }

        await handleIntegrationShortcutDown(integrationID: integrationID)
    }

    private func handleIntegrationCustomShortcutUp(integrationID: UUID) async {
        guard let integration = integration(for: integrationID),
              integration.isEnabled,
              integration.shortcutDefinition == nil,
              integration.modifierShortcutGesture == nil,
              integration.shortcutPresetKey == .custom
        else {
            return
        }

        await handleIntegrationShortcutUp(integrationID: integrationID)
    }

    private func handleShortcutDown(activationModeOverride: ShortcutActivationMode? = nil) async {
        if shouldUseAssistantShortcutLayer {
            let activationMode = activationModeOverride ?? settings.assistantShortcutActivationMode
            if activationMode == .doubleTap {
                return
            }
            armShortcutLayer()
            return
        }

        shortcutHandler.handleShortcutDown(activationMode: activationModeOverride ?? settings.assistantShortcutActivationMode)
    }

    private func handleShortcutUp(activationModeOverride: ShortcutActivationMode? = nil) async {
        if shouldUseAssistantShortcutLayer {
            let activationMode = activationModeOverride ?? settings.assistantShortcutActivationMode
            if activationMode == .doubleTap {
                registerLayerLeaderTap()
            }
            return
        }

        shortcutHandler.handleShortcutUp(activationMode: activationModeOverride ?? settings.assistantShortcutActivationMode)
    }

    private func handleIntegrationShortcutDown(
        integrationID: UUID,
        activationModeOverride: ShortcutActivationMode? = nil
    ) async {
        guard let integration = integration(for: integrationID), integration.isEnabled else {
            return
        }

        settings.assistantSelectedIntegrationId = integrationID
        let shortcutHandler = integrationShortcutHandlers[integrationID] ?? makeIntegrationShortcutHandler(for: integrationID)
        integrationShortcutHandlers[integrationID] = shortcutHandler
        shortcutHandler.handleShortcutDown(activationMode: activationModeOverride ?? integration.shortcutActivationMode)
    }

    private func handleIntegrationShortcutUp(
        integrationID: UUID,
        activationModeOverride: ShortcutActivationMode? = nil
    ) async {
        guard let integration = integration(for: integrationID), integration.isEnabled else {
            return
        }

        let shortcutHandler = integrationShortcutHandlers[integrationID] ?? makeIntegrationShortcutHandler(for: integrationID)
        integrationShortcutHandlers[integrationID] = shortcutHandler
        shortcutHandler.handleShortcutUp(activationMode: activationModeOverride ?? integration.shortcutActivationMode)
    }

    private func performAction(_ action: SmartShortcutHandler.Action) async {
        switch action {
        case .startRecording:
            await assistantService.startRecording(flow: .assistantMode)
        case .stopRecording:
            await assistantService.stopAndProcess()
        }
    }

    private func performIntegrationAction(_ action: SmartShortcutHandler.Action, integrationID: UUID) async {
        switch action {
        case .startRecording:
            settings.assistantSelectedIntegrationId = integrationID
            await assistantService.startRecording(flow: .integrationDispatch)
        case .stopRecording:
            await assistantService.stopAndProcess()
        }
    }

    private func makeIntegrationShortcutHandler(for integrationID: UUID) -> SmartShortcutHandler {
        SmartShortcutHandler(
            doubleTapInterval: currentDoubleTapInterval,
            isRecordingProvider: { [weak self] in self?.assistantService.isRecording ?? false },
            actionHandler: { [weak self] action in
                Task { @MainActor in
                    await self?.performIntegrationAction(action, integrationID: integrationID)
                }
            }
        )
    }

    private func integration(for id: UUID) -> AssistantIntegrationConfig? {
        settings.assistantIntegrations.first(where: { $0.id == id })
    }

    private func integrationState(for integrationID: UUID) -> ShortcutActivationState {
        if let existingState = integrationPresetStates[integrationID] {
            return existingState
        }

        let newState = ShortcutActivationState()
        integrationPresetStates[integrationID] = newState
        return newState
    }

    private func handleInHouseShortcutEvent(
        definition: ShortcutDefinition,
        event: NSEvent,
        state: ShortcutActivationState,
        handler: SmartShortcutHandler,
        onDown: @escaping (ShortcutActivationMode) -> Void,
        onUp: @escaping (ShortcutActivationMode) -> Void
    ) {
        let isActive = state.isShortcutActive(definition, event: event)
        let wasPressed = handler.isPressed
        handler.handleModifierChange(isActive: isActive)
        let activationMode = definition.trigger.asShortcutActivationMode

        if isActive, !wasPressed {
            onDown(activationMode)
        } else if !isActive, wasPressed {
            onUp(activationMode)
        }
    }

    private func resetShortcutState() {
        lastEscapePressTime = nil
        lastLayerLeaderTapTime = nil
        disarmShortcutLayer(showFeedback: false)
        presetState.reset()
        shortcutHandler.reset()
        integrationPresetStates.values.forEach { $0.reset() }
        integrationShortcutHandlers.values.forEach { $0.reset() }
    }

    private var shouldUseAssistantShortcutLayer: Bool {
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

    private func armShortcutLayer() {
        isShortcutLayerArmed = true
        shortcutLayerKeySuppressor.start()
        shortcutLayerFeedbackController.showArmed()

        let timeoutNanoseconds = layerTimeoutNanoseconds
        shortcutLayerTask?.cancel()
        shortcutLayerTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: timeoutNanoseconds)
            self?.disarmShortcutLayer(showFeedback: false)
        }
    }

    private func disarmShortcutLayer(showFeedback: Bool) {
        isShortcutLayerArmed = false
        shortcutLayerKeySuppressor.stop()
        shortcutLayerTask?.cancel()
        shortcutLayerTask = nil

        if showFeedback {
            shortcutLayerFeedbackController.showCancelled()
        } else {
            shortcutLayerFeedbackController.hide()
        }
    }

    private func registerLayerLeaderTap() {
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

    private var currentDoubleTapInterval: TimeInterval {
        settings.shortcutDoubleTapIntervalMilliseconds / 1_000
    }

    private func applyGlobalDoubleTapInterval() {
        let interval = currentDoubleTapInterval
        shortcutHandler.setDoubleTapInterval(interval)
        integrationShortcutHandlers.values.forEach { $0.setDoubleTapInterval(interval) }
    }

    private func handleShortcutLayerKeyDown(_ event: NSEvent) -> Bool {
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

    private func isModifierKeyCode(_ keyCode: UInt16) -> Bool {
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
}

private final class ShortcutLayerKeySuppressor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    func start() {
        guard eventTap == nil else {
            return
        }

        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else {
                return Unmanaged.passUnretained(event)
            }

            let suppressor = Unmanaged<ShortcutLayerKeySuppressor>
                .fromOpaque(userInfo)
                .takeUnretainedValue()
            return suppressor.handle(type: type, event: event)
        }

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            AppLogger.warning(
                "Failed to create shortcut layer key suppressor tap",
                category: .assistant
            )
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        guard let source else {
            AppLogger.warning(
                "Failed to create runloop source for shortcut layer key suppressor",
                category: .assistant
            )
            return
        }

        self.eventTap = eventTap
        runLoopSource = source

        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }

        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        runLoopSource = nil
        eventTap = nil
    }

    deinit {
        stop()
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        case .keyDown, .keyUp:
            return nil
        default:
            return Unmanaged.passUnretained(event)
        }
    }
}

@MainActor
private final class ShortcutLayerFeedbackController {
    private var window: NSPanel?
    private var hideTask: Task<Void, Never>?

    func showArmed() {
        show(message: "⌨︎")
    }

    func showCancelled() {
        show(message: "×")
    }

    func showTriggered() {
        show(message: "✓")
    }

    func hide() {
        hideTask?.cancel()
        hideTask = nil
        window?.orderOut(nil)
    }

    private func show(message: String) {
        hideTask?.cancel()

        let panel = makeOrReusePanel()
        if let textField = panel.contentView?.subviews.first as? NSTextField {
            textField.stringValue = message
        }

        position(panel)
        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            panel.animator().alphaValue = 1
        }

        hideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.12
                panel.animator().alphaValue = 0
            } completionHandler: {
                Task { @MainActor in
                    panel.orderOut(nil)
                    panel.alphaValue = 1
                }
            }
        }
    }

    private func makeOrReusePanel() -> NSPanel {
        if let window {
            return window
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 46, height: 30),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        let container = NSView(frame: panel.contentView!.bounds)
        container.wantsLayer = true
        container.layer?.cornerRadius = 10
        container.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.8).cgColor
        container.layer?.borderWidth = 1
        container.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.6).cgColor

        let label = NSTextField(labelWithString: "⌨︎")
        label.alignment = .center
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .secondaryLabelColor
        label.frame = container.bounds
        label.autoresizingMask = [.width, .height]

        container.addSubview(label)
        panel.contentView = container

        window = panel
        return panel
    }

    private func position(_ panel: NSPanel) {
        guard let screenFrame = NSScreen.main?.visibleFrame else {
            return
        }

        let originX = screenFrame.midX - (panel.frame.width / 2)
        let originY = screenFrame.maxY - panel.frame.height - 20
        panel.setFrameOrigin(NSPoint(x: originX, y: originY))
    }
}
