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
    private var audioFile: AVAudioFile?
    private var streamOutput: AudioStreamOutput?
    
    // Audio configuration for Parakeet compatibility
    private let sampleRate: Double = 16000
    private let channels: AVAudioChannelCount = 1
    
    private init() {}
    
    /// Start recording system audio.
    /// - Parameter outputURL: Where to save the WAV file
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
        
        // Prepare audio file
        let audioFormat = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: channels
        )!
        
        audioFile = try AVAudioFile(
            forWriting: outputURL,
            settings: audioFormat.settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
        
        // Create stream output handler
        streamOutput = AudioStreamOutput(audioFile: audioFile!, logger: logger)
        
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
        logger.info("Recording started successfully")
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
        
        // Cleanup
        self.stream = nil
        self.audioFile = nil
        self.streamOutput = nil
        
        isRecording = false
        
        let savedURL = currentRecordingURL
        logger.info("Recording saved to: \(savedURL?.path ?? "unknown")")
        
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
}

// MARK: - Stream Output Handler

/// Handles audio samples from ScreenCaptureKit stream.
private class AudioStreamOutput: NSObject, SCStreamOutput {
    private let audioFile: AVAudioFile
    private let logger: Logger
    
    init(audioFile: AVAudioFile, logger: Logger) {
        self.audioFile = audioFile
        self.logger = logger
    }
    
    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard type == .audio else { return }
        
        // Convert CMSampleBuffer to AVAudioPCMBuffer
        guard let pcmBuffer = createPCMBuffer(from: sampleBuffer) else {
            logger.warning("Failed to create PCM buffer")
            return
        }
        
        // Write to file
        do {
            try audioFile.write(from: pcmBuffer)
        } catch {
            logger.error("Failed to write audio: \(error.localizedDescription)")
        }
    }
    
    private func createPCMBuffer(from sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
              let audioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)
        else {
            return nil
        }
        
        let format = AVAudioFormat(streamDescription: audioStreamBasicDescription)!
        
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            return nil
        }
        
        let frameCount = CMSampleBufferGetNumSamples(sampleBuffer)
        
        guard let pcmBuffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(frameCount)
        ) else {
            return nil
        }
        
        pcmBuffer.frameLength = AVAudioFrameCount(frameCount)
        
        var dataPointer: UnsafeMutablePointer<Int8>?
        var dataLength: Int = 0
        
        CMBlockBufferGetDataPointer(
            blockBuffer,
            atOffset: 0,
            lengthAtOffsetOut: nil,
            totalLengthOut: &dataLength,
            dataPointerOut: &dataPointer
        )
        
        if let data = dataPointer, let channelData = pcmBuffer.floatChannelData {
            memcpy(channelData[0], data, dataLength)
        }
        
        return pcmBuffer
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
