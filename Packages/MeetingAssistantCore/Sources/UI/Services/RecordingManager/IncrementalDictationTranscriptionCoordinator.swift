@preconcurrency import AVFoundation
import Foundation
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

@MainActor
final class IncrementalDictationTranscriptionCoordinator {
    struct FinalizedResult: Sendable {
        let response: DomainTranscriptionResponse
        let checkpointID: UUID
    }

    struct Callbacks {
        let onPreviewTextChanged: @Sendable (String) -> Void
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
                onPreviewTextChanged: callbacks.onPreviewTextChanged,
                onProcessedDurationChanged: callbacks.onProcessedDurationChanged,
                fallbackLogMessage: "Dictation incremental transcription degraded; full-file fallback required"
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

    func finish() async throws -> FinalizedResult {
        try await core.finishAccumulation()
        let response = try await core.buildFinalizedResponse()

        return FinalizedResult(response: response, checkpointID: core.checkpointID)
    }

    func cancelAndDiscard() async {
        await core.cancelAndDiscard()
    }
}
