import Combine
import Foundation
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

@MainActor
public final class AssistantShortcutSettingsViewModel: ObservableObject {
    private let settings = AppSettingsStore.shared
    private var cancellables = Set<AnyCancellable>()
    private let raycastIntegrationService: any AssistantDeepLinkDispatching

    @Published public var activationMode: ShortcutActivationMode
    @Published public var useEscapeToCancelRecording: Bool
    @Published public var selectedPresetKey: PresetShortcutKey
    @Published public var assistantModifierShortcutGesture: ModifierShortcutGesture?
    @Published public var assistantModifierTriggerMode: ModifierShortcutTriggerMode
    @Published public var assistantModifierConflictMessage: String?
    @Published public var isRecordingCustomShortcut: Bool = false
    @Published public var borderColor: AssistantBorderColor
    @Published public var borderStyle: AssistantBorderStyle
    @Published public var assistantIntegrations: [AssistantIntegrationConfig]
    @Published public var selectedIntegrationId: UUID?

    @Published public private(set) var raycastTestStatusMessage: String?
    @Published public private(set) var raycastTestStatusIsError: Bool = false
    @Published public private(set) var raycastDeepLinkIsValid: Bool = true
    @Published public private(set) var raycastDeepLinkValidationMessage: String?

    @Published public private(set) var scriptTestOutput: String?
    @Published public private(set) var scriptTestErrorMessage: String?
    private var isApplyingModifierShortcutChange = false

    public init(
        raycastIntegrationService: any AssistantDeepLinkDispatching = AssistantRaycastIntegrationService()
    ) {
        let persistedIntegrations = settings.assistantIntegrations
        let resolvedSelectedIntegration = settings.assistantSelectedIntegration ?? persistedIntegrations.first

        self.raycastIntegrationService = raycastIntegrationService
        activationMode = settings.assistantShortcutActivationMode
        useEscapeToCancelRecording = settings.assistantUseEscapeToCancelRecording
        selectedPresetKey = settings.assistantSelectedPresetKey
        assistantModifierShortcutGesture = settings.assistantModifierShortcutGesture
        assistantModifierTriggerMode = settings.assistantModifierShortcutGesture?.triggerMode ?? .singleTap
        assistantModifierConflictMessage = nil
        isRecordingCustomShortcut = settings.assistantSelectedPresetKey == .custom
        borderColor = settings.assistantBorderColor
        borderStyle = settings.assistantBorderStyle
        assistantIntegrations = persistedIntegrations
        selectedIntegrationId = resolvedSelectedIntegration?.id

        raycastTestStatusMessage = nil
        raycastDeepLinkValidationMessage = nil
        scriptTestOutput = nil
        scriptTestErrorMessage = nil

        setupBindings()
        updateRaycastDeepLinkValidation()
    }

    public var builtInIntegrations: [AssistantIntegrationConfig] {
        assistantIntegrations.filter { $0.id == AssistantIntegrationConfig.raycastDefaultID }
    }

    public var customIntegrations: [AssistantIntegrationConfig] {
        assistantIntegrations.filter { $0.id != AssistantIntegrationConfig.raycastDefaultID }
    }

    public var canAddIntegration: Bool {
        true
    }

    public func integration(for id: UUID) -> AssistantIntegrationConfig? {
        assistantIntegrations.first(where: { $0.id == id })
    }

    public func setIntegrationEnabled(_ isEnabled: Bool, for id: UUID) {
        if isEnabled, let integration = integration(for: id) {
            var candidate = integration
            candidate.isEnabled = true
            if let conflictMessage = modifierConflictMessage(for: normalizedIntegration(candidate)) {
                raycastTestStatusIsError = true
                raycastTestStatusMessage = conflictMessage
                return
            }
        }

        updateIntegration(id: id) { integration in
            integration.isEnabled = isEnabled
        }

        if isEnabled {
            selectedIntegrationId = id
        }

        if selectedIntegrationId == id {
            updateRaycastDeepLinkValidation()
        }
    }

    public func addIntegration() {
        let nextIndex = customIntegrations.count + 1
        let newIntegration = AssistantIntegrationConfig(
            name: "settings.assistant.integrations.default_name".localized(with: nextIndex),
            kind: .deeplink,
            isEnabled: false,
            deepLink: AssistantIntegrationConfig.defaultRaycastDeepLink
        )

        assistantIntegrations = assistantIntegrations + [newIntegration]
        selectedIntegrationId = newIntegration.id
        raycastTestStatusMessage = nil
    }

    public func removeIntegration(id: UUID) {
        guard id != AssistantIntegrationConfig.raycastDefaultID else {
            return
        }

        assistantIntegrations = assistantIntegrations.filter { $0.id != id }

        if selectedIntegrationId == id {
            selectedIntegrationId = assistantIntegrations.first?.id
        }

        raycastTestStatusMessage = nil
    }

