import Foundation
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

public enum AssistantExecutionFlow: Sendable {
    case assistantMode
    case integrationDispatch
}

public enum AssistantIntegrationDeepLinkShortcode {
    public static let finalText = "{{assistant_text}}"
    public static let finalTextURLEncoded = "{{assistant_text_urlencoded}}"
    public static let rawText = "{{assistant_raw_text}}"
    public static let rawTextURLEncoded = "{{assistant_raw_text_urlencoded}}"
}

@MainActor
public final class AssistantVoiceCommandService: ObservableObject {
    @Published public private(set) var isRecording = false
    @Published public private(set) var isProcessing = false

    private let audioRecorder: AudioRecorder
    private let transcriptionClient: TranscriptionClient
    private let postProcessingService: PostProcessingService
    private let recordingManager: RecordingManager
    private let indicator: FloatingRecordingIndicatorController
    private let screenBorder: AssistantScreenBorderController
    private let settings: AppSettingsStore
    private let raycastIntegrationService: any AssistantDeepLinkDispatching
    private let scriptRunner: AssistantBashScriptRunner
    private let textSelectionService: AssistantTextSelectionService

    private var currentRecordingURL: URL?
    private var currentExecutionFlow: AssistantExecutionFlow = .assistantMode

    public init(
        audioRecorder: AudioRecorder = .shared,
        transcriptionClient: TranscriptionClient = .shared,
        postProcessingService: PostProcessingService = .shared,
        recordingManager: RecordingManager = .shared,
        indicator: FloatingRecordingIndicatorController = FloatingRecordingIndicatorController(),
        screenBorder: AssistantScreenBorderController = AssistantScreenBorderController(),
        settings: AppSettingsStore = .shared,
        raycastIntegrationService: any AssistantDeepLinkDispatching = AssistantRaycastIntegrationService(),
        scriptRunner: AssistantBashScriptRunner = AssistantBashScriptRunner(),
        textSelectionService: AssistantTextSelectionService = AssistantTextSelectionService()
    ) {
        self.audioRecorder = audioRecorder
        self.transcriptionClient = transcriptionClient
        self.postProcessingService = postProcessingService
        self.recordingManager = recordingManager
        self.indicator = indicator
        self.screenBorder = screenBorder
        self.settings = settings
        self.raycastIntegrationService = raycastIntegrationService
        self.scriptRunner = scriptRunner
        self.textSelectionService = textSelectionService
    }

