import Foundation
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

@MainActor
public final class AssistantVoiceCommandService: ObservableObject {
    @Published public private(set) var isRecording = false
    @Published public private(set) var isProcessing = false

    private let audioRecorder: AudioRecorder
    private let transcriptionClient: TranscriptionClient
    private let postProcessingService: PostProcessingService
    private let recordingManager: RecordingManager
    private let indicator: FloatingRecordingIndicatorController
    private let selectionService: AssistantTextSelectionService
    private let screenBorder: AssistantScreenBorderController
    private let settings: AppSettingsStore
    private let raycastIntegrationService: any AssistantDeepLinkDispatching
    private let scriptRunner: AssistantBashScriptRunner

    private var currentRecordingURL: URL?

    public init(
        audioRecorder: AudioRecorder = .shared,
        transcriptionClient: TranscriptionClient = .shared,
        postProcessingService: PostProcessingService = .shared,
        recordingManager: RecordingManager = .shared,
        indicator: FloatingRecordingIndicatorController = FloatingRecordingIndicatorController(),
        selectionService: AssistantTextSelectionService = AssistantTextSelectionService(),
        screenBorder: AssistantScreenBorderController = AssistantScreenBorderController(),
        settings: AppSettingsStore = .shared,
        raycastIntegrationService: any AssistantDeepLinkDispatching = AssistantRaycastIntegrationService(),
        scriptRunner: AssistantBashScriptRunner = AssistantBashScriptRunner()
    ) {
        self.audioRecorder = audioRecorder
        self.transcriptionClient = transcriptionClient
        self.postProcessingService = postProcessingService
        self.recordingManager = recordingManager
        self.indicator = indicator
        self.selectionService = selectionService
        self.screenBorder = screenBorder
        self.settings = settings
        self.raycastIntegrationService = raycastIntegrationService
        self.scriptRunner = scriptRunner
    }

    public func startRecording() async {
        guard !isRecording, !isProcessing else { return }

        guard !recordingManager.isRecording else {
            AppLogger.info("Assistant start blocked because Recording is active", category: .assistant)
            return
        }

        guard await RecordingExclusivityCoordinator.shared.beginAssistant() else {
            AppLogger.info("Assistant recording start blocked by exclusivity coordinator", category: .assistant)
            return
        }

        let hasPermission = await audioRecorder.hasPermission()
        if !hasPermission {
            await audioRecorder.requestPermission()
        }

        guard await audioRecorder.hasPermission() else {
            await RecordingExclusivityCoordinator.shared.endAssistant()
            showError(.microphonePermissionRequired)
            return
        }

        do {
            let outputURL = makeTemporaryRecordingURL()
            currentRecordingURL = outputURL

            try await audioRecorder.startRecording(to: outputURL, source: .microphone)
            isRecording = true
            indicator.show(mode: .recording)
            screenBorder.show()
        } catch {
            await RecordingExclusivityCoordinator.shared.endAssistant()
            showError(.failedToStartRecording)
        }
    }

