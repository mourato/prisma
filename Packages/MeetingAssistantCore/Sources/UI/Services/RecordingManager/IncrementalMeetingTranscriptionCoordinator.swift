@preconcurrency import AVFoundation
import Foundation
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

@MainActor
final class IncrementalMeetingTranscriptionCoordinator {
    struct FinalizedResult: Sendable {
        let response: DomainTranscriptionResponse
        let checkpointID: UUID
    }

    struct Callbacks {
        let onProcessedDurationChanged: @Sendable (Double) -> Void
    }

    private let core: IncrementalTranscriptionCoordinatorCore

    init(
        transcriptionID: UUID,
        meeting: Meeting,
        inputSource: String?,
        storage: any StorageService,
        transcriptionClient: any TranscriptionService,
        callbacks: Callbacks
    ) {
        core = IncrementalTranscriptionCoordinatorCore(
            configuration: .init(
                transcriptionID: transcriptionID,
                meeting: meeting,
                inputSource: inputSource,
                storage: storage,
                transcriptionClient: transcriptionClient,
                onPreviewTextChanged: nil,
                onProcessedDurationChanged: callbacks.onProcessedDurationChanged,
                fallbackLogMessage: "Meeting incremental transcription degraded; full-file fallback required"
            )
        )
    }

    var checkpointID: UUID {
        core.checkpointID
    }

    var requiresLegacyFallback: Bool {
        core.requiresLegacyFallback
    }

    var fallbackError: Error? {
        core.fallbackError
    }

    var fallbackReason: IncrementalTranscriptionFallbackReason? {
        core.fallbackReason
    }

    func start() async throws {
        try await core.start()
    }

    func append(buffer: AVAudioPCMBuffer) async {
        await core.append(buffer: buffer)
    }

    func finish(
        audioURL: URL,
        diarizationEnabled: Bool,
        finalDiarizationService: (any TranscriptionServiceFinalDiarization)?
    ) async throws -> FinalizedResult {
        try await core.finishAccumulation()

        var finalizedSegments = core.currentSegments
        if diarizationEnabled {
            guard let finalDiarizationService else {
                let error = TranscriptionError.transcriptionFailed("Final diarization unsupported in current backend")
                await core.markForLegacyFallback(error, reason: .finalDiarizationFailed)
                throw error
            }

            do {
                let speakerTimeline = try await finalDiarizationService.diarize(audioURL: audioURL)
                finalizedSegments = finalDiarizationService.assignSpeakers(
                    to: core.currentSegments,
                    using: speakerTimeline
                )
            } catch {
                await core.markForLegacyFallback(error, reason: .finalDiarizationFailed)
                throw error
            }
        }

        let response = try await core.buildFinalizedResponse(segmentsOverride: finalizedSegments)

        return FinalizedResult(response: response, checkpointID: core.checkpointID)
    }

    func cancelAndDiscard() async {
        await core.cancelAndDiscard()
    }
}
