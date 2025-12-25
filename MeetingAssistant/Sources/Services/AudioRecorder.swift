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
        
        try stream?.addStreamOutput(
            streamOutput!,
            type: .audio,
            sampleHandlerQueue: DispatchQueue(label: "audio-capture")
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
        
        try await stream.stopCapture()
        
        // Finalize the M4A file
        await finalizeAssetWriter()
        
        // Cleanup
        self.stream = nil
        self.streamOutput = nil
        
        isRecording = false
        
        let savedURL = currentRecordingURL
        if let url = savedURL {
            logFileSizeInfo(url: url)
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
    private func finalizeAssetWriter() async {
        audioInput?.markAsFinished()
        
        await withCheckedContinuation { continuation in
            assetWriter?.finishWriting {
                continuation.resume()
            }
        }
        
        assetWriter = nil
        audioInput = nil
        logger.debug("Asset writer finalized")
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
