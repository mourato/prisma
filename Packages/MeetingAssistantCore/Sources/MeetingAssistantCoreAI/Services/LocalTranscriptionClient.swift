import Foundation
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import os.log

/// Client for local transcription using FluidAudio.
@MainActor
public class LocalTranscriptionClient {
    public static let shared = LocalTranscriptionClient()

    private let logger = Logger(subsystem: "MeetingAssistant", category: "LocalTranscriptionClient")
    private let manager = FluidAIModelManager.shared

    private init() {}

    /// Initializes and warms up the model.
    public func prepare() async {
        await manager.loadModels()
    }

    /// Transcribe an audio file locally.
    /// - Parameter audioURL: Path to the audio file.
    /// - Parameter onProgress: Optional callback for transcription progress.
    /// - Returns: TranscriptionResponse compatible with existing app logic.
    public func transcribe(
        audioURL: URL,
        isDiarizationEnabled: Bool? = nil,
        minSpeakers: Int? = nil,
        maxSpeakers: Int? = nil,
        numSpeakers: Int? = nil,
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> TranscriptionResponse {
        logger.info("Starting local transcription for: \(audioURL.lastPathComponent)")

        // Ensure models are loaded
        if manager.modelState != .loaded {
            await manager.loadModels()
        }

        let startTime = Date()

        // Perform transcription
        let (text, segmentsFromASR) = try await manager.transcribe(
            audioURL: audioURL,
            progress: onProgress
        )

        var segments: [Transcription.Segment] = []

        // Use passed settings or fallback to singleton (for app-process usage)
        let diarizationEnabled = isDiarizationEnabled ?? AppSettingsStore.shared.isDiarizationEnabled
        let minS = minSpeakers ?? AppSettingsStore.shared.minSpeakers
        let maxS = maxSpeakers ?? AppSettingsStore.shared.maxSpeakers
        let numS = numSpeakers ?? AppSettingsStore.shared.numSpeakers

        // Check if diarization is enabled
        if diarizationEnabled {
            // Perform diarization
            logger.info("Diarization enabled. Processing...")
            do {
                let diarizationSegments = try await manager.diarize(
                    audioURL: audioURL,
                    minSpeakers: minS,
                    maxSpeakers: maxS,
                    numSpeakers: numS
                )
                if segmentsFromASR.isEmpty {
                    // Fallback when token timings are unavailable.
                    segments = fallbackSegments(text: text, speakers: diarizationSegments)
                } else {
                    segments = merge(
                        text: text, asrSegments: segmentsFromASR, speakers: diarizationSegments
                    )

                    if segments.isEmpty {
                        segments = fallbackSegments(text: text, speakers: diarizationSegments)
                    }
                }
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
        guard let firstAsrSegment = asrSegments.first,
              let firstSpeaker = speakers.first
        else {
            return []
        }
        _ = firstAsrSegment // Validates asrSegments is not empty
        _ = firstSpeaker // Validates speakers is not empty

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

    private func fallbackSegments(
        text: String,
        speakers: [FluidAIModelManager.DiarizationSegment]
    ) -> [Transcription.Segment] {
        let sortedSpeakers = speakers.sorted { $0.startTime < $1.startTime }
        let words = text.split(whereSeparator: \.isWhitespace)
        guard !sortedSpeakers.isEmpty, !words.isEmpty else { return [] }

        let totalDuration = sortedSpeakers.reduce(0.0) { partial, segment in
            partial + max(0, segment.endTime - segment.startTime)
        }

        var result: [Transcription.Segment] = []
        var currentIndex = 0
        var remainingDuration = totalDuration

        for (index, speaker) in sortedSpeakers.enumerated() {
            let remainingWords = words.count - currentIndex
            guard remainingWords > 0 else { break }

            let duration = max(0, speaker.endTime - speaker.startTime)
            let isLast = index == sortedSpeakers.count - 1

            let wordCount: Int
            if isLast {
                wordCount = remainingWords
            } else if remainingDuration > 0 {
                let ratio = duration / remainingDuration
                wordCount = max(1, Int(round(ratio * Double(remainingWords))))
            } else {
                wordCount = max(1, remainingWords / max(1, sortedSpeakers.count - index))
            }

            let endIndex = min(currentIndex + wordCount, words.count)
            let segmentText = words[currentIndex..<endIndex].joined(separator: " ").trimmingCharacters(in: .whitespaces)
            currentIndex = endIndex
            remainingDuration -= duration

            guard !segmentText.isEmpty else { continue }

            result.append(
                Transcription.Segment(
                    speaker: speaker.speakerId,
                    text: segmentText,
                    startTime: speaker.startTime,
                    endTime: speaker.endTime
                )
            )
        }

        if currentIndex < words.count, !result.isEmpty {
            let remainder = words[currentIndex...].joined(separator: " ")
            let last = result[result.count - 1]
            let updated = Transcription.Segment(
                id: last.id,
                speaker: last.speaker,
                text: "\(last.text) \(remainder)".trimmingCharacters(in: .whitespaces),
                startTime: last.startTime,
                endTime: last.endTime
            )
            result[result.count - 1] = updated
        }

        return result
    }

    private func makeSegment(from batch: [FluidAIModelManager.AsrSegment], speaker: String)
        -> Transcription.Segment?
    {
        guard !batch.isEmpty else { return nil }

        let segmentText = batch.map(\.text).joined(separator: "").trimmingCharacters(
            in: .whitespaces
        )
        guard !segmentText.isEmpty else { return nil }

        let start = batch.first.map(\.startTime) ?? 0
        let end = batch.last.map(\.endTime) ?? 0

        return Transcription.Segment(
            speaker: speaker,
            text: segmentText,
            startTime: start,
            endTime: end
        )
    }
}
