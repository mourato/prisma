import Foundation
@preconcurrency import ScreenCaptureKit
import AVFoundation
import os.log

/// Service for capturing system audio using ScreenCaptureKit.
/// Requires macOS 13.0+ and screen recording permissions.
@MainActor
class AudioRecorder: ObservableObject {
    static let shared = AudioRecorder()
    
    private let logger = Logger(subsystem: "MeetingAssistant", category: "AudioRecorder")
    
    @Published private(set) var isRecording = false
    @Published private(set) var currentRecordingURL: URL?
    @Published private(set) var error: Error?
    
    private var stream: SCStream?
    private var assetWriter: AVAssetWriter?
    private var audioInput: AVAssetWriterInput?
    private var streamOutput: AudioStreamOutput?
    private var audioCaptureQueue: DispatchQueue?
    
    // Audio configuration for Parakeet compatibility
    private let sampleRate: Double = 16000
    private let channels: AVAudioChannelCount = 1
    private let audioBitRate = 64000 // 64 kbps - good quality for speech
    
    private init() {}
    
    /// Start recording system audio in M4A format (AAC encoded).
    /// - Parameter outputURL: Where to save the M4A file
    func startRecording(to outputURL: URL) async throws {
        guard !isRecording else {
            logger.warning("Already recording")
            return
        }
        
        logger.info("Starting audio recording to: \(outputURL.path)")
        
        // Check permissions
        guard await hasPermission() else {
            throw AudioRecorderError.permissionDenied
        }
        
        // Get shareable content
        let content = try await SCShareableContent.current
        
        // We need at least one display to capture audio
        guard let display = content.displays.first else {
            throw AudioRecorderError.noDisplayFound
        }
        
        // Configure stream for audio-only capture
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        
        // Audio settings
        config.capturesAudio = true
        config.sampleRate = Int(sampleRate)
        config.channelCount = Int(channels)
        
        // Minimize video capture (we only need audio)
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1) // 1 fps
        
        // Setup AVAssetWriter for M4A output
        try setupAssetWriter(outputURL: outputURL)
        
        // Create stream output handler
        streamOutput = AudioStreamOutput(
            audioInput: audioInput!,
            assetWriter: assetWriter!,
            logger: logger
        )
        
        // Create and start stream
        stream = SCStream(filter: filter, configuration: config, delegate: nil)
        
        // Store the queue for later synchronization
        audioCaptureQueue = DispatchQueue(label: "audio-capture")
        
        try stream?.addStreamOutput(
            streamOutput!,
            type: .audio,
            sampleHandlerQueue: audioCaptureQueue
        )
        
        try await stream?.startCapture()
        