    public func stopAndProcess() async {
        guard isRecording else { return }
        guard !isProcessing else { return }

        isProcessing = true
        indicator.update(mode: .processing)

        let recordingURL = await audioRecorder.stopRecording()
        isRecording = false
        await RecordingExclusivityCoordinator.shared.endAssistant()

        do {
            guard let recordingURL else {
                throw AssistantVoiceCommandError.failedToStopRecording
            }

            let transcription = try await transcriptionClient.transcribe(audioURL: recordingURL)
            let command = transcription.text.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !command.isEmpty else {
                throw AssistantVoiceCommandError.emptyCommand
            }

            guard let selectedIntegration = settings.assistantSelectedIntegration,
                  selectedIntegration.isEnabled
            else {
                throw AssistantVoiceCommandError.integrationDisabled
            }

            let outputMode = selectedIntegration.outputMode
            AppLogger.info(
                "Assistant command processed",
                category: .assistant,
                extra: [
                    "integration": selectedIntegration.name,
                    "outputMode": outputMode.rawValue,
                    "commandLength": command.count,
                ]
            )

            if shouldReplaceSelection(for: outputMode) {
                let (selectedText, snapshot) = try await selectionService.captureSelectedText()

                guard let beforeAIInput = try await applyScriptIfNeeded(
                    stage: .beforeAI,
                    input: selectedText,
                    integration: selectedIntegration
                ) else {
                    indicator.hide()
                    screenBorder.hide()
                    isProcessing = false
                    return
                }

                let promptInstructions = normalizedPromptInstructions(from: selectedIntegration)
                let promptText = promptInstructions ?? command

                let prompt = PostProcessingPrompt(
                    title: "assistant.prompt_title".localized,
                    promptText: promptText
                )

                let processed = try await postProcessingService.processTranscription(
                    beforeAIInput,
                    with: prompt,
                    systemPromptOverride: AIPromptTemplates.assistantSystemPrompt
                )

                guard let output = try await applyScriptIfNeeded(
                    stage: .afterAI,
                    input: processed,
                    integration: selectedIntegration
                ) else {
                    indicator.hide()
                    screenBorder.hide()
                    isProcessing = false
                    return
                }

                try await selectionService.replaceSelectedText(
                    with: output,
                    restoring: snapshot
                )
            }

            if shouldSendToRaycast(for: outputMode) {
                let raycastPrompt = PostProcessingPrompt(
                    title: "assistant.raycast.prompt_title".localized,
                    promptText: normalizedPromptInstructions(from: selectedIntegration) ?? command
                )

                guard let beforeAICommand = try await applyScriptIfNeeded(
                    stage: .beforeAI,
                    input: command,
                    integration: selectedIntegration
                ) else {
                    indicator.hide()
                    screenBorder.hide()
                    isProcessing = false
                    return
                }

                let processedRaycastCommand = try await postProcessingService.processTranscription(
                    beforeAICommand,
                    with: raycastPrompt
                )

                guard let commandForDispatch = try await applyScriptIfNeeded(
                    stage: .afterAI,
                    input: processedRaycastCommand,
                    integration: selectedIntegration
                ) else {
                    indicator.hide()
                    screenBorder.hide()
                    isProcessing = false
                    return
                }

                let dispatchResult = try dispatchToRaycast(
                    with: commandForDispatch,
                    selectedIntegration: selectedIntegration
                )
                if dispatchResult == .openedWithClipboardFallback {
                    indicator.showError("settings.assistant.integrations.test_success_clipboard_fallback".localized)
                }
                AppLogger.info(
                    "Assistant Raycast dispatch completed",
                    category: .assistant,
                    extra: [
                        "integrationId": selectedIntegration.id.uuidString,
                        "integrationName": selectedIntegration.name,
                        "result": dispatchResult == .openedWithClipboardFallback ? "clipboardFallback" : "deepLink",
                        "processedLength": processedRaycastCommand.count,
                    ]
                )
            }

            indicator.hide()
            screenBorder.hide()
        } catch let error as AssistantVoiceCommandError {
            AppLogger.error("Assistant processing failed with known error", category: .assistant, error: error)
            showError(error)
        } catch let error as PostProcessingError {
            AppLogger.error("Assistant post-processing failed", category: .assistant, error: error)
            indicator.showError(error.localizedDescription)
        } catch {
            AppLogger.error("Assistant processing failed with unexpected error", category: .assistant, error: error)
            showError(.processingFailed)
        }

        isProcessing = false
        screenBorder.hide()
        cleanupRecordingFile(recordingURL ?? currentRecordingURL)
        currentRecordingURL = nil
    }

