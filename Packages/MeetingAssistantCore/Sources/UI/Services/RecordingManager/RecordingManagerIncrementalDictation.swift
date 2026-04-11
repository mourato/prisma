import AVFoundation
import Foundation
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreInfrastructure
import MeetingAssistantCoreDomain

extension RecordingManager {
    private final class SendableAudioBufferBox: @unchecked Sendable {
        let buffer: AVAudioPCMBuffer

        init(buffer: AVAudioPCMBuffer) {
            self.buffer = buffer
        }
    }

    func shouldUseIncrementalDictationCapture(
        purpose: CapturePurpose,
        source: RecordingSource
    ) -> Bool {
        guard purpose == .dictation, source == .microphone else { return false }
        guard FeatureFlags.enableIncrementalDictationTranscription else { return false }
        guard FeatureFlags.enableRealtimeVADForDictation else { return false }
        guard let recorder = micRecorder as? AudioRecorder else { return false }
        guard recorder === AudioRecorder.shared else { return false }
        guard let transcriptionClient = transcriptionClient as? TranscriptionClient else { return false }
        return transcriptionClient.supportsIncrementalTranscription(for: .dictation)
    }

    func prepareIncrementalDictationSessionIfNeeded(
        meeting: Meeting,
        purpose: CapturePurpose,
        source: RecordingSource
    ) async throws {
        guard shouldUseIncrementalDictationCapture(purpose: purpose, source: source) else {
            teardownIncrementalDictationSession()
            return
        }

        guard let recorder = micRecorder as? AudioRecorder else { return }

        let coordinator = IncrementalDictationTranscriptionCoordinator(
            transcriptionID: meeting.id,
            meeting: meeting,
            inputSource: resolveInputSourceLabel(for: meeting, recordingSource: source),
            storage: storage,
            transcriptionClient: transcriptionClient,
            callbacks: IncrementalDictationTranscriptionCoordinator.Callbacks(
                onPreviewTextChanged: { [weak self] previewText in
                    Task { @MainActor [weak self] in
                        self?.transcriptionStatus.updateLivePreviewText(previewText)
                    }
                },
                onProcessedDurationChanged: { [weak self] (processedDuration: Double) in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        self.transcriptionStatus.updateProgress(
                            phase: .processing,
                            processedSeconds: processedDuration
                        )
                    }
                }
            )
        )

        if let transcriptionClient = transcriptionClient as? TranscriptionClient {
            transcriptionClient.warmupModelIfNeededInBackground()
        }

        recorder.onMixedAudioBuffer = { buffer in
            let bufferBox = SendableAudioBufferBox(buffer: buffer)
            Task { @MainActor in
                await coordinator.append(buffer: bufferBox.buffer)
            }
        }

        do {
            try await coordinator.start()
            incrementalDictationCoordinator = coordinator
        } catch {
            recorder.onMixedAudioBuffer = nil
            incrementalDictationCoordinator = nil
            throw error
        }
    }

    func finishIncrementalDictationSession(
        audioURL: URL,
        session: TranscriptionSessionSnapshot
    ) async throws -> Transcription {
        guard let incrementalDictationCoordinator else {
            throw TranscriptionError.transcriptionFailed("Missing incremental dictation session")
        }

        let audioDuration = await getAudioDuration(from: audioURL)
        beginVisibleTranscriptionStatus(audioDuration: audioDuration, sessionID: session.id)
        updateVisibleTranscriptionProgress(
            phase: .processing,
            percentage: Constants.processingProgress,
            sessionID: session.id
        )

        let result = try await incrementalDictationCoordinator.finish()
        AppLogger.info(
            "Selected transcription pipeline",
            category: .recordingManager,
            extra: [
                "path": "incremental-final",
                "sessionID": session.id.uuidString,
                "capturePurpose": session.meeting.capturePurpose.rawValue,
            ]
        )
        let settings = AppSettingsStore.shared
        let meetingEntity = makeMeetingEntity(meeting: session.meeting, audioDuration: audioDuration)
        let config = makeUseCaseConfig(session: session, settings: settings)

        if shouldDriveSharedTranscriptionState(for: session.id) {
            meetingState = .processing(.generatingOutput)
        }

        let transcriptionEntity = try await transcribeAudioUseCase.finalizePreparedResponse(
            response: result.response,
            transcriptionID: result.checkpointID,
            meeting: meetingEntity,
            inputSource: resolveInputSourceLabel(for: session.meeting, recordingSource: session.recordingSource),
            contextItems: config.postProcessingContextItems,
            vocabularyReplacementRules: settings.vocabularyReplacementRules,
            applyPostProcessing: config.applyPostProcessing,
            postProcessingPrompt: config.postProcessingPrompt,
            defaultPostProcessingPrompt: config.defaultPostProcessingPrompt,
            postProcessingModel: config.postProcessingModel,
            autoDetectMeetingType: config.autoDetectMeetingType,
            availablePrompts: config.availablePrompts,
            postProcessingContext: config.postProcessingContext,
            kernelMode: config.kernelMode,
            dictationStructuredPostProcessingEnabled: config.dictationStructuredPostProcessingEnabled,
            transcriptionDuration: audioDuration ?? result.response.durationSeconds,
            onPhaseChange: { [weak self] phase in
                Task { @MainActor [weak self] in
                    self?.handleUseCasePhaseChange(phase, meeting: session.meeting, sessionID: session.id)
                }
            }
        )

        let transcription = convertToModel(
            transcriptionEntity,
            audioDuration: audioDuration,
            transcriptionStart: session.meeting.startTime
        )
        teardownIncrementalDictationSession()
        return transcription
    }

    func teardownIncrementalDictationSession() {
        if let recorder = micRecorder as? AudioRecorder {
            recorder.onMixedAudioBuffer = nil
        }
        incrementalDictationCoordinator = nil
        transcriptionStatus.updateLivePreviewText("")
    }

    func cancelIncrementalDictationSessionIfNeeded() async {
        if let incrementalDictationCoordinator {
            await incrementalDictationCoordinator.cancelAndDiscard()
        }
        teardownIncrementalDictationSession()
    }
}