        isRecording = true
        currentRecordingURL = outputURL
        logger.info("Recording started successfully (M4A/AAC format)")
    }
    
    /// Stop the current recording.
    /// - Returns: URL to the saved audio file
    @discardableResult
    func stopRecording() async throws -> URL? {
        guard isRecording, let stream = stream else {
            logger.warning("Not recording")
            return nil
        }
        
        logger.info("Stopping recording...")
        
        // Stop the screen capture stream
        try await stream.stopCapture()
        
        // CRITICAL: Wait for the audio capture queue to finish processing
        // any pending samples before finalizing the asset writer.
        // This prevents the "moov atom not found" error caused by incomplete files.
        if let queue = audioCaptureQueue {
            await withCheckedContinuation { continuation in
                queue.async(flags: .barrier) {
                    continuation.resume()
                }
            }
        }
        
        // Finalize the M4A file (writes the moov atom)
        await finalizeAssetWriter()
        
        // Cleanup
        self.stream = nil
        self.streamOutput = nil
        self.audioCaptureQueue = nil
        
        isRecording = false
        
        let savedURL = currentRecordingURL
        if let url = savedURL {
            logFileSizeInfo(url: url)
            verifyFileIntegrity(url: url)
        }
        
        return savedURL
    }
    
    /// Check if we have screen recording permission.
    func hasPermission() async -> Bool {
        do {
            _ = try await SCShareableContent.current
            return true
        } catch {
            logger.error("Permission check failed: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Request screen recording permission by triggering the system prompt.
    func requestPermission() async {
        // Attempting to get shareable content triggers the permission prompt
        _ = try? await SCShareableContent.current
    }
    
    /// Opens System Preferences to the Screen Recording section.
    func openScreenRecordingSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }
    
    // MARK: - Private Methods
    
    /// Setup AVAssetWriter for M4A (AAC) output.
    private func setupAssetWriter(outputURL: URL) throws {
        // Remove existing file if present
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }
        
        assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .m4a)
        
        // AAC audio settings optimized for speech
        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: channels,
            AVEncoderBitRateKey: audioBitRate
        ]
        
        audioInput = AVAssetWriterInput(
            mediaType: .audio,
            outputSettings: audioSettings
        )
        audioInput?.expectsMediaDataInRealTime = true
        
        if let input = audioInput, assetWriter!.canAdd(input) {
            assetWriter?.add(input)
        } else {
            throw AudioRecorderError.recordingFailed("Cannot add audio input to asset writer")
        }
        
        guard assetWriter?.startWriting() == true else {
            let errorMsg = assetWriter?.error?.localizedDescription ?? "Unknown error"
            throw AudioRecorderError.recordingFailed("Failed to start asset writer: \(errorMsg)")
        }
        
        assetWriter?.startSession(atSourceTime: .zero)
        logger.debug("Asset writer configured for M4A output")
    }
    
    /// Finalize the asset writer and close the file.
    /// This writes the moov atom which is essential for the file to be playable.
    private func finalizeAssetWriter() async {
        guard let writer = assetWriter else {
            logger.warning("No asset writer to finalize")
            return
        }
        
        // Mark audio input as finished
        audioInput?.markAsFinished()
        
        // Wait for the writer to finish writing
        await withCheckedContinuation { continuation in
            writer.finishWriting {
                continuation.resume()
            }
        }
        
        // Check for errors during finalization
        if writer.status == .failed {
            let errorMsg = writer.error?.localizedDescription ?? "Unknown error"
            logger.error("Asset writer failed during finalization: \(errorMsg)")
        } else if writer.status == .completed {
            logger.debug("Asset writer finalized successfully (moov atom written)")
        } else {
            logger.warning("Asset writer finished with unexpected status: \(writer.status.rawValue)")
        }
        
        assetWriter = nil
        audioInput = nil
    }
    
    /// Log file size information for debugging.
    private func logFileSizeInfo(url: URL) {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let fileSize = attributes[.size] as? Int64 {
                let fileSizeFormatted = ByteCountFormatter.string(
                    fromByteCount: fileSize,
                    countStyle: .file
                )
                logger.info("Recording saved: \(url.lastPathComponent) (\(fileSizeFormatted))")
            }
        } catch {
            logger.info("Recording saved to: \(url.path)")
        }
    }
    
    /// Verify that the M4A file is valid and readable.
    /// This helps detect corrupted files (missing moov atom) immediately.
    private func verifyFileIntegrity(url: URL) {
        let asset = AVAsset(url: url)
        
        Task {
            do {
                let duration = try await asset.load(.duration)
                let durationSeconds = CMTimeGetSeconds(duration)
                
                if durationSeconds > 0 {
                    logger.info("Recording verified: \(String(format: "%.1f", durationSeconds)) seconds")
                } else {
                    logger.warning("Recording may be invalid: duration is zero or negative")
                }
            } catch {
                logger.error("Failed to verify recording integrity: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Stream Output Handler

/// Handles audio samples from ScreenCaptureKit stream.
private class AudioStreamOutput: NSObject, SCStreamOutput {
    private let audioInput: AVAssetWriterInput
    private let assetWriter: AVAssetWriter
    private let logger: Logger
    private var isFirstSample = true
    private var sessionStartTime: CMTime = .zero
    
    init(audioInput: AVAssetWriterInput, assetWriter: AVAssetWriter, logger: Logger) {
        self.audioInput = audioInput
        self.assetWriter = assetWriter
        self.logger = logger
    }
    
    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard type == .audio else { return }
        guard sampleBuffer.isValid else { return }
        guard assetWriter.status == .writing else { return }
        
        // Handle first sample timing
        if isFirstSample {
            sessionStartTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            isFirstSample = false
        }
        
        // Adjust timestamp relative to session start
        let adjustedBuffer = adjustTimestamp(sampleBuffer)
        
        // Write to asset writer
        if audioInput.isReadyForMoreMediaData {
            audioInput.append(adjustedBuffer ?? sampleBuffer)
        }
    }
    
    /// Adjust sample buffer timestamp to start from zero.
    private func adjustTimestamp(_ buffer: CMSampleBuffer) -> CMSampleBuffer? {
        let originalTime = CMSampleBufferGetPresentationTimeStamp(buffer)
        let adjustedTime = CMTimeSubtract(originalTime, sessionStartTime)
        
        var timingInfo = CMSampleTimingInfo(
            duration: CMSampleBufferGetDuration(buffer),
            presentationTimeStamp: adjustedTime,
            decodeTimeStamp: .invalid
        )
        
        var adjustedBuffer: CMSampleBuffer?
        CMSampleBufferCreateCopyWithNewTiming(
            allocator: nil,
            sampleBuffer: buffer,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timingInfo,
            sampleBufferOut: &adjustedBuffer
        )
        
        return adjustedBuffer
    }
}

// MARK: - Errors

enum AudioRecorderError: LocalizedError {
    case permissionDenied
    case noDisplayFound
    case recordingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Permissão de gravação de tela negada. Habilite nas Preferências do Sistema."
        case .noDisplayFound:
            return "Nenhum display encontrado para captura de áudio."
        case .recordingFailed(let reason):
            return "Falha na gravação: \(reason)"
        }
    }
}