    public func startRecording(flow: AssistantExecutionFlow = .assistantMode) async {
        guard !isRecording, !isProcessing else { return }
        let requestedAt = Date()

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
            currentExecutionFlow = flow

            try await audioRecorder.startRecording(to: outputURL, source: .microphone)
            isRecording = true
            indicator.show(mode: .recording)
            screenBorder.show()
            let now = Date()
            PerformanceMonitor.shared.reportMetric(
                name: "assistant_start_requested_to_recorder_ms",
                value: now.timeIntervalSince(requestedAt) * 1000,
                unit: "ms"
            )
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

        defer {
            isProcessing = false
            currentExecutionFlow = .assistantMode
            screenBorder.hide()
            cleanupRecordingFile(recordingURL ?? currentRecordingURL)
            currentRecordingURL = nil
        }

        do {
            guard let recordingURL else {
                throw AssistantVoiceCommandError.failedToStopRecording
            }

            let transcription = try await transcriptionClient.transcribe(audioURL: recordingURL)
            let command = transcription.text.trimmingCharacters(in: .whitespacesAndNewlines)

            if AssistantPayloadLogging.shouldLogPayloadDetails {
                AppLogger.debug(
                    "Assistant transcription payload",
                    category: .assistant,
                    extra: [
                        "rawLength": transcription.text.count,
                        "trimmedLength": command.count,
                        "preview": AssistantPayloadLogging.payloadPreview(command),
                    ]
                )
            }

            guard !command.isEmpty else {
                throw AssistantVoiceCommandError.emptyCommand
            }

            let executionFlow = currentExecutionFlow
            let selectedIntegration: AssistantIntegrationConfig?

            if executionFlow == .integrationDispatch {
                guard let integration = settings.assistantSelectedIntegration,
                      integration.isEnabled
                else {
                    throw AssistantVoiceCommandError.integrationDisabled
                }
                selectedIntegration = integration
            } else {
                selectedIntegration = nil
            }

            AppLogger.info(
                "Assistant command processed",
                category: .assistant,
                extra: [
                    "integration": selectedIntegration?.name ?? "assistantMode",
                    "executionFlow": executionFlow == .integrationDispatch ? "integrationDispatch" : "assistantMode",
                    "commandLength": command.count,
                ]
            )

            let selectedTextResult: (text: String, snapshot: AssistantTextSelectionService.PasteboardSnapshot)?
            let sourceText: String

            if executionFlow == .integrationDispatch {
                selectedTextResult = nil
                sourceText = command

                if AssistantPayloadLogging.shouldLogPayloadDetails {
                    AppLogger.debug(
                        "Assistant integration source payload",
                        category: .assistant,
                        extra: [
                            "length": sourceText.count,
                            "preview": AssistantPayloadLogging.payloadPreview(sourceText),
                        ]
                    )
                }
            } else {
                let selectedTextCapture = try await textSelectionService.captureSelectedText()
                selectedTextResult = selectedTextCapture
                sourceText = selectedTextCapture.text

                if AssistantPayloadLogging.shouldLogPayloadDetails {
                    AppLogger.debug(
                        "Assistant selected text payload",
                        category: .assistant,
                        extra: [
                            "length": sourceText.count,
                            "preview": AssistantPayloadLogging.payloadPreview(sourceText),
                        ]
                    )
                }
            }

            guard let beforeAICommand = try await applyScriptIfNeeded(
                stage: .beforeAI,
                input: command,
                integration: selectedIntegration
            ) else {
                indicator.hide()
                return
            }

            let integrationPrompt = PostProcessingPrompt(
                title: "assistant.raycast.prompt_title".localized,
                promptText: assistantPromptInstructions(
                    baseInstructions: normalizedPromptInstructions(from: selectedIntegration),
                    voiceCommand: beforeAICommand,
                    executionFlow: executionFlow
                )
            )

            let processedCommand = try await postProcessingService.processTranscription(
                sourceText,
                with: integrationPrompt,
                systemPromptOverride: executionFlow == .integrationDispatch
                    ? AIPromptTemplates.assistantSystemPrompt
                    : nil
            )

            if AssistantPayloadLogging.shouldLogPayloadDetails {
                AppLogger.debug(
                    "Assistant post-processing payload",
                    category: .assistant,
                    extra: [
                        "length": processedCommand.count,
                        "preview": AssistantPayloadLogging.payloadPreview(processedCommand),
                    ]
                )
            }

            guard let commandForDispatch = try await applyScriptIfNeeded(
                stage: .afterAI,
                input: processedCommand,
                integration: selectedIntegration
            ) else {
                indicator.hide()
                return
            }

            let processedCommandForDispatch: String
            if executionFlow == .integrationDispatch {
                processedCommandForDispatch = try requireNonEmptyCommand(
                    processedCommand,
                    fallback: nil
                )
            } else {
                processedCommandForDispatch = normalizedCommand(processedCommand, fallback: beforeAICommand)
            }

            let commandToDispatch = normalizedCommand(
                commandForDispatch,
                fallback: processedCommandForDispatch
            )
            let finalCommand = executionFlow == .integrationDispatch
                ? commandToDispatch
                : normalizedCommand(commandToDispatch, fallback: sourceText)

            if AssistantPayloadLogging.shouldLogPayloadDetails {
                AppLogger.debug(
                    "Assistant dispatch payload",
                    category: .assistant,
                    extra: [
                        "length": finalCommand.count,
                        "preview": AssistantPayloadLogging.payloadPreview(finalCommand),
                        "integrationId": selectedIntegration?.id.uuidString ?? "assistantMode",
                    ]
                )
            }

            if executionFlow == .integrationDispatch {
                guard let selectedIntegration else {
                    throw AssistantVoiceCommandError.integrationDisabled
                }

                let dispatchResult = try dispatchToRaycast(
                    with: finalCommand,
                    rawText: command,
                    selectedIntegration: selectedIntegration
                )
                AppLogger.info(
                    "Assistant integration dispatch completed",
                    category: .assistant,
                    extra: [
                        "integrationId": selectedIntegration.id.uuidString,
                        "integrationName": selectedIntegration.name,
                        "result": dispatchResult == .openedWithClipboardFallback ? "clipboardFallback" : "deepLink",
                        "processedLength": processedCommand.count,
                        "dispatchedLength": finalCommand.count,
                    ]
                )
            } else {
                guard let selectedTextResult else {
                    throw AssistantVoiceCommandError.noSelectionFound
                }
                try await textSelectionService.replaceSelectedText(
                    with: finalCommand,
                    restoring: selectedTextResult.snapshot
                )
                AppLogger.info(
                    "Assistant mode command applied to active app",
                    category: .assistant,
                    extra: [
                        "processedLength": processedCommand.count,
                        "appliedLength": finalCommand.count,
                    ]
                )
            }

            indicator.hide()
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
    }

    public func cancelRecording() async {
        guard isRecording else { return }

        _ = await audioRecorder.stopRecording()
        isRecording = false
        isProcessing = false
        currentExecutionFlow = .assistantMode
        await RecordingExclusivityCoordinator.shared.endAssistant()
        SoundFeedbackService.shared.playRecordingCancelledSound()
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

    private func dispatchToRaycast(
        with command: String,
        rawText: String,
        selectedIntegration: AssistantIntegrationConfig
    ) throws -> AssistantIntegrationDispatchResult {
        let resolvedDeepLink = resolveDeepLinkShortcodes(
            in: selectedIntegration.deepLink,
            finalText: command,
            rawText: rawText
        )

        if AssistantPayloadLogging.shouldLogPayloadDetails {
            AppLogger.debug(
                "Assistant dispatch target",
                category: .assistant,
                extra: [
                    "deepLink": selectedIntegration.deepLink,
                    "resolvedDeepLink": resolvedDeepLink,
                    "commandPreview": AssistantPayloadLogging.payloadPreview(command),
                ]
            )
        }

        do {
            return try raycastIntegrationService.dispatch(
                command: command,
                baseDeepLink: resolvedDeepLink
            )
        } catch AssistantIntegrationDispatchError.invalidDeepLink {
            throw AssistantVoiceCommandError.raycastDeeplinkInvalid
        } catch AssistantIntegrationDispatchError.openFailed {
            throw AssistantVoiceCommandError.raycastOpenFailed
        }
    }

    private func resolveDeepLinkShortcodes(
        in template: String,
        finalText: String,
        rawText: String
    ) -> String {
        let replacements: [(String, String)] = [
            (AssistantIntegrationDeepLinkShortcode.finalTextURLEncoded, urlEncoded(finalText)),
            (AssistantIntegrationDeepLinkShortcode.rawTextURLEncoded, urlEncoded(rawText)),
            (AssistantIntegrationDeepLinkShortcode.finalText, finalText),
            (AssistantIntegrationDeepLinkShortcode.rawText, rawText),
        ]

        return replacements.reduce(template) { partialResult, replacement in
            partialResult.replacingOccurrences(of: replacement.0, with: replacement.1)
        }
    }

    private func urlEncoded(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=+?#")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
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

        if AssistantPayloadLogging.shouldLogPayloadDetails {
            AppLogger.debug(
                "Assistant script stage output",
                category: .assistant,
                extra: [
                    "stage": stage.rawValue,
                    "inputLength": input.count,
                    "outputLength": output?.count ?? 0,
                    "outputPreview": AssistantPayloadLogging.payloadPreview(output ?? ""),
                ]
            )
        }

        if output == nil {
            AppLogger.info(
                "Assistant script returned empty output; skipping remaining processing",
                category: .assistant,
                extra: ["stage": stage.rawValue, "integration": integration.name]
            )
        }

        return output
    }

    private func normalizedPromptInstructions(from integration: AssistantIntegrationConfig?) -> String? {
        let normalized = integration?.promptInstructions?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let normalized, !normalized.isEmpty else {
            return nil
        }
        return normalized
    }

    private func normalizedCommand(_ command: String, fallback: String) -> String {
        let normalized = command.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalized.isEmpty {
            return normalized
        }

        return fallback.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func assistantPromptInstructions(
        baseInstructions: String?,
        voiceCommand: String,
        executionFlow: AssistantExecutionFlow
    ) -> String {
        let normalizedVoiceCommand = voiceCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        if executionFlow == .integrationDispatch {
            let immutableInstructions = """
            You are preparing text that will be sent to another AI assistant through a deep link.
            Rewrite or clean the command while preserving the user's intent and language.
            Never answer the command.
            Return only the final command text.
            """
            guard let baseInstructions,
                  !baseInstructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                return """
                \(immutableInstructions)

                User command:
                \(normalizedVoiceCommand)
                """
            }

            return """
            \(immutableInstructions)

            Additional user instructions:
            \(baseInstructions)

            User command:
            \(normalizedVoiceCommand)
            """
        }

        guard let baseInstructions,
              !baseInstructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return normalizedVoiceCommand
        }

        return """
        \(baseInstructions)

        Comando do usuário:
        \(normalizedVoiceCommand)
        """
    }

    private func requireNonEmptyCommand(_ command: String, fallback: String?) throws -> String {
        let normalized = command.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalized.isEmpty {
            return normalized
        }

        if let fallback {
            let normalizedFallback = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
            if !normalizedFallback.isEmpty {
                return normalizedFallback
            }
        }

        throw AssistantVoiceCommandError.processingFailed
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
