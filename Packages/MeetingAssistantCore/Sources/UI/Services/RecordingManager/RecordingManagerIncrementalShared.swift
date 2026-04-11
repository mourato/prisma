import AVFoundation
import Foundation
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

extension RecordingManager {
    struct IncrementalCaptureSupportConfig {
        let expectedPurpose: CapturePurpose
        let expectedSource: RecordingSource
        let incrementalFeatureEnabled: Bool
        let realtimeFeatureEnabled: Bool
        let executionMode: TranscriptionExecutionMode
    }

    private final class SendableIncrementalAudioBufferBox: @unchecked Sendable {
        let buffer: AVAudioPCMBuffer

        init(buffer: AVAudioPCMBuffer) {
            self.buffer = buffer
        }
    }

    func supportsIncrementalCapture(
        _ config: IncrementalCaptureSupportConfig,
        actualPurpose: CapturePurpose,
        actualSource: RecordingSource
    ) -> Bool {
        guard actualPurpose == config.expectedPurpose, actualSource == config.expectedSource else { return false }
        guard config.incrementalFeatureEnabled else { return false }
        guard config.realtimeFeatureEnabled else { return false }
        guard let recorder = micRecorder as? AudioRecorder else { return false }
        guard recorder === AudioRecorder.shared else { return false }
        guard let transcriptionClient = transcriptionClient as? TranscriptionClient else { return false }
        return transcriptionClient.supportsIncrementalTranscription(for: config.executionMode)
    }

    func warmupIncrementalTranscriptionIfNeeded() {
        guard let transcriptionClient = transcriptionClient as? TranscriptionClient else { return }
        transcriptionClient.warmupModelIfNeededInBackground()
    }

    func installIncrementalBufferForwarder(
        on recorder: AudioRecorder,
        handler: @escaping @MainActor (AVAudioPCMBuffer) async -> Void
    ) {
        recorder.onMixedAudioBuffer = { buffer in
            let bufferBox = SendableIncrementalAudioBufferBox(buffer: buffer)
            Task { @MainActor in
                await handler(bufferBox.buffer)
            }
        }
    }

    func beginIncrementalFinalizationUI(
        audioURL: URL,
        sessionID: UUID
    ) async -> Double? {
        let audioDuration = await getAudioDuration(from: audioURL)
        beginVisibleTranscriptionStatus(audioDuration: audioDuration, sessionID: sessionID)
        updateVisibleTranscriptionProgress(
            phase: .processing,
            percentage: Constants.processingProgress,
            sessionID: sessionID
        )
        return audioDuration
    }

    func finalizeIncrementalPreparedResponse(
        response: DomainTranscriptionResponse,
        checkpointID: UUID,
        session: TranscriptionSessionSnapshot,
        audioDuration: Double?
    ) async throws -> Transcription {
        let settings = AppSettingsStore.shared
        let meetingEntity = makeMeetingEntity(meeting: session.meeting, audioDuration: audioDuration)
        let config = makeUseCaseConfig(session: session, settings: settings)

        if shouldDriveSharedTranscriptionState(for: session.id) {
            meetingState = .processing(.generatingOutput)
        }

        let transcriptionEntity = try await transcribeAudioUseCase.finalizePreparedResponse(
            response: response,
            transcriptionID: checkpointID,
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
            transcriptionDuration: audioDuration ?? response.durationSeconds,
            onPhaseChange: { [weak self] phase in
                Task { @MainActor [weak self] in
                    self?.handleUseCasePhaseChange(phase, meeting: session.meeting, sessionID: session.id)
                }
            }
        )

        return convertToModel(
            transcriptionEntity,
            audioDuration: audioDuration,
            transcriptionStart: session.meeting.startTime
        )
    }
}
