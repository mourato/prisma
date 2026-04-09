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
    private(set) var fallbackReason: IncrementalTranscriptionFallbackReason?

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
            if !requiresLegacyFallback {
                await markForLegacyFallback(error, reason: .assemblerFailed)
            }
        }
    }

    func finish() async throws -> FinalizedResult {
        if let fallbackError {
            throw fallbackError
        }

        do {
            let windows = try await assembler.finish()
            for window in windows {
                try await transcribe(window: window)
            }
        } catch {
            if !requiresLegacyFallback {
                await markForLegacyFallback(error, reason: .assemblerFailed)
            }
            throw error
        }

        if let fallbackError {
            throw fallbackError
        }
        try await ensureAccumulatedTranscriptionContent()
        try await persistCheckpoint(lifecycleState: .finalizing)

        let response = DomainTranscriptionResponse(
            text: accumulatedRawText,
            segments: accumulatedSegments.map { segment in
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
            append(response: response, absoluteWindowStartTime: window.startTime, absoluteWindowEndTime: window.endTime)
            try await persistCheckpoint(lifecycleState: .partial)
        } catch {
            await markForLegacyFallback(error, reason: .windowTranscriptionFailed)
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

        callbacks.onPreviewTextChanged(accumulatedRawText)
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

    private var mergedConfidenceScore: Double? {
        guard !confidenceScores.isEmpty else { return nil }
        return confidenceScores.reduce(0, +) / Double(confidenceScores.count)
    }

    private func ensureAccumulatedTranscriptionContent() async throws {
        if !accumulatedRawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return
        }

        let hasSegmentText = accumulatedSegments.contains {
            !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard !hasSegmentText else { return }

        let error = TranscriptionError.transcriptionFailed(
            PostProcessingError.emptyTranscription.localizedDescription
        )
        await markForLegacyFallback(error, reason: .emptyTranscript)
        throw error
    }

    private func markForLegacyFallback(
        _ error: Error,
        reason: IncrementalTranscriptionFallbackReason
    ) async {
        guard !requiresLegacyFallback else { return }
        requiresLegacyFallback = true
        fallbackError = error
        fallbackReason = reason
        AppLogger.warning(
            "Dictation incremental transcription degraded; full-file fallback required",
            category: .recordingManager,
            extra: [
                "reason": reason.rawValue,
                "error": error.localizedDescription,
            ]
        )
        try? await persistCheckpoint(lifecycleState: .failed)
    }
}