    public func cancelRecording() async {
        guard isRecording else { return }

        _ = await audioRecorder.stopRecording()
        isRecording = false
        isProcessing = false
        await RecordingExclusivityCoordinator.shared.endAssistant()
        indicator.hide()
        screenBorder.hide()
        cleanupRecordingFile(currentRecordingURL)
        currentRecordingURL = nil
    }

    private func makeTemporaryRecordingURL() -> URL {
        let fileName = "assistant-command-\(UUID().uuidString).m4a"
        return FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
    }

    private func cleanupRecordingFile(_ url: URL?) {
        guard let url else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private func shouldReplaceSelection(for mode: AssistantIntegrationOutputMode) -> Bool {
        mode == .replaceSelection || mode == .both
    }

    private func shouldSendToRaycast(for mode: AssistantIntegrationOutputMode) -> Bool {
        mode == .sendToRaycast || mode == .both
    }

    private func dispatchToRaycast(
        with command: String,
        selectedIntegration: AssistantIntegrationConfig
    ) throws -> AssistantIntegrationDispatchResult {
        do {
            return try raycastIntegrationService.dispatch(
                command: command,
                baseDeepLink: selectedIntegration.deepLink
            )
        } catch AssistantIntegrationDispatchError.invalidDeepLink {
            throw AssistantVoiceCommandError.raycastDeeplinkInvalid
        } catch AssistantIntegrationDispatchError.openFailed {
            throw AssistantVoiceCommandError.raycastOpenFailed
        }
    }

    private func applyScriptIfNeeded(
        stage: AssistantIntegrationScriptConfig.Stage,
        input: String,
        integration: AssistantIntegrationConfig?
    ) async throws -> String? {
        guard let integration,
              integration.isEnabled,
              let scriptConfig = integration.advancedScript,
              scriptConfig.stage == stage
        else {
            return input
        }

        let output = try await scriptRunner.run(
            script: scriptConfig.script,
            input: input,
            timeoutSeconds: 15
        )

        if output == nil {
            AppLogger.info(
                "Assistant script returned empty output; skipping remaining processing",
                category: .assistant,
                extra: ["stage": stage.rawValue, "integration": integration.name]
            )
        }

        return output
    }

    private func normalizedPromptInstructions(from integration: AssistantIntegrationConfig) -> String? {
        let normalized = integration.promptInstructions?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let normalized, !normalized.isEmpty else {
            return nil
        }
        return normalized
    }

    private func showError(_ error: AssistantVoiceCommandError) {
        indicator.showError(error.localizedDescription)
    }
}

public enum AssistantVoiceCommandError: LocalizedError {
    case microphonePermissionRequired
    case accessibilityPermissionRequired
    case noSelectionFound
    case emptyCommand
    case failedToStartRecording
    case failedToStopRecording
    case recordingInProgress
    case processingFailed
    case integrationDisabled
    case raycastIntegrationDisabled
    case raycastDeeplinkInvalid
    case raycastOpenFailed

    public var errorDescription: String? {
        switch self {
        case .microphonePermissionRequired:
            "assistant.error.microphone_permission".localized
        case .accessibilityPermissionRequired:
            "assistant.error.accessibility_permission".localized
        case .noSelectionFound:
            "assistant.error.no_selection".localized
        case .emptyCommand:
            "assistant.error.empty_command".localized
        case .failedToStartRecording:
            "assistant.error.start_failed".localized
        case .failedToStopRecording:
            "assistant.error.stop_failed".localized
        case .recordingInProgress:
            "assistant.error.recording_in_progress".localized
        case .processingFailed:
            "assistant.error.processing_failed".localized
        case .integrationDisabled:
            "assistant.error.integration_disabled".localized
        case .raycastIntegrationDisabled:
            "assistant.error.raycast_integration_disabled".localized
        case .raycastDeeplinkInvalid:
            "assistant.error.raycast_deeplink_invalid".localized
        case .raycastOpenFailed:
            "assistant.error.raycast_open_failed".localized
        }
    }
}