    public func saveIntegration(_ integration: AssistantIntegrationConfig) {
        updateIntegration(id: integration.id) { existing in
            existing = integration
        }

        selectedIntegrationId = integration.id
        updateRaycastDeepLinkValidation()
    }

    @discardableResult
    public func saveIntegrationWithModifierValidation(_ integration: AssistantIntegrationConfig) -> String? {
        let normalized = normalizedIntegration(integration)
        if let conflictMessage = modifierConflictMessage(for: normalized) {
            return conflictMessage
        }

        saveIntegration(normalized)
        return nil
    }

    public func applyPreset(_ preset: AssistantIntegrationPreset, to id: UUID) {
        updateIntegration(id: id) { integration in
            integration.selectedPreset = preset
            integration.deepLink = defaultDeepLink(for: preset)
        }

        updateRaycastDeepLinkValidation()
    }

    public func defaultDeepLink(for preset: AssistantIntegrationPreset) -> String {
        switch preset {
        case .googleSearch:
            "raycast://extensions/raycast/google-search/search"
        case .launchApps:
            "raycast://extensions/raycast/system/open"
        case .closeApps:
            "raycast://extensions/raycast/system/quit"
        case .askChatGPT:
            AssistantIntegrationConfig.defaultRaycastDeepLink
        case .askClaude:
            AssistantIntegrationConfig.defaultRaycastDeepLink
        case .youtubeSearch:
            "raycast://extensions/raycast/youtube/search-videos"
        case .openWebsite:
            "raycast://extensions/raycast/browser/open-url"
        case .appleShortcuts:
            "raycast://extensions/raycast/shortcuts/run-shortcut"
        case .shellCommand:
            "raycast://extensions/raycast/script-commands"
        case .pressKeys:
            "raycast://extensions/raycast/system/keyboard-shortcuts"
        }
    }

    public func validateDeepLink(_ deepLink: String, integrationEnabled: Bool) {
        guard integrationEnabled else {
            raycastDeepLinkIsValid = true
            raycastDeepLinkValidationMessage = nil
            return
        }

        let validation = raycastIntegrationService.validateDeepLink(deepLink)
        switch validation {
        case .valid:
            raycastDeepLinkIsValid = true
            raycastDeepLinkValidationMessage = "settings.assistant.integrations.valid_deeplink".localized
        case .invalid:
            raycastDeepLinkIsValid = false
            raycastDeepLinkValidationMessage = "settings.assistant.integrations.invalid_deeplink".localized
        }
    }

    public func testIntegration(_ integration: AssistantIntegrationConfig) {
        AppLogger.info(
            "Running integration test",
            category: .assistant,
            extra: ["deepLinkLength": integration.deepLink.count, "name": integration.name]
        )

        do {
            let result = try raycastIntegrationService.dispatch(
                command: "settings.assistant.integrations.test_message".localized,
                baseDeepLink: integration.deepLink
            )

            raycastTestStatusIsError = false
            raycastTestStatusMessage = result == .openedWithClipboardFallback
                ? "settings.assistant.integrations.test_success_clipboard_fallback".localized
                : "settings.assistant.integrations.test_success".localized
        } catch AssistantIntegrationDispatchError.invalidDeepLink {
            raycastTestStatusIsError = true
            raycastTestStatusMessage = "settings.assistant.integrations.test_invalid_deeplink".localized
        } catch {
            raycastTestStatusIsError = true
            raycastTestStatusMessage = "settings.assistant.integrations.test_failed".localized
        }
    }

    public func clearScriptTestResult() {
        scriptTestOutput = nil
        scriptTestErrorMessage = nil
    }

    public func testScript(script: String, input: String) async {
        do {
            scriptTestErrorMessage = nil
            let output = try await Self.executeScript(script: script, input: input)
            scriptTestOutput = output
        } catch {
            scriptTestOutput = nil
            scriptTestErrorMessage = error.localizedDescription
        }
    }

    private func setupBindings() {
        $activationMode
            .dropFirst()
            .sink { [weak self] newValue in
                self?.settings.assistantShortcutActivationMode = newValue
            }
            .store(in: &cancellables)

        $useEscapeToCancelRecording
            .dropFirst()
            .sink { [weak self] newValue in
                self?.settings.assistantUseEscapeToCancelRecording = newValue
            }
            .store(in: &cancellables)

        $selectedPresetKey
            .dropFirst()
            .sink { [weak self] newValue in
                self?.settings.assistantSelectedPresetKey = newValue
                self?.isRecordingCustomShortcut = (newValue == .custom)
            }
            .store(in: &cancellables)

        $assistantModifierShortcutGesture
            .dropFirst()
            .sink { [weak self] newValue in
                self?.handleAssistantModifierGestureChange(newValue)
            }
            .store(in: &cancellables)

        $assistantModifierTriggerMode
            .dropFirst()
            .sink { [weak self] newValue in
                self?.handleAssistantModifierTriggerModeChange(newValue)
            }
            .store(in: &cancellables)

        $borderColor
            .dropFirst()
            .sink { [weak self] newValue in
                self?.settings.assistantBorderColor = newValue
            }
            .store(in: &cancellables)

        $borderStyle
            .dropFirst()
            .sink { [weak self] newValue in
                self?.settings.assistantBorderStyle = newValue
            }
            .store(in: &cancellables)

        $assistantIntegrations
            .dropFirst()
            .sink { [weak self] newValue in
                self?.settings.assistantIntegrations = newValue
            }
            .store(in: &cancellables)

        $selectedIntegrationId
            .dropFirst()
            .sink { [weak self] newValue in
                self?.settings.assistantSelectedIntegrationId = newValue
                self?.updateRaycastDeepLinkValidation()
            }
            .store(in: &cancellables)
    }

