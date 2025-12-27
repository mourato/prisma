import AVFoundation
import Foundation
import os.log

/// Merges multiple audio files into a single output file.
/// Used after recording to combine microphone and system audio tracks.
@MainActor
public final class AudioMerger {
    private let logger = Logger(subsystem: "MeetingAssistant", category: "AudioMerger")

    public init() {}

    // MARK: - Public API

    /// Merge multiple audio files into a single file.
    /// - Parameters:
    ///   - inputURLs: Array of audio file URLs to merge.
    ///   - outputURL: Destination URL.
    ///   - format: Target audio format (WAV or M4A).
    /// - Returns: URL of the merged file.
    public func mergeAudioFiles(inputURLs: [URL], to outputURL: URL, format: AppSettingsStore.AudioFormat) async throws -> URL {
        self.logger.info("Merging \(inputURLs.count) audio files to: \(outputURL.path) (Format: \(format.displayName))")

        // Filter out non-existent files
        let existingURLs = inputURLs.filter { FileManager.default.fileExists(atPath: $0.path) }

        guard !existingURLs.isEmpty else {
            throw AudioMergerError.noInputFiles
        }

        // Remove existing output file
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        // Create composition
        let composition = AVMutableComposition()

        // Add tracks (sequentially or mixed? implementation assumes mixing start at zero based on previous code)
        // Original code: inserts all at .zero. This creates a MIX.
        try await self.buildComposition(composition, from: existingURLs)

        // Extract sample rate from first audio track to match source
        let sampleRate = await self.extractSampleRate(from: composition) ?? 48_000.0
        self.logger.info("Using sample rate: \(sampleRate)Hz for export")

        // Export using AVAssetWriter
        try await self.export(composition: composition, to: outputURL, format: format, sampleRate: sampleRate)

        return outputURL
    }

    // MARK: - Private Methods

    private func buildComposition(_ composition: AVMutableComposition, from urls: [URL]) async throws {
        for (index, url) in urls.enumerated() {
            let asset = AVAsset(url: url)
            do {
                let tracks = try await asset.loadTracks(withMediaType: .audio)
                let duration = try await asset.load(.duration)

                guard let track = tracks.first else { continue }

                guard let compositionTrack = composition.addMutableTrack(
                    withMediaType: .audio,
                    preferredTrackID: Int32(index + 1)
                ) else { continue }

                try compositionTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: duration),
                    of: track,
                    at: .zero
                )
            } catch {
                self.logger.warning("Failed to add track from \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
    }

    private func extractSampleRate(from asset: AVAsset) async -> Double? {
        do {
            let tracks = try await asset.loadTracks(withMediaType: .audio)
            guard let track = tracks.first else { return nil }
            let formatDescriptions = try await track.load(.formatDescriptions)
            guard let formatDesc = formatDescriptions.first else { return nil }

            let audioDesc = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)
            return audioDesc?.pointee.mSampleRate
        } catch {
            self.logger.warning("Failed to extract sample rate: \(error.localizedDescription)")
            return nil
        }
    }

    private func export(
        composition: AVAsset,
        to outputURL: URL,
        format: AppSettingsStore.AudioFormat,
        sampleRate: Double
    ) async throws {
        // 1. Setup Reader
        let reader = try AVAssetReader(asset: composition)

        // Configure Reader Output to PCM for processing
        let readerSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsNonInterleaved: false,
        ]

        // Use async loadTracks instead of deprecated synchronous tracks(withMediaType:)
        let audioTracks = try await composition.loadTracks(withMediaType: .audio)
        let readerOutput = AVAssetReaderAudioMixOutput(audioTracks: audioTracks, audioSettings: readerSettings)
        if reader.canAdd(readerOutput) {
            reader.add(readerOutput)
        } else {
            throw AudioMergerError.failedToCreateExportSession
        }

        // 2. Setup Writer
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: format == .m4a ? .m4a : .wav)

        // Configure Writer Input based on format
        // Use source sample rate to avoid unnecessary conversion
        let writerSettings: [String: Any] = switch format {
        case .m4a:
            [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVNumberOfChannelsKey: 2,
                AVSampleRateKey: sampleRate,
                AVEncoderBitRateKey: 128_000,
            ]
        case .wav:
            [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVNumberOfChannelsKey: 2,
                AVSampleRateKey: sampleRate,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false,
            ]
        }

        let writerInput = AVAssetWriterInput(mediaType: .audio, outputSettings: writerSettings)
        writerInput.expectsMediaDataInRealTime = false

        if writer.canAdd(writerInput) {
            writer.add(writerInput)
        } else {
            throw AudioMergerError.failedToCreateExportSession
        }

        // 3. Start Processing
        if !reader.startReading() {
            throw AudioMergerError.exportFailed(reader.error)
        }

        if !writer.startWriting() {
            throw AudioMergerError.exportFailed(writer.error)
        }

        writer.startSession(atSourceTime: .zero)

        // 4. Pump Buffers
        // Use a detached task or blocking loop? AVAssetWriterInput requestMediaData is async-friendly-ish but usually used with a queue.
        // For simplicity in async context, we can use requestMediaDataWhenReady logic wrapper.

        await withCheckedContinuation { continuation in
            let queue = DispatchQueue(label: "audioMerger.export")

            writerInput.requestMediaDataWhenReady(on: queue) {
                while writerInput.isReadyForMoreMediaData {
                    if let buffer = readerOutput.copyNextSampleBuffer() {
                        if !writerInput.append(buffer) {
                            writerInput.markAsFinished()
                            continuation.resume()
                            return
                        }
                    } else {
                        // verify if reading actually finished or failed
                        if reader.status == .reading {
                            // This case might happen if we just ran out of buffer temporarily, but copyNextSampleBuffer implies pull.
                            // Usually nil means done or error.
                            // We should mark indices finished.
                            writerInput.markAsFinished()
                        } else if reader.status == .completed {
                            writerInput.markAsFinished()
                        } else if reader.status == .failed {
                            // We cannot throw easily from here async, so we signal finish and let the cleanup check catch it.
                            // Ideally we should cancel.
                            writerInput.markAsFinished() // Writer will likely fail or just finish empty.
                            // We will check listener status at the end.
                        } else {
                            writerInput.markAsFinished()
                        }
                        continuation.resume()
                        return
                    }
                }
            }
        }

        await writer.finishWriting()

        if writer.status == .failed {
            throw AudioMergerError.exportFailed(writer.error)
        }

        if reader.status == .failed {
            throw AudioMergerError.exportFailed(reader.error)
        }
    }
}

// MARK: - Errors

public enum AudioMergerError: LocalizedError {
    case noInputFiles
    case noValidTracks
    case failedToCreateExportSession
    case exportFailed(Error?)
    case exportCancelled

    public var errorDescription: String? {
        switch self {
        case .noInputFiles:
            return "No input files provided for merging"
        case .noValidTracks:
            return "No valid audio tracks found in input files"
        case .failedToCreateExportSession:
            return "Failed to create audio export session"
        case let .exportFailed(error):
            if let error {
                return "Audio export failed: \(error.localizedDescription)"
            }
            return "Audio export failed"
        case .exportCancelled:
            return "Audio export was cancelled"
        }
    }
}
