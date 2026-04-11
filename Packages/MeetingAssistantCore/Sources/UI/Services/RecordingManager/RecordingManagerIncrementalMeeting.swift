import AVFoundation
import Foundation
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

extension RecordingManager {
    func shouldUseIncrementalMeetingCapture(
        purpose: CapturePurpose,
        source: RecordingSource
    ) -> Bool {
        guard transcriptionClient is any TranscriptionServiceFinalDiarization else { return false }
        let config = IncrementalCaptureSupportConfig(
            expectedPurpose: .meeting,
            expectedSource: .all,
            incrementalFeatureEnabled: FeatureFlags.enableIncrementalMeetingTranscription,
            realtimeFeatureEnabled: FeatureFlags.enableRealtimeVADForMeetings,
            executionMode: .meeting
        )
        return supportsIncrementalCapture(config, actualPurpose: purpose, actualSource: source)
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

        warmupIncrementalTranscriptionIfNeeded()

        installIncrementalBufferForwarder(on: recorder) { buffer in
            await coordinator.append(buffer: buffer)
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

        let audioDuration = await beginIncrementalFinalizationUI(
            audioURL: audioURL,
            sessionID: session.id
        )

        let result = try await incrementalMeetingCoordinator.finish(
            audioURL: audioURL,
            diarizationEnabled: diarizationEnabled,
            finalDiarizationService: finalDiarizationService
        )
        AppLogger.info(
            "Selected transcription pipeline",
            category: .recordingManager,
            extra: [
                "path": "incremental-final",
                "sessionID": session.id.uuidString,
                "capturePurpose": session.meeting.capturePurpose.rawValue,
            ]
        )
        let transcription = try await finalizeIncrementalPreparedResponse(
            response: result.response,
            checkpointID: result.checkpointID,
            session: session,
            audioDuration: audioDuration
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
