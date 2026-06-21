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

    private let audioRecorder: any AssistantRecordingService
    private let transcriptionPhase: AssistantTranscriptionPhase
    private let aiPhase: AssistantAIPhase
    private let recordingManager: RecordingManager
    private let indicator: FloatingRecordingIndicatorController
    private let screenBorder: AssistantScreenBorderController
    private let settings: AppSettingsStore
    private let normalizationPhase: AssistantNormalizationPhase
    private let dispatchPhase: AssistantDispatchPhase

    private var currentRecordingURL: URL?
    private var currentExecutionFlow: AssistantExecutionFlow = .assistantMode

    public init(
        audioRecorder: any AssistantRecordingService = AudioRecorder.shared,
        transcriptionClient: TranscriptionClient = .shared,
        postProcessingService: PostProcessingService = .shared,
        recordingManager: RecordingManager = .shared,
        indicator: FloatingRecordingIndicatorController = FloatingRecordingIndicatorController(),
        screenBorder: AssistantScreenBorderController = AssistantScreenBorderController(),
        settings: AppSettingsStore = .shared,
        normalizationPhase: AssistantNormalizationPhase = AssistantNormalizationPhase(),
        transcriptionPhase: AssistantTranscriptionPhase? = nil,
        aiPhase: AssistantAIPhase? = nil,
        dispatchPhase: AssistantDispatchPhase? = nil,
        raycastIntegrationService: any AssistantDeepLinkDispatching = AssistantRaycastIntegrationService(),
        scriptRunner: AssistantBashScriptRunner = AssistantBashScriptRunner(),
        textSelectionService: AssistantTextSelectionService = AssistantTextSelectionService()
    ) {
        self.audioRecorder = audioRecorder
        self.transcriptionPhase = transcriptionPhase ?? AssistantTranscriptionPhase(transcriptionClient: transcriptionClient)
        self.aiPhase = aiPhase ?? AssistantAIPhase(
            postProcessingService: postProcessingService,
            scriptRunner: scriptRunner
        )
        self.recordingManager = recordingManager
        self.indicator = indicator
        self.screenBorder = screenBorder
        self.settings = settings
        self.normalizationPhase = normalizationPhase
        self.dispatchPhase = dispatchPhase ?? AssistantDispatchPhase(
            raycastIntegrationService: raycastIntegrationService,
            textSelectionService: textSelectionService,
            normalizationPhase: normalizationPhase
        )
    }

    public func startRecording(flow: AssistantExecutionFlow = .assistantMode) async {
        guard !isRecording, !isProcessing else { return }
        let requestedAt = Date()

        if flow == .integrationDispatch, !settings.isAssistantIntegrationsEnabled {
            showError(.integrationDisabled)
            return
        }

        guard !recordingManager.isRecording, !recordingManager.isStartingRecording else {
            AppLogger.info(
                "Assistant start blocked because RecordingManager capture is active",
                category: .assistant
            )
            showError(.recordingInProgress)
            return
        }

        guard await RecordingExclusivityCoordinator.shared.beginAssistant() else {
            AppLogger.info("Assistant recording start blocked by exclusivity coordinator", category: .assistant)
            showError(.recordingInProgress)
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

        recordingManager.refreshPostProcessingReadinessWarning(for: .assistant, settings: settings)

        do {
            let outputURL = makeTemporaryRecordingURL()
            currentRecordingURL = outputURL
            currentExecutionFlow = flow

            try await audioRecorder.startRecording(to: outputURL, source: .microphone)
            isRecording = true
            indicator.show(
                renderState: recordingIndicatorRenderState(mode: .recording),
                onStop: { [weak self] in
                    Task { @MainActor [weak self] in
                        await self?.stopAndProcess()
                    }
                },
                onCancel: { [weak self] in
                    Task { @MainActor [weak self] in
                        await self?.cancelRecording()
                    }
                }
            )
            screenBorder.show()
            let now = Date()
            PerformanceMonitor.shared.reportMetric(
                name: "assistant_start_requested_to_recorder_ms",
                value: now.timeIntervalSince(requestedAt) * 1_000,
                unit: "ms"
            )
        } catch {
            recordingManager.clearPostProcessingReadinessWarning()
            await RecordingExclusivityCoordinator.shared.endAssistant()
            showError(.failedToStartRecording)
        }
    }

    public func stopAndProcess() async {
        guard isRecording, !isProcessing else { return }

        recordingManager.refreshPostProcessingReadinessWarning(for: .assistant, settings: settings)
        isProcessing = true
        indicator.updateProcessingSnapshot(.init(step: .transcribingCommand))
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
            recordingManager.clearPostProcessingReadinessWarning()
        }

        do {
            let (command, executionFlow, selectedIntegration) = try await performTranscription(recordingURL: recordingURL)
            let (sourceText, selectedTextResult) = try await captureSourceText(executionFlow: executionFlow, command: command)
            let processedCommand = try await processWithAI(
                sourceText: sourceText,
                command: command,
                executionFlow: executionFlow,
                selectedIntegration: selectedIntegration
            )
            let finalCommand = normalizationPhase.applyNormalization(
                processedCommand: processedCommand,
                command: command,
                executionFlow: executionFlow,
                sourceText: sourceText
            )
            try await executeDispatch(
                executionFlow: executionFlow,
                finalCommand: finalCommand,
                command: command,
                processedCommand: processedCommand,
                selectedIntegration: selectedIntegration,
                selectedTextResult: selectedTextResult
            )
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

    // MARK: - Phase Helpers

    private func performTranscription(recordingURL: URL?) async throws -> (
        command: String,
        executionFlow: AssistantExecutionFlow,
        selectedIntegration: AssistantIntegrationConfig?
    ) {
        indicator.updateProcessingSnapshot(.init(step: .transcribingCommand))
        guard let recordingURL else {
            throw AssistantVoiceCommandError.failedToStopRecording
        }

        return try await transcriptionPhase.performTranscription(
            recordingURL: recordingURL,
            vocabularyReplacementRules: settings.vocabularyReplacementRules,
            executionFlow: currentExecutionFlow,
            isAssistantIntegrationsEnabled: settings.isAssistantIntegrationsEnabled,
            assistantSelectedIntegration: settings.assistantSelectedIntegration
        )
    }

    private func captureSourceText(
        executionFlow: AssistantExecutionFlow,
        command: String
    ) async throws -> (
        sourceText: String,
        selectedTextResult: (text: String, snapshot: AssistantTextSelectionService.PasteboardSnapshot)?
    ) {
        indicator.updateProcessingSnapshot(.init(step: .capturingContext))
        return try await dispatchPhase.captureSourceText(
            executionFlow: executionFlow,
            command: command
        )
    }

    private func processWithAI(
        sourceText: String,
        command: String,
        executionFlow: AssistantExecutionFlow,
        selectedIntegration: AssistantIntegrationConfig?
    ) async throws -> String {
        indicator.updateProcessingSnapshot(.init(step: .interpretingCommand))
        return try await aiPhase.processWithAI(
            sourceText: sourceText,
            command: command,
            executionFlow: executionFlow,
            selectedIntegration: selectedIntegration
        )
    }

    private func applyNormalization(
        processedCommand: String,
        command: String,
        executionFlow: AssistantExecutionFlow,
        sourceText: String
    ) -> String {
        normalizationPhase.applyNormalization(
            processedCommand: processedCommand,
            command: command,
            executionFlow: executionFlow,
            sourceText: sourceText
        )
    }

    private func executeDispatch(
        executionFlow: AssistantExecutionFlow,
        finalCommand: String,
        command: String,
        processedCommand: String,
        selectedIntegration: AssistantIntegrationConfig?,
        selectedTextResult: (text: String, snapshot: AssistantTextSelectionService.PasteboardSnapshot)?
    ) async throws {
        indicator.updateProcessingSnapshot(.init(step: .dispatchingResult))
        try await dispatchPhase.executeDispatch(
            executionFlow: executionFlow,
            finalCommand: finalCommand,
            command: command,
            processedCommand: processedCommand,
            selectedIntegration: selectedIntegration,
            selectedTextResult: selectedTextResult
        )
    }

    private func logPayloadIfNeeded(_ message: String, _ extras: [String: Any]) {
        guard AssistantPayloadLogging.shouldLogPayloadDetails else { return }
        AppLogger.debug(message, category: .assistant, extra: extras)
    }

    public func cancelRecording() async {
        guard isRecording || audioRecorder.isRecording else { return }

        _ = await audioRecorder.stopRecording()
        isRecording = false
        isProcessing = false
        currentExecutionFlow = .assistantMode
        await RecordingExclusivityCoordinator.shared.endAssistant()
        SoundFeedbackService.shared.playRecordingCancelledSound()
        recordingManager.clearPostProcessingReadinessWarning()
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

    private func recordingIndicatorRenderState(mode: FloatingRecordingIndicatorMode) -> RecordingIndicatorRenderState {
        switch currentExecutionFlow {
        case .assistantMode:
            RecordingIndicatorRenderState(mode: mode, kind: .assistant)
        case .integrationDispatch:
            RecordingIndicatorRenderState(
                mode: mode,
                kind: .assistantIntegration,
                assistantIntegrationID: settings.assistantSelectedIntegrationId
            )
        }
    }

    private func showError(_ error: AssistantVoiceCommandError) {
        indicator.showError(error.localizedDescription)
    }

}
