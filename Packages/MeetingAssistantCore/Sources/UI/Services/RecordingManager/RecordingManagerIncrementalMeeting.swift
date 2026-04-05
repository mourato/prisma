import AVFoundation
import Foundation
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

extension RecordingManager {
    private final class SendableMeetingAudioBufferBox: @unchecked Sendable {
        let buffer: AVAudioPCMBuffer

        init(buffer: AVAudioPCMBuffer) {
            self.buffer = buffer
        }
    }

    func shouldUseIncrementalMeetingCapture(
        purpose: CapturePurpose,
        source: RecordingSource
    ) -> Bool {
        guard purpose == .meeting, source == .all else { return false }
        guard FeatureFlags.enableIncrementalMeetingTranscription else { return false }
        guard FeatureFlags.enableRealtimeVADForMeetings else { return false }
        guard let recorder = micRecorder as? AudioRecorder else { return false }
        guard recorder === AudioRecorder.shared else { return false }
        guard let transcriptionClient = transcriptionClient as? TranscriptionClient else { return false }
        guard transcriptionClient.supportsIncrementalTranscription else { return false }
        guard transcriptionClient is any TranscriptionServiceFinalDiarization else { return false }
        return true
    }

    func prepareIncrementalMeetingSessionIfNeeded(
        meeting: Meeting,
        purpose: CapturePurpose,
        source: RecordingSource
    ) async throws {
        guard shouldUseIncrementalMeetingCapture(purpose: purpose, source: source) else {
            teardownIncrementalMeetingSession()
            return
        }

        guard let recorder = micRecorder as? AudioRecorder else { return }

        let coordinator = IncrementalMeetingTranscriptionCoordinator(
            transcriptionID: meeting.id,
            meeting: meeting,
            inputSource: resolveInputSourceLabel(for: meeting, recordingSource: source),
            storage: storage,
            transcriptionClient: transcriptionClient,
            callbacks: .init(
                onProcessedDurationChanged: { [weak self] processedDuration in
                    Task { @MainActor [weak self] in
                        self?.transcriptionStatus.updateProgress(
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

        recorder.onMixedAudioBuffer = { [weak self] buffer in
            let bufferBox = SendableMeetingAudioBufferBox(buffer: buffer)
            Task { @MainActor [weak self] in
                guard let self else { return }
                await coordinator.append(buffer: bufferBox.buffer)
                if coordinator.requiresLegacyFallback {
                    AppLogger.warning(
                        "Meeting incremental transcription degraded; will fallback to legacy full-file transcription on stop",
                        category: .recordingManager,
                        extra: [
                            "error": coordinator.fallbackError?.localizedDescription ?? "unknown",
                        ]
                    )
                }
            }
        }

        do {
            try await coordinator.start()
            incrementalMeetingCoordinator = coordinator
        } catch {
            recorder.onMixedAudioBuffer = nil
            incrementalMeetingCoordinator = nil
            throw error
        }
    }

    func finishIncrementalMeetingSession(
        audioURL: URL,
        session: TranscriptionSessionSnapshot
    ) async throws -> Transcription {
        guard let incrementalMeetingCoordinator else {
            throw TranscriptionError.transcriptionFailed("Missing incremental meeting session")
        }

        let diarizationEnabled = shouldEnableDiarization(
            for: session.meeting,
            capturePurposeOverride: session.meeting.capturePurpose
        )
        let finalDiarizationService = transcriptionClient as? any TranscriptionServiceFinalDiarization

        let audioDuration = await getAudioDuration(from: audioURL)
        beginVisibleTranscriptionStatus(audioDuration: audioDuration, sessionID: session.id)
        updateVisibleTranscriptionProgress(
            phase: .processing,
            percentage: Constants.processingProgress,
            sessionID: session.id
        )

        let result = try await incrementalMeetingCoordinator.finish(
            audioURL: audioURL,
            diarizationEnabled: diarizationEnabled,
            finalDiarizationService: finalDiarizationService
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
        teardownIncrementalMeetingSession()
        return transcription
    }

    func teardownIncrementalMeetingSession() {
        if let recorder = micRecorder as? AudioRecorder {
            recorder.onMixedAudioBuffer = nil
        }
        incrementalMeetingCoordinator = nil
    }

    func cancelIncrementalMeetingSessionIfNeeded() async {
        if let incrementalMeetingCoordinator {
            await incrementalMeetingCoordinator.cancelAndDiscard()
        }
        teardownIncrementalMeetingSession()
    }

    func cancelIncrementalTranscriptionSessionsIfNeeded() async {
        await cancelIncrementalDictationSessionIfNeeded()
        await cancelIncrementalMeetingSessionIfNeeded()
    }
}
