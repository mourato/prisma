import Foundation
import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain

public extension AppSettingsStore {
    /// Active integration resolved from selected ID.
    var assistantSelectedIntegration: AssistantIntegrationConfig? {
        if let id = assistantSelectedIntegrationId,
           let selected = assistantIntegrations.first(where: { $0.id == id })
        {
            return selected
        }
        return assistantIntegrations.first
    }

    /// Snapshot of all currently configured shortcuts in the normalized in-house format.
    var configuredShortcutBindings: [ShortcutBinding] {
        var bindings: [ShortcutBinding] = []

        appendResolvedShortcutBinding(
            to: &bindings,
            actionID: .dictation,
            actionDisplayName: "settings.shortcuts.dictation".localized,
            shortcut: dictationShortcutDefinition,
            explicitGesture: dictationModifierShortcutGesture,
            legacyPresetKey: dictationSelectedPresetKey,
            activationMode: dictationShortcutActivationMode
        )

        appendResolvedShortcutBinding(
            to: &bindings,
            actionID: .assistant,
            actionDisplayName: "settings.assistant.toggle_command".localized,
            shortcut: assistantShortcutDefinition,
            explicitGesture: assistantModifierShortcutGesture,
            legacyPresetKey: assistantSelectedPresetKey,
            activationMode: assistantShortcutActivationMode
        )

        appendResolvedShortcutBinding(
            to: &bindings,
            actionID: .meeting,
            actionDisplayName: "settings.shortcuts.meeting".localized,
            shortcut: meetingShortcutDefinition,
            explicitGesture: meetingModifierShortcutGesture,
            legacyPresetKey: meetingSelectedPresetKey,
            activationMode: shortcutActivationMode
        )

        for integration in assistantIntegrations where integration.isEnabled {
            let resolvedShortcut = integration.shortcutDefinition
                .flatMap {
                    normalizedInHouseShortcutDefinition($0, activationMode: integration.shortcutActivationMode)
                } ??
                integration.modifierShortcutGesture
                .flatMap {
                    normalizedInHouseShortcutDefinition($0.asShortcutDefinition, activationMode: integration.shortcutActivationMode)
                } ??
                integration.shortcutPresetKey
                .asLegacyModifierGesture(activationMode: integration.shortcutActivationMode)
                .flatMap {
                    normalizedInHouseShortcutDefinition($0.asShortcutDefinition, activationMode: integration.shortcutActivationMode)
                }

            guard let resolvedShortcut, !resolvedShortcut.isEmpty else {
                continue
            }

            bindings.append(
                ShortcutBinding(
                    actionID: .assistantIntegration(integration.id),
                    actionDisplayName: integration.name,
                    shortcut: resolvedShortcut
                )
            )
        }

        return bindings
    }

    func shortcutConflict(for candidate: ShortcutBinding) -> ShortcutConflict? {
        ModifierShortcutConflictService.conflict(
            for: candidate,
            in: configuredShortcutBindings
        )
    }

    var shortcutConflicts: [ShortcutConflict] {
        ModifierShortcutConflictService.allConflicts(in: configuredShortcutBindings)
    }

    func upsertAssistantIntegration(_ integration: AssistantIntegrationConfig) {
        if let index = assistantIntegrations.firstIndex(where: { $0.id == integration.id }) {
            var updated = assistantIntegrations
            updated[index] = integration
            assistantIntegrations = updated
        } else {
            var updated = assistantIntegrations
            updated.append(integration)
            assistantIntegrations = updated

            if assistantSelectedIntegrationId == nil {
                assistantSelectedIntegrationId = integration.id
            }
        }
    }

    func removeAssistantIntegration(id: UUID) {
        let filtered = assistantIntegrations.filter { $0.id != id }
        guard filtered.count != assistantIntegrations.count else { return }
        assistantIntegrations = filtered
    }
}