    private func updateRaycastDeepLinkValidation() {
        guard let selectedIntegrationId,
              let selected = assistantIntegrations.first(where: { $0.id == selectedIntegrationId })
        else {
            raycastDeepLinkIsValid = true
            raycastDeepLinkValidationMessage = nil
            return
        }

        validateDeepLink(selected.deepLink, integrationEnabled: selected.isEnabled)
    }

    private func updateIntegration(id: UUID, mutate: (inout AssistantIntegrationConfig) -> Void) {
        guard let index = assistantIntegrations.firstIndex(where: { $0.id == id }) else {
            return
        }

        var updated = assistantIntegrations
        mutate(&updated[index])
        assistantIntegrations = updated
    }

    private func normalizedIntegration(_ integration: AssistantIntegrationConfig) -> AssistantIntegrationConfig {
        var normalized = integration
        if let gesture = integration.modifierShortcutGesture {
            normalized.modifierShortcutGesture = ModifierShortcutGesture(
                keys: gesture.keys,
                triggerMode: gesture.triggerMode
            )
        }
        return normalized
    }

    private func modifierConflictMessage(for integration: AssistantIntegrationConfig) -> String? {
        guard integration.isEnabled else {
            return nil
        }

        let resolvedGesture = integration.modifierShortcutGesture ??
            integration.shortcutPresetKey.asLegacyModifierGesture(activationMode: integration.shortcutActivationMode)
        guard let resolvedGesture else {
            return nil
        }

        let candidate = ModifierShortcutBinding(
            actionID: .assistantIntegration(integration.id),
            actionDisplayName: integration.name,
            gesture: resolvedGesture
        )

        guard let conflict = settings.modifierShortcutConflict(for: candidate) else {
            return nil
        }

        return "settings.shortcuts.modifier.conflict".localized(with: conflict.conflicting.actionDisplayName)
    }

    private func handleAssistantModifierGestureChange(_ newValue: ModifierShortcutGesture?) {
        guard !isApplyingModifierShortcutChange else {
            return
        }

        let normalizedValue = newValue.map {
            ModifierShortcutGesture(keys: $0.keys, triggerMode: assistantModifierTriggerMode)
        }

        guard let normalizedValue else {
            settings.assistantModifierShortcutGesture = nil
            assistantModifierConflictMessage = nil
            return
        }

        let candidate = ModifierShortcutBinding(
            actionID: .assistant,
            actionDisplayName: "settings.assistant.toggle_command".localized,
            gesture: normalizedValue
        )

        if let conflict = settings.modifierShortcutConflict(for: candidate) {
            isApplyingModifierShortcutChange = true
            assistantModifierShortcutGesture = settings.assistantModifierShortcutGesture
            assistantModifierTriggerMode = settings.assistantModifierShortcutGesture?.triggerMode ?? .singleTap
            assistantModifierConflictMessage = "settings.shortcuts.modifier.conflict".localized(with: conflict.conflicting.actionDisplayName)
            isApplyingModifierShortcutChange = false
            return
        }

        settings.assistantModifierShortcutGesture = normalizedValue
        assistantModifierConflictMessage = nil
    }

    private func handleAssistantModifierTriggerModeChange(_ newValue: ModifierShortcutTriggerMode) {
        guard !isApplyingModifierShortcutChange else {
            return
        }

        guard let gesture = assistantModifierShortcutGesture else {
            return
        }

        let updatedGesture = ModifierShortcutGesture(keys: gesture.keys, triggerMode: newValue)
        if updatedGesture == assistantModifierShortcutGesture {
            return
        }

        isApplyingModifierShortcutChange = true
        assistantModifierShortcutGesture = updatedGesture
        isApplyingModifierShortcutChange = false
        handleAssistantModifierGestureChange(updatedGesture)
    }

    private static func executeScript(script: String, input: String) async throws -> String? {
        try await AssistantBashScriptRunner().run(script: script, input: input, timeoutSeconds: 15)
    }
}
