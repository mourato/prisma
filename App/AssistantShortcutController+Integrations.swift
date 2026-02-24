import AppKit
import MeetingAssistantCore

@MainActor
extension AssistantShortcutController {
    func handleIntegrationFlagsChanged(_ event: NSEvent) {
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

    func handleIntegrationKeyEvent(_ event: NSEvent) {
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

    func handleIntegrationCustomShortcutDown(integrationID: UUID) async {
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

    func handleIntegrationCustomShortcutUp(integrationID: UUID) async {
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

    func handleIntegrationShortcutDown(
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

    func handleIntegrationShortcutUp(
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

    func performIntegrationAction(_ action: SmartShortcutHandler.Action, integrationID: UUID) async {
        switch action {
        case .startRecording:
            settings.assistantSelectedIntegrationId = integrationID
            await assistantService.startRecording(flow: .integrationDispatch)
        case .stopRecording:
            await assistantService.stopAndProcess()
        }
    }

    func makeIntegrationShortcutHandler(for integrationID: UUID) -> SmartShortcutHandler {
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

    func integration(for id: UUID) -> AssistantIntegrationConfig? {
        settings.assistantIntegrations.first(where: { $0.id == id })
    }

    func integrationState(for integrationID: UUID) -> ShortcutActivationState {
        if let existingState = integrationPresetStates[integrationID] {
            return existingState
        }

        let newState = ShortcutActivationState()
        integrationPresetStates[integrationID] = newState
        return newState
    }
}