extension AppSettingsStore {
    static func resolveShortcutDefinition(
        explicitGesture: ModifierShortcutGesture?,
        legacyPresetKey: PresetShortcutKey,
        activationMode: ShortcutActivationMode
    ) -> ShortcutDefinition? {
        if let explicitGesture {
            return normalizedInHouseShortcutDefinition(
                explicitGesture.asShortcutDefinition,
                activationMode: activationMode
            )
        }

        guard let legacyGesture = legacyPresetKey.asLegacyModifierGesture(activationMode: activationMode) else {
            return nil
        }

        return normalizedInHouseShortcutDefinition(
            legacyGesture.asShortcutDefinition,
            activationMode: activationMode
        )
    }

    func appendResolvedShortcutBinding(
        to bindings: inout [ShortcutBinding],
        actionID: ModifierShortcutActionID,
        actionDisplayName: String,
        shortcut: ShortcutDefinition?,
        explicitGesture: ModifierShortcutGesture?,
        legacyPresetKey: PresetShortcutKey,
        activationMode: ShortcutActivationMode
    ) {
        let resolvedShortcut = shortcut ??
            Self.resolveShortcutDefinition(
                explicitGesture: explicitGesture,
                legacyPresetKey: legacyPresetKey,
                activationMode: activationMode
            )
        guard let resolvedShortcut, !resolvedShortcut.isEmpty else {
            return
        }

        bindings.append(
            ShortcutBinding(
                actionID: actionID,
                actionDisplayName: actionDisplayName,
                shortcut: resolvedShortcut
            )
        )
    }

    func synchronizeAssistantIntegrationsState() {
        var normalizedIntegrations = assistantIntegrations

        if normalizedIntegrations.isEmpty {
            normalizedIntegrations = [AssistantIntegrationConfig.defaultRaycast]
        }

        normalizedIntegrations = normalizedIntegrations.map { integration in
            var normalized = integration
            normalized.layerShortcutKey = Self.normalizedLayerShortcutKey(normalized.layerShortcutKey)

            let normalizedShortcut = normalized.shortcutDefinition
                .flatMap {
                    normalizedInHouseShortcutDefinition($0, activationMode: normalized.shortcutActivationMode)
                } ??
                normalized.modifierShortcutGesture
                .flatMap {
                    normalizedInHouseShortcutDefinition($0.asShortcutDefinition, activationMode: normalized.shortcutActivationMode)
                } ??
                normalized.shortcutPresetKey
                .asLegacyModifierGesture(activationMode: normalized.shortcutActivationMode)
                .flatMap {
                    normalizedInHouseShortcutDefinition($0.asShortcutDefinition, activationMode: normalized.shortcutActivationMode)
                }
            normalized.shortcutDefinition = normalizedShortcut

            if let canonicalGesture = normalized.shortcutDefinition?.asModifierShortcutGesture {
                normalized.modifierShortcutGesture = canonicalGesture
                normalized.shortcutPresetKey = .custom
                normalized.shortcutActivationMode = canonicalGesture.triggerMode.asShortcutActivationMode
            }

            guard normalized.id == AssistantIntegrationConfig.raycastDefaultID else {
                return normalized
            }

            normalized.shortcutPresetKey = .custom
            normalized.shortcutActivationMode = .toggle
            normalized.deepLink = AssistantIntegrationConfig.defaultRaycastDeepLink
            normalized.layerShortcutKey = normalized.layerShortcutKey ?? "R"
            return normalized
        }

        if normalizedIntegrations != assistantIntegrations {
            isSynchronizingAssistantIntegrations = true
            assistantIntegrations = normalizedIntegrations
            isSynchronizingAssistantIntegrations = false
        }

        if let selectedID = assistantSelectedIntegrationId,
           assistantIntegrations.contains(where: { $0.id == selectedID }) == false
        {
            assistantSelectedIntegrationId = assistantIntegrations.first?.id
        }

        if assistantSelectedIntegrationId == nil {
            assistantSelectedIntegrationId = assistantIntegrations.first?.id
        }

        if let raycast = assistantIntegrations.first(where: { $0.id == AssistantIntegrationConfig.raycastDefaultID }) {
            assistantRaycastEnabled = raycast.isEnabled
            assistantRaycastDeepLink = raycast.deepLink
        }
    }
}
