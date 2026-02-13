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
    private var integrationShortcutHandlers: [UUID: SmartShortcutHandler] = [:]
    private var integrationPresetStates: [UUID: ShortcutActivationState] = [:]
    private var registeredIntegrationShortcutIDs = Set<UUID>()

    private lazy var shortcutHandler = SmartShortcutHandler(
        isRecordingProvider: { [weak self] in self?.assistantService.isRecording ?? false },
        actionHandler: { [weak self] (action: SmartShortcutHandler.Action) in
            Task { @MainActor in
                await self?.performAction(action)
            }
        }
    )

    private let presetState = ShortcutActivationState()
    private let escapeDoublePressInterval: TimeInterval = 0.5
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
        let needsModifierMonitoring = settings.assistantSelectedPresetKey.requiresModifierMonitoring
            || settings.assistantIntegrations.contains { integration in
                integration.isEnabled && integration.shortcutPresetKey.requiresModifierMonitoring
            }
        let needsEscapeMonitoring = settings.assistantUseEscapeToCancelRecording

        if needsModifierMonitoring {
            installFlagsChangedMonitors()
        } else {
            removeFlagsChangedMonitors()
        }

        if needsEscapeMonitoring {
            installKeyDownMonitors()
        } else {
            removeKeyDownMonitors()
        }
    }

    private func refreshCustomShortcutRegistration() {
        switch settings.assistantSelectedPresetKey {
        case .custom:
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

            if integration.isEnabled, integration.shortcutPresetKey == .custom {
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
            keyDownMonitor = KeyboardEventMonitor(mask: .keyDown) { [weak self] event in
                Task { @MainActor in
                    self?.handleKeyDown(event)
                }
            }
            keyDownMonitor?.start()
        }
    }

    private func removeKeyDownMonitors() {
        keyDownMonitor?.stop()
        keyDownMonitor = nil
    }

    private func removeEventMonitors() {
        removeFlagsChangedMonitors()
        removeKeyDownMonitors()
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        guard settings.assistantSelectedPresetKey.requiresModifierMonitoring else {
            handleIntegrationFlagsChanged(event)
            return
        }

        let isActive = presetState.isPresetActive(settings.assistantSelectedPresetKey, event: event)
        let wasPressed = shortcutHandler.isPressed
        shortcutHandler.handleModifierChange(isActive: isActive)

        if isActive, !wasPressed {
            Task { @MainActor [weak self] in await self?.handleShortcutDown() }
        } else if !isActive, wasPressed {
            Task { @MainActor [weak self] in await self?.handleShortcutUp() }
        }

        handleIntegrationFlagsChanged(event)
    }

    private func handleIntegrationFlagsChanged(_ event: NSEvent) {
        for integration in settings.assistantIntegrations where integration.isEnabled && integration.shortcutPresetKey.requiresModifierMonitoring {
            let presetState = integrationPresetStates[integration.id, default: ShortcutActivationState()]
            let isActive = presetState.isPresetActive(integration.shortcutPresetKey, event: event)
            let shortcutHandler = integrationShortcutHandlers[integration.id] ?? makeIntegrationShortcutHandler(for: integration.id)
            integrationShortcutHandlers[integration.id] = shortcutHandler
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

    private func handleKeyDown(_ event: NSEvent) {
        guard settings.assistantUseEscapeToCancelRecording else {
            return
        }

        guard !event.isARepeat else {
            return
        }

        guard event.keyCode == PresetShortcutKey.escapeKeyCode else {
            lastEscapePressTime = nil
            return
        }

        let now = Date()
        guard let lastEscapePressTime, now.timeIntervalSince(lastEscapePressTime) <= escapeDoublePressInterval else {
            self.lastEscapePressTime = now
            return
        }
        self.lastEscapePressTime = nil

        Task { @MainActor [weak self] in
            guard let self else { return }
            guard assistantService.isRecording else {
                return
            }

            await assistantService.cancelRecording()
        }
    }

    private func handleCustomShortcutDown() async {
        guard settings.assistantSelectedPresetKey == .custom else {
            return
        }

        await handleShortcutDown()
    }

    private func handleCustomShortcutUp() async {
        guard settings.assistantSelectedPresetKey == .custom else {
            return
        }

        await handleShortcutUp()
    }

    private func handleIntegrationCustomShortcutDown(integrationID: UUID) async {
        guard let integration = integration(for: integrationID),
              integration.isEnabled,
              integration.shortcutPresetKey == .custom
        else {
            return
        }

        await handleIntegrationShortcutDown(integrationID: integrationID)
    }

    private func handleIntegrationCustomShortcutUp(integrationID: UUID) async {
        guard let integration = integration(for: integrationID),
              integration.isEnabled,
              integration.shortcutPresetKey == .custom
        else {
            return
        }

        await handleIntegrationShortcutUp(integrationID: integrationID)
    }

    private func handleShortcutDown() async {
        shortcutHandler.handleShortcutDown(activationMode: settings.assistantShortcutActivationMode)
    }

    private func handleShortcutUp() async {
        shortcutHandler.handleShortcutUp(activationMode: settings.assistantShortcutActivationMode)
    }

    private func handleIntegrationShortcutDown(integrationID: UUID) async {
        guard let integration = integration(for: integrationID), integration.isEnabled else {
            return
        }

        settings.assistantSelectedIntegrationId = integrationID
        let shortcutHandler = integrationShortcutHandlers[integrationID] ?? makeIntegrationShortcutHandler(for: integrationID)
        integrationShortcutHandlers[integrationID] = shortcutHandler
        shortcutHandler.handleShortcutDown(activationMode: integration.shortcutActivationMode)
    }

    private func handleIntegrationShortcutUp(integrationID: UUID) async {
        guard let integration = integration(for: integrationID), integration.isEnabled else {
            return
        }

        let shortcutHandler = integrationShortcutHandlers[integrationID] ?? makeIntegrationShortcutHandler(for: integrationID)
        integrationShortcutHandlers[integrationID] = shortcutHandler
        shortcutHandler.handleShortcutUp(activationMode: integration.shortcutActivationMode)
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

    private func resetShortcutState() {
        lastEscapePressTime = nil
        presetState.reset()
        shortcutHandler.reset()
        integrationPresetStates.values.forEach { $0.reset() }
        integrationShortcutHandlers.values.forEach { $0.reset() }
    }
}
