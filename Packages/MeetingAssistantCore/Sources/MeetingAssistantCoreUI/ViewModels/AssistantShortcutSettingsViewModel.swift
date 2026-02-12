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
    @Published public var integrationOutputMode: AssistantIntegrationOutputMode
    @Published public var assistantIntegrations: [AssistantIntegrationConfig]
    @Published public var selectedIntegrationId: UUID?
    @Published public var integrationName: String
    @Published public var integrationEnabled: Bool
    @Published public var integrationDeepLink: String
    @Published public private(set) var raycastTestStatusMessage: String?
    @Published public private(set) var raycastTestStatusIsError: Bool = false
    @Published public private(set) var raycastDeepLinkIsValid: Bool = true
    @Published public private(set) var raycastDeepLinkValidationMessage: String?

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
        integrationOutputMode = settings.assistantIntegrationOutputMode
        assistantIntegrations = persistedIntegrations
        selectedIntegrationId = resolvedSelectedIntegration?.id
        integrationName = resolvedSelectedIntegration?.name ?? ""
        integrationEnabled = resolvedSelectedIntegration?.isEnabled ?? false
        integrationDeepLink = resolvedSelectedIntegration?.deepLink ?? ""
        raycastTestStatusMessage = nil
        raycastDeepLinkValidationMessage = nil

        setupBindings()
        updateRaycastDeepLinkValidation()
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

        $integrationOutputMode
            .dropFirst()
            .sink { [weak self] newValue in
                self?.settings.assistantIntegrationOutputMode = newValue
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
                self?.synchronizeSelectedIntegrationState()
                self?.updateRaycastDeepLinkValidation()
            }
            .store(in: &cancellables)

        $integrationEnabled
            .dropFirst()
            .sink { [weak self] newValue in
                self?.updateSelectedIntegration { integration in
                    integration.isEnabled = newValue
                }
                self?.updateRaycastDeepLinkValidation()
            }
            .store(in: &cancellables)

        $integrationName
            .dropFirst()
            .sink { [weak self] newValue in
                self?.updateSelectedIntegration { integration in
                    integration.name = newValue
                }
            }
            .store(in: &cancellables)

        $integrationDeepLink
            .dropFirst()
            .sink { [weak self] newValue in
                self?.updateSelectedIntegration { integration in
                    integration.deepLink = newValue
                }
                self?.updateRaycastDeepLinkValidation()
            }
            .store(in: &cancellables)
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

    public func testRaycastIntegration() {
        AppLogger.info(
            "Running Raycast integration test",
            category: .assistant,
            extra: ["deepLinkLength": integrationDeepLink.count]
        )

        do {
            let result = try raycastIntegrationService.dispatch(
                command: "settings.assistant.integrations.test_message".localized,
                baseDeepLink: integrationDeepLink
            )

            raycastTestStatusIsError = false
            raycastTestStatusMessage = result == .openedWithClipboardFallback
                ? "settings.assistant.integrations.test_success_clipboard_fallback".localized
                : "settings.assistant.integrations.test_success".localized
            AppLogger.info(
                "Raycast integration test completed",
                category: .assistant,
                extra: ["result": result == .openedWithClipboardFallback ? "clipboardFallback" : "deepLink"]
            )
        } catch AssistantIntegrationDispatchError.invalidDeepLink {
            raycastTestStatusIsError = true
            raycastTestStatusMessage = "settings.assistant.integrations.test_invalid_deeplink".localized
            AppLogger.warning("Raycast integration test failed: invalid deeplink", category: .assistant)
        } catch {
            raycastTestStatusIsError = true
            raycastTestStatusMessage = "settings.assistant.integrations.test_failed".localized
            AppLogger.error("Raycast integration test failed", category: .assistant, error: error)
        }
    }

    public var canRemoveSelectedIntegration: Bool {
        assistantIntegrations.count > 1 && selectedIntegrationId != nil
    }

    public func addIntegration() {
        let nextIndex = assistantIntegrations.count + 1
        let newIntegration = AssistantIntegrationConfig(
            name: "settings.assistant.integrations.default_name".localized(with: nextIndex),
            kind: .deeplink,
            isEnabled: false,
            deepLink: "raycast://ai-commands/ask-ai"
        )

        assistantIntegrations = assistantIntegrations + [newIntegration]
        selectedIntegrationId = newIntegration.id
        raycastTestStatusMessage = nil
    }

    public func removeSelectedIntegration() {
        guard let id = selectedIntegrationId,
              assistantIntegrations.count > 1
        else {
            return
        }

        let updated = assistantIntegrations.filter { $0.id != id }
        assistantIntegrations = updated
        selectedIntegrationId = updated.first?.id
        raycastTestStatusMessage = nil
    }

    private func updateRaycastDeepLinkValidation() {
        guard integrationEnabled else {
            raycastDeepLinkIsValid = true
            raycastDeepLinkValidationMessage = nil
            return
        }

        let validation = raycastIntegrationService.validateDeepLink(integrationDeepLink)
        switch validation {
        case .valid:
            raycastDeepLinkIsValid = true
            raycastDeepLinkValidationMessage = "settings.assistant.integrations.valid_deeplink".localized
            AppLogger.debug("Raycast deeplink marked as valid in settings", category: .assistant)
        case .invalid:
            raycastDeepLinkIsValid = false
            raycastDeepLinkValidationMessage = "settings.assistant.integrations.invalid_deeplink".localized
            AppLogger.warning("Raycast deeplink marked as invalid in settings", category: .assistant)
        }
    }

    private func synchronizeSelectedIntegrationState() {
        guard let id = selectedIntegrationId,
              let selected = assistantIntegrations.first(where: { $0.id == id })
        else {
            integrationName = ""
            integrationEnabled = false
            integrationDeepLink = ""
            return
        }

        integrationName = selected.name
        integrationEnabled = selected.isEnabled
        integrationDeepLink = selected.deepLink
    }

    private func updateSelectedIntegration(_ mutate: (inout AssistantIntegrationConfig) -> Void) {
        guard let id = selectedIntegrationId,
              let index = assistantIntegrations.firstIndex(where: { $0.id == id })
        else {
            return
        }

        var updated = assistantIntegrations
        mutate(&updated[index])
        assistantIntegrations = updated
    }
}
