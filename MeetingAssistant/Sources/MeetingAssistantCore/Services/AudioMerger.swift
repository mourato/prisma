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

    /// Merge multiple audio files into a single M4A file.
    /// - Parameters:
    ///   - inputURLs: Array of audio file URLs to merge (can be different formats/sample rates)
    ///   - outputURL: Destination URL for the merged file (.m4a)
    /// - Returns: URL of the merged file
    public func mergeAudioFiles(inputURLs: [URL], to outputURL: URL) async throws -> URL {
        self.logger.info("Merging \(inputURLs.count) audio files to: \(outputURL.path)")

        // Filter out non-existent files
        let existingURLs = inputURLs.filter { FileManager.default.fileExists(atPath: $0.path) }

        guard !existingURLs.isEmpty else {
            throw AudioMergerError.noInputFiles
        }

        // If only one file exists, just convert it to M4A
        if existingURLs.count == 1 {
            return try await self.convertToM4A(inputURL: existingURLs[0], outputURL: outputURL)
        }

        // Create composition
        let composition = AVMutableComposition()

        // Load all assets and add to composition
        var longestDuration: CMTime = .zero

        for (index, url) in existingURLs.enumerated() {
            let asset = AVAsset(url: url)

            do {
                let tracks = try await asset.loadTracks(withMediaType: .audio)
                let duration = try await asset.load(.duration)

                guard let track = tracks.first else {
                    self.logger.warning("No audio track found in: \(url.lastPathComponent)")
                    continue
                }

                guard let compositionTrack = composition.addMutableTrack(
                    withMediaType: .audio,
                    preferredTrackID: Int32(index + 1)
                ) else {
                    self.logger.warning("Failed to add track for: \(url.lastPathComponent)")
                    continue
                }

                try compositionTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: duration),
                    of: track,
                    at: .zero
                )

                if duration > longestDuration {
                    longestDuration = duration
                }

                self.logger.info("Added track: \(url.lastPathComponent) (\(duration.seconds)s)")

            } catch {
                self.logger.warning("Failed to load asset \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }

        guard !composition.tracks.isEmpty else {
            throw AudioMergerError.noValidTracks
        }

        // Export to M4A
        return try await self.exportComposition(composition, to: outputURL)
    }

    /// Convert a single audio file to M4A format.
    public func convertToM4A(inputURL: URL, outputURL: URL) async throws -> URL {
        self.logger.info("Converting \(inputURL.lastPathComponent) to M4A")

        let asset = AVAsset(url: inputURL)
        return try await self.exportAsset(asset, to: outputURL)
    }

    // MARK: - Private Methods

    private func exportComposition(_ composition: AVComposition, to outputURL: URL) async throws -> URL {
        try await self.exportAsset(composition, to: outputURL)
    }

    private func exportAsset(_ asset: AVAsset, to outputURL: URL) async throws -> URL {
        // Remove existing file if present
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        // Create export session
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw AudioMergerError.failedToCreateExportSession
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a

        // Optimize for speech transcription: 16kHz mono
        exportSession.audioMix = try await self.createAudioMix(for: asset)

        // Export
        await exportSession.export()

        switch exportSession.status {
        case .completed:
            self.logger.info("Export completed: \(outputURL.lastPathComponent)")
            return outputURL
        case .failed:
            throw AudioMergerError.exportFailed(exportSession.error)
        case .cancelled:
            throw AudioMergerError.exportCancelled
        default:
            throw AudioMergerError.exportFailed(nil)
        }
    }

    private func createAudioMix(for asset: AVAsset) async throws -> AVAudioMix? {
        let tracks = try await asset.loadTracks(withMediaType: .audio)

        guard !tracks.isEmpty else { return nil }

        let mix = AVMutableAudioMix()
        var inputParameters: [AVMutableAudioMixInputParameters] = []

        for track in tracks {
            let params = AVMutableAudioMixInputParameters(track: track)
            // Keep full volume for all tracks
            params.setVolume(1.0, at: .zero)
            inputParameters.append(params)
        }

        mix.inputParameters = inputParameters
        return mix
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
