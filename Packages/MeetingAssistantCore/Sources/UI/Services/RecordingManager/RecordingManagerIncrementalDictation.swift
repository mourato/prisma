import AVFoundation
import Foundation
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreInfrastructure
import MeetingAssistantCoreDomain

extension RecordingManager {
    func shouldUseIncrementalDictationCapture(
        purpose: CapturePurpose,
        source: RecordingSource
    ) -> Bool {
        let config = IncrementalCaptureSupportConfig(
            expectedPurpose: .dictation,
            expectedSource: .microphone,
            incrementalFeatureEnabled: FeatureFlags.enableIncrementalDictationTranscription,
            realtimeFeatureEnabled: FeatureFlags.enableRealtimeVADForDictation,
            executionMode: .dictation
        )
        return supportsIncrementalCapture(config, actualPurpose: purpose, actualSource: source)
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

        warmupIncrementalTranscriptionIfNeeded()

        installIncrementalBufferForwarder(on: recorder) { buffer in
            await coordinator.append(buffer: buffer)
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

        let audioDuration = await beginIncrementalFinalizationUI(
            audioURL: audioURL,
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
        let transcription = try await finalizeIncrementalPreparedResponse(
            response: result.response,
            checkpointID: result.checkpointID,
            session: session,
            audioDuration: audioDuration
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
