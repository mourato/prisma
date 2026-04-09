@preconcurrency import AVFoundation
import Foundation
import MeetingAssistantCoreAudio
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

    private let transcriptionID: UUID
    private let meeting: Meeting
    private let inputSource: String?
    private let storage: any StorageService
    private let transcriptionClient: any TranscriptionService
    private let assembler = RealtimeVoiceActivityWindowAssembler()
    private let callbacks: Callbacks
    private let createdAt: Date

    private var accumulatedRawText = ""
    private var accumulatedSegments: [Transcription.Segment] = []
    private var language = "auto"
    private var modelName = "parakeet-tdt-0.6b-v3-coreml"
    private var processedDurationSeconds: Double = 0
    private var confidenceScores: [Double] = []
    private var hasPersistedCheckpoint = false
    private(set) var requiresLegacyFallback = false
    private(set) var fallbackError: Error?

    init(
        transcriptionID: UUID,
        meeting: Meeting,
        inputSource: String?,
        storage: any StorageService,
        transcriptionClient: any TranscriptionService,
        callbacks: Callbacks
    ) {
        self.transcriptionID = transcriptionID
        self.meeting = meeting
        self.inputSource = inputSource
        self.storage = storage
        self.transcriptionClient = transcriptionClient
        self.callbacks = callbacks
        createdAt = Date()
    }

    var checkpointID: UUID {
        transcriptionID
    }

    func start() async throws {
        try await persistCheckpoint(lifecycleState: .partial)
    }

    func append(buffer: AVAudioPCMBuffer) async {
        guard !requiresLegacyFallback else { return }

        do {
            let windows = try await assembler.append(buffer: buffer)
            for window in windows {
                try await transcribe(window: window)
            }
        } catch {
            await markForLegacyFallback(error)
        }
    }

    func finish(
        audioURL: URL,
        diarizationEnabled: Bool,
        finalDiarizationService: (any TranscriptionServiceFinalDiarization)?
    ) async throws -> FinalizedResult {
        if let fallbackError {
            throw fallbackError
        }

        do {
            let windows = try await assembler.finish()
            for window in windows {
                try await transcribe(window: window)
            }
        } catch {
            await markForLegacyFallback(error)
            throw error
        }

        if let fallbackError {
            throw fallbackError
        }

        guard hasAccumulatedTranscriptionContent else {
            let error = TranscriptionError.transcriptionFailed(
                PostProcessingError.emptyTranscription.localizedDescription
            )
            await markForLegacyFallback(error)
            throw error
        }

        var finalizedSegments = accumulatedSegments
        if diarizationEnabled {
            guard let finalDiarizationService else {
                let error = TranscriptionError.transcriptionFailed("Final diarization unsupported in current backend")
                await markForLegacyFallback(error)
                throw error
            }

            do {
                let speakerTimeline = try await finalDiarizationService.diarize(audioURL: audioURL)
                finalizedSegments = finalDiarizationService.assignSpeakers(
                    to: accumulatedSegments,
                    using: speakerTimeline
                )
            } catch {
                await markForLegacyFallback(error)
                throw error
            }
        }

        accumulatedSegments = finalizedSegments
        try await persistCheckpoint(lifecycleState: .finalizing)

        let response = DomainTranscriptionResponse(
            text: accumulatedRawText,
            segments: finalizedSegments.map { segment in
                DomainTranscriptionSegment(
                    id: segment.id,
                    speaker: segment.speaker,
                    text: segment.text,
                    startTime: segment.startTime,
                    endTime: segment.endTime
                )
            },
            language: language,
            durationSeconds: processedDurationSeconds,
            model: modelName,
            processedAt: ISO8601DateFormatter().string(from: Date()),
            confidenceScore: mergedConfidenceScore
        )

        return FinalizedResult(response: response, checkpointID: transcriptionID)
    }

    func cancelAndDiscard() async {
        fallbackError = CancellationError()
        requiresLegacyFallback = true
        if hasPersistedCheckpoint {
            try? await storage.deleteTranscription(by: transcriptionID)
        }
    }

    private func transcribe(window: RealtimeVoiceActivityWindowAssembler.Window) async throws {
        guard !window.samples.isEmpty else { return }

        do {
            let response = try await transcriptionClient.transcribe(samples: window.samples)
            append(
                response: response,
                absoluteWindowStartTime: window.startTime,
                absoluteWindowEndTime: window.endTime
            )
            try await persistCheckpoint(lifecycleState: .partial)
        } catch {
            throw error
        }
    }

    private func append(
        response: TranscriptionResponse,
        absoluteWindowStartTime: Double,
        absoluteWindowEndTime: Double
    ) {
        let trimmedText = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedText.isEmpty {
            if accumulatedRawText.isEmpty {
                accumulatedRawText = trimmedText
            } else {
                accumulatedRawText += " \(trimmedText)"
            }
        }

        let mappedSegments = if response.segments.isEmpty, !trimmedText.isEmpty {
            [
                Transcription.Segment(
                    speaker: Transcription.unknownSpeaker,
                    text: trimmedText,
                    startTime: absoluteWindowStartTime,
                    endTime: absoluteWindowEndTime
                ),
            ]
        } else {
            response.segments.map { segment in
                Transcription.Segment(
                    id: segment.id,
                    speaker: segment.speaker,
                    text: segment.text,
                    startTime: absoluteWindowStartTime + segment.startTime,
                    endTime: absoluteWindowStartTime + segment.endTime
                )
            }
        }

        accumulatedSegments.append(contentsOf: mappedSegments)
        language = response.language
        modelName = response.model
        processedDurationSeconds = max(processedDurationSeconds, absoluteWindowEndTime)
        if let confidence = response.confidenceScore {
            confidenceScores.append(confidence)
        }

        callbacks.onProcessedDurationChanged(processedDurationSeconds)
    }

    private func persistCheckpoint(lifecycleState: TranscriptionLifecycleState) async throws {
        let checkpoint = Transcription(
            id: transcriptionID,
            meeting: meeting,
            contextItems: [],
            segments: accumulatedSegments,
            text: accumulatedRawText,
            rawText: accumulatedRawText,
            processedContent: nil,
            canonicalSummary: nil,
            qualityProfile: nil,
            postProcessingPromptId: nil,
            postProcessingPromptTitle: nil,
            language: language,
            createdAt: createdAt,
            modelName: modelName,
            inputSource: inputSource,
            transcriptionDuration: processedDurationSeconds,
            postProcessingDuration: 0,
            postProcessingModel: nil,
            meetingType: nil,
            lifecycleState: lifecycleState,
            meetingConversationState: nil
        )
        try await storage.saveTranscription(checkpoint)
        hasPersistedCheckpoint = true
    }

    private func markForLegacyFallback(_ error: Error) async {
        guard !requiresLegacyFallback else { return }
        requiresLegacyFallback = true
        fallbackError = error
        try? await persistCheckpoint(lifecycleState: .failed)
    }

    private var mergedConfidenceScore: Double? {
        guard !confidenceScores.isEmpty else { return nil }
        return confidenceScores.reduce(0, +) / Double(confidenceScores.count)
    }

    private var hasAccumulatedTranscriptionContent: Bool {
        if !accumulatedRawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }

        return accumulatedSegments.contains {
            !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}
