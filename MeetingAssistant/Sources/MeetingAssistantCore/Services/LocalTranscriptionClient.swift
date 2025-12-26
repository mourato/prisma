import Foundation
import os.log

/// Client for local transcription using FluidAudio.
@MainActor
class LocalTranscriptionClient {
    static let shared = LocalTranscriptionClient()

    private let logger = Logger(subsystem: "MeetingAssistant", category: "LocalTranscriptionClient")
    private let manager = FluidAIModelManager.shared

    private init() {}

    /// Initializes and warms up the model.
    func prepare() async {
        await manager.loadModels()
    }

    /// Transcribe an audio file locally.
    /// - Parameter audioURL: Path to the audio file.
    /// - Returns: TranscriptionResponse compatible with existing app logic.
    func transcribe(audioURL: URL) async throws -> TranscriptionResponse {
        logger.info("Starting local transcription for: \(audioURL.lastPathComponent)")

        // Ensure models are loaded
        if manager.modelState != .loaded {
            await manager.loadModels()
        }

        let startTime = Date()

        // Perform transcription
        // Returns tuple (text, segments) -> conceptually "tokens" for alignment if they are small enough
        let (text, segmentsFromASR) = try await manager.transcribe(audioURL: audioURL)

        var segments: [Transcription.Segment] = []

        // Check if diarization is enabled
        if AppSettingsStore.shared.isDiarizationEnabled {
            // Perform diarization
            logger.info("Diarization enabled. Processing...")
            do {
                let diarizationSegments = try await manager.diarize(audioURL: audioURL)
                segments = merge(
                    text: text, asrSegments: segmentsFromASR, speakers: diarizationSegments)
            } catch {
                logger.error(
                    "Diarization failed: \(error.localizedDescription). Proceeding with transcription only."
                )
            }
        }

        let duration = Date().timeIntervalSince(startTime)
        let processedAt = ISO8601DateFormatter().string(from: Date())

        // Map FluidAudio result to App response
        return TranscriptionResponse(
            text: text,
            segments: segments,
            language: "auto",
            durationSeconds: duration,
            model: "parakeet-tdt-0.6b-v3-coreml",
            processedAt: processedAt
        )
    }

    /// Merges ASR segments with Speaker segments to produce aligned transcription segments.
    private func merge(
        text: String,
        asrSegments: [FluidAIModelManager.AsrSegment],
        speakers: [FluidAIModelManager.DiarizationSegment]
    ) -> [Transcription.Segment] {
        guard !asrSegments.isEmpty, !speakers.isEmpty else { return [] }

        var result: [Transcription.Segment] = []
        var currentSpeakerId = ""
        var currentBatch: [FluidAIModelManager.AsrSegment] = []

        // Simple algorithm: Assign each ASR segment to the speaker active at its midpoint
        // Then group consecutive segments of same speaker.

        for segment in asrSegments {
            let midPoint = (segment.startTime + segment.endTime) / 2.0

            // Find speaker active at midPoint
            // If overlapping speakers, pick the first one (simplification)
            let speaker =
                speakers.first { $0.startTime <= midPoint && $0.endTime >= midPoint }?.speakerId
                ?? Transcription.unknownSpeaker

            if speaker != currentSpeakerId {
                // Determine if we should start a new segment
                if let segment = makeSegment(from: currentBatch, speaker: currentSpeakerId) {
                    result.append(segment)
                }
                currentSpeakerId = speaker
                currentBatch = []
            }

            currentBatch.append(segment)
        }

        // Flush last segment
        if let segment = makeSegment(from: currentBatch, speaker: currentSpeakerId) {
            result.append(segment)
        }

        return result
    }

    private func makeSegment(from batch: [FluidAIModelManager.AsrSegment], speaker: String)
        -> Transcription.Segment?
    {
        guard !batch.isEmpty else { return nil }

        let segmentText = batch.map(\.text).joined(separator: "").trimmingCharacters(
            in: .whitespaces)
        guard !segmentText.isEmpty else { return nil }

        let start = batch.first?.startTime ?? 0
        let end = batch.last?.endTime ?? 0

        return Transcription.Segment(
            speaker: speaker,
            text: segmentText,
            startTime: start,
            endTime: end
        )
    }
}
