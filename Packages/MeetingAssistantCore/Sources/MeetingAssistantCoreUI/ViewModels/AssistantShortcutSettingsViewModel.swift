import Combine
import Foundation
import KeyboardShortcuts
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
    @Published public var testKeysInput: String = ""
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

    public init(
        raycastIntegrationService: any AssistantDeepLinkDispatching = AssistantRaycastIntegrationService()
    ) {
        let persistedIntegrations = settings.assistantIntegrations
        let resolvedSelectedIntegration = settings.assistantSelectedIntegration ?? persistedIntegrations.first

        self.raycastIntegrationService = raycastIntegrationService
        activationMode = settings.assistantShortcutActivationMode
        useEscapeToCancelRecording = settings.assistantUseEscapeToCancelRecording
        selectedPresetKey = settings.assistantSelectedPresetKey
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
            deepLink: "raycast://ai-commands/ask-ai",
            outputMode: .replaceSelection
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
            "raycast://ai-commands/ask-ai"
        case .askClaude:
            "raycast://ai-commands/ask-ai"
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

    public func resetShortcuts() {
        KeyboardShortcuts.reset(.assistantCommand)
        activationMode = .holdOrToggle
        useEscapeToCancelRecording = false
        selectedPresetKey = .rightOption
        isRecordingCustomShortcut = false
        borderColor = .green
        borderStyle = .stroke
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

    private static func executeScript(script: String, input: String) async throws -> String? {
        try await AssistantBashScriptRunner().run(script: script, input: input, timeoutSeconds: 15)
    }
}
