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
        // Now returns tuple (text, tokens)
        let (text, tokens) = try await manager.transcribe(audioURL: audioURL)

        var segments: [Transcription.Segment] = []

        // Check if diarization is enabled
        if AppSettingsStore.shared.isDiarizationEnabled {
            // Perform diarization
            logger.info("Diarization enabled. Processing...")
            do {
                let diarizationSegments = try await manager.diarize(audioURL: audioURL)
                segments = merge(text: text, tokens: tokens, speakers: diarizationSegments)
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

    /// Merges ASR tokens with Speaker segments to produce aligned transcription segments.
    private func merge(
        text: String,
        tokens: [FluidAIModelManager.AsrToken],
        speakers: [FluidAIModelManager.DiarizationSegment]
    ) -> [Transcription.Segment] {
        guard !tokens.isEmpty, !speakers.isEmpty else { return [] }

        var result: [Transcription.Segment] = []
        var currentSpeakerId = ""
        var currentSegmentTokens: [FluidAIModelManager.AsrToken] = []

        // Simple algorithm: Assign each token to the speaker active at token's midpoint
        // Then group consecutive tokens of same speaker.

        for token in tokens {
            let midPoint = (token.startTime + token.endTime) / 2.0

            // Find speaker active at midPoint
            // If overlapping speakers, pick the first one (simplification)
            let speaker =
                speakers.first { $0.startTime <= midPoint && $0.endTime >= midPoint }?.speakerId
                ?? "Desconhecido"

            if speaker != currentSpeakerId {
                // Determine if we should start a new segment
                if !currentSegmentTokens.isEmpty {
                    let segmentText = currentSegmentTokens.map(\.text).joined(separator: "")
                        .trimmingCharacters(in: .whitespaces)
                    if !segmentText.isEmpty {
                        let start = currentSegmentTokens.first?.startTime ?? 0
                        let end = currentSegmentTokens.last?.endTime ?? 0
                        result.append(
                            Transcription.Segment(
                                speaker: currentSpeakerId,
                                text: segmentText,
                                startTime: start,
                                endTime: end
                            ))
                    }
                }
                currentSpeakerId = speaker
                currentSegmentTokens = []
            }

            currentSegmentTokens.append(token)
        }

        // Flush last segment
        if !currentSegmentTokens.isEmpty {
            let segmentText = currentSegmentTokens.map(\.text).joined(separator: "")
                .trimmingCharacters(in: .whitespaces)
            if !segmentText.isEmpty {
                let start = currentSegmentTokens.first?.startTime ?? 0
                let end = currentSegmentTokens.last?.endTime ?? 0
                result.append(
                    Transcription.Segment(
                        speaker: currentSpeakerId,
                        text: segmentText,
                        startTime: start,
                        endTime: end
                    ))
            }
        }

        return result
    }
}
