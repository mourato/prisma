import Foundation

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

    private var currentRecordingURL: URL?

    public init(
        audioRecorder: AudioRecorder = .shared,
        transcriptionClient: TranscriptionClient = .shared,
        postProcessingService: PostProcessingService = .shared,
        recordingManager: RecordingManager = .shared,
        indicator: FloatingRecordingIndicatorController = FloatingRecordingIndicatorController(),
        selectionService: AssistantTextSelectionService = AssistantTextSelectionService()
    ) {
        self.audioRecorder = audioRecorder
        self.transcriptionClient = transcriptionClient
        self.postProcessingService = postProcessingService
        self.recordingManager = recordingManager
        self.indicator = indicator
        self.selectionService = selectionService
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

            let (selectedText, snapshot) = try await selectionService.captureSelectedText()
            let transcription = try await transcriptionClient.transcribe(audioURL: recordingURL)
            let command = transcription.text.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !command.isEmpty else {
                throw AssistantVoiceCommandError.emptyCommand
            }

            let prompt = PostProcessingPrompt(
                title: "Assistant Command",
                promptText: command
            )

            let processed = try await postProcessingService.processTranscription(
                selectedText,
                with: prompt,
                systemPromptOverride: AIPromptTemplates.assistantSystemPrompt
            )

            try await selectionService.replaceSelectedText(
                with: processed,
                restoring: snapshot
            )

            indicator.hide()
        } catch let error as AssistantVoiceCommandError {
            showError(error)
        } catch let error as PostProcessingError {
            indicator.showError(error.localizedDescription)
        } catch {
            showError(.processingFailed)
        }

        isProcessing = false
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

    public var errorDescription: String? {
        switch self {
        case .microphonePermissionRequired:
            NSLocalizedString("assistant.error.microphone_permission", bundle: .safeModule, comment: "")
        case .accessibilityPermissionRequired:
            NSLocalizedString("assistant.error.accessibility_permission", bundle: .safeModule, comment: "")
        case .noSelectionFound:
            NSLocalizedString("assistant.error.no_selection", bundle: .safeModule, comment: "")
        case .emptyCommand:
            NSLocalizedString("assistant.error.empty_command", bundle: .safeModule, comment: "")
        case .failedToStartRecording:
            NSLocalizedString("assistant.error.start_failed", bundle: .safeModule, comment: "")
        case .failedToStopRecording:
            NSLocalizedString("assistant.error.stop_failed", bundle: .safeModule, comment: "")
        case .recordingInProgress:
            NSLocalizedString("assistant.error.recording_in_progress", bundle: .safeModule, comment: "")
        case .processingFailed:
            NSLocalizedString("assistant.error.processing_failed", bundle: .safeModule, comment: "")
        }
    }
}
