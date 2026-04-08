import Foundation
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreInfrastructure

extension RecordingManager {
    struct PreparedTranscriptionAudio {
        let transcriptionURL: URL
        let cleanupURL: URL?
    }

    func prepareAudioForTranscription(
        audioURL: URL,
        allowSilenceRemoval: Bool
    ) async -> PreparedTranscriptionAudio {
        guard allowSilenceRemoval else {
            return PreparedTranscriptionAudio(transcriptionURL: audioURL, cleanupURL: nil)
        }

        let settings = AppSettingsStore.shared
        guard settings.removeSilenceBeforeProcessing else {
            return PreparedTranscriptionAudio(transcriptionURL: audioURL, cleanupURL: nil)
        }

        // The compacted copy is only an internal transcription artifact.
        // Keep it PCM/WAV to avoid fragile AAC re-encoding in the hot path.
        let compactionFormat: AppSettingsStore.AudioFormat = .wav
        let tempOutputURL = temporaryCompactedAudioURL(for: compactionFormat)
        let startedAt = Date()

        do {
            let result = try await audioSilenceCompactor.compactForTranscription(
                inputURL: audioURL,
                outputURL: tempOutputURL,
                format: compactionFormat
            )
            let elapsedMs = Date().timeIntervalSince(startedAt) * 1_000

            AppLogger.info(
                "Prepared compacted audio for transcription",
                category: .recordingManager,
                extra: [
                    "input": audioURL.lastPathComponent,
                    "output": result.outputURL.lastPathComponent,
                    "wasCompacted": result.wasCompacted ? "true" : "false",
                    "originalDuration": String(result.originalDuration),
                    "compactedDuration": String(result.compactedDuration),
                    "removedDuration": String(result.removedDuration),
                    "removedRatio": String(result.removedRatio),
                    "compactionDurationMs": String(elapsedMs),
                ]
            )

            PerformanceMonitor.shared.reportMetric(
                name: "audio_silence_compaction_removed_ratio",
                value: result.removedRatio,
                unit: "ratio"
            )
            PerformanceMonitor.shared.reportMetric(
                name: "audio_silence_compaction_duration_ms",
                value: elapsedMs,
                unit: "ms"
            )

            guard result.wasCompacted else {
                storage.cleanupTemporaryFiles(urls: [tempOutputURL])
                return PreparedTranscriptionAudio(transcriptionURL: audioURL, cleanupURL: nil)
            }

            return PreparedTranscriptionAudio(
                transcriptionURL: result.outputURL,
                cleanupURL: result.outputURL
            )
        } catch {
            storage.cleanupTemporaryFiles(urls: [tempOutputURL])
            AppLogger.warning(
                "Silence compaction failed; falling back to original audio",
                category: .recordingManager,
                extra: [
                    "input": audioURL.lastPathComponent,
                    "error": error.localizedDescription,
                ]
            )
            return PreparedTranscriptionAudio(transcriptionURL: audioURL, cleanupURL: nil)
        }
    }

    func cleanupPreparedTranscriptionAudio(_ preparedAudio: PreparedTranscriptionAudio) {
        guard let cleanupURL = preparedAudio.cleanupURL else { return }
        storage.cleanupTemporaryFiles(urls: [cleanupURL])
    }

    private func temporaryCompactedAudioURL(for format: AppSettingsStore.AudioFormat) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("prisma-compacted-\(UUID().uuidString)")
            .appendingPathExtension(format.fileExtension)
    }
}
