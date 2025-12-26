import Foundation
@preconcurrency import ScreenCaptureKit
import AVFoundation
import CoreGraphics
import CoreMedia
import AudioToolbox
import os.log


/// Service for capturing system audio and microphone using ScreenCaptureKit and AVAudioEngine.
/// Mixes both sources into a single 16kHz Mono M4A file for Parakeet.
@MainActor
class AudioRecorder: ObservableObject {
    static let shared = AudioRecorder()
    
    private let logger = Logger(subsystem: "MeetingAssistant", category: "AudioRecorder")
    
    @Published private(set) var isRecording = false
    @Published private(set) var currentRecordingURL: URL?
    @Published private(set) var error: Error?
    
    // MARK: - Audio Engine & Capture
    private let engine = AVAudioEngine()
    private let systemAudioPlayer = AVAudioPlayerNode()
    
    private var stream: SCStream?
    private var assetWriter: AVAssetWriter?
    private var audioInput: AVAssetWriterInput?
    private var streamOutput: AudioStreamOutput?
    private var audioCaptureQueue: DispatchQueue?
    
    // MARK: - Configuration Constants
    
    // Output configuration for Parakeet (16kHz Mono)
    private let outputSampleRate: Double = 16000
    private let outputChannels: Int = 1
    private let audioBitRate = 64000
    
    // Internal processing format (standard 48kHz or 44.1kHz is usually best for engine)
    private let processingSampleRate: Double = 48000
    
    // Video capture (limit to minimal to save resources as we only want audio)
    private let minVideoDimension = 2
    private let videoFrameRate = 1
    
    private init() {
        // We delay engine setup until needed to avoid claiming resources too early
    }
    
    // MARK: - Lifecycle Management
    
    /// Start recording system audio + microphone.
    func startRecording(to outputURL: URL) async throws {
        guard !isRecording else {
            logger.warning("Already recording")
            return
        }
        
        logger.info("Starting recording to: \(outputURL.path)")
        
        guard await hasPermission() else {
            throw AudioRecorderError.permissionDenied
        }
        
        // Cleanup potential previous state
        await cleanup()
        
        do {
            // 1. Prepare Audio Engine
            try prepareEngine()
            
            // 2. Setup ScreenCaptureKit (System Audio)
            // We do this BEFORE writer to fail fast if no display / permission
            try await setupScreenCapture()
            
            // 3. Setup Asset Writer
            try setupAssetWriter(outputURL: outputURL)
            
            // 4. Install Tap on Main Mixer to write to file
            installTap()
            
            // 5. Start Engine
            try engine.start()
            
            // 6. Start Screen Capture
            if let stream = stream {
                try await stream.startCapture()
            }
            
            isRecording = true
            currentRecordingURL = outputURL
            logger.info("Audio Engine & Screen Capture started successfully")
            
        } catch {
            logger.error("Failed to start recording: \(error.localizedDescription)")
            // Rollback/Cleanup on failure
            await cleanup()
            throw error
        }
    }
    
    /// Stop recording.
    @discardableResult
    func stopRecording() async throws -> URL? {
        guard isRecording else { return nil }
        
        logger.info("Stopping recording...")
        
        // Stop capture
        if let stream = stream {
            try? await stream.stopCapture()
        }
        
        engine.stop()
        engine.mainMixerNode.removeTap(onBus: 0)
        
        // Finish writing
        if let assetWriter = assetWriter, assetWriter.status == .writing {
            audioInput?.markAsFinished()
            await assetWriter.finishWriting()
        }
        
        // Cleanup resources
        let url = currentRecordingURL
        await cleanup(keepFile: true)
        
        // Validate
        if let url = url {
            verifyFileIntegrity(url: url)
            return url
        }
        return nil
    }
    
    /// Internal cleanup method to reset state
    private func cleanup(keepFile: Bool = false) async {
        stream = nil
        streamOutput = nil
        
        engine.stop()
        engine.reset()
        engine.mainMixerNode.removeTap(onBus: 0)
        
        // Reset player node connections
        engine.detach(systemAudioPlayer)
        
        assetWriter = nil
        audioInput = nil
        
        totalFrames = 0
        
        isRecording = false
        if !keepFile {
            currentRecordingURL = nil
        }
    }
    
    // MARK: - Setup Methods
    
    private func prepareEngine() throws {
        // Ensure detached first
        engine.detach(systemAudioPlayer)
        engine.attach(systemAudioPlayer)
        
        let inputNode = engine.inputNode
        let mainMixer = engine.mainMixerNode
        
        // Configure Microphone Input
        // Note: inputNode format is read-only and determined by hardware.
        let inputFormat = inputNode.inputFormat(forBus: 0)
        
        // Connect Input -> Mixer
        // We let the mixer handle sample rate conversion if needed
        engine.connect(inputNode, to: mainMixer, format: inputFormat)
        
        // Configure System Audio Player
        // We'll feed it buffers at the processing rate
        guard let stereoFormat = AVAudioFormat(standardFormatWithSampleRate: processingSampleRate, channels: 2) else {
            logger.error("Failed to create stereo AVAudioFormat")
            throw AudioRecorderError.recordingFailed("Could not create audio format")
        }
        
        // Connect Player -> Mixer
        engine.connect(systemAudioPlayer, to: mainMixer, format: stereoFormat)
        
        engine.prepare()
    }
    
    private func setupAssetWriter(outputURL: URL) throws {
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }
        
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .m4a)
        assetWriter = writer
        
        // Output format: M4A (AAC), 16kHz, Mono
        var acl = AudioChannelLayout()
        memset(&acl, 0, MemoryLayout<AudioChannelLayout>.size)
        acl.mChannelLayoutTag = kAudioChannelLayoutTag_Mono
        
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: outputSampleRate,
            AVNumberOfChannelsKey: outputChannels,
            AVEncoderBitRateKey: audioBitRate,
            AVChannelLayoutKey: Data(bytes: &acl, count: MemoryLayout<AudioChannelLayout>.size)
        ]
        
        let input = AVAssetWriterInput(mediaType: .audio, outputSettings: outputSettings)
        input.expectsMediaDataInRealTime = true
        audioInput = input
        
        if writer.canAdd(input) {
            writer.add(input)
        } else {
            throw AudioRecorderError.recordingFailed("Cannot add audio input to writer")
        }
        
        if !writer.startWriting() {
            throw AudioRecorderError.recordingFailed("Failed to start writing: \(writer.error?.localizedDescription ?? "Unknown error")")
        }
        
        writer.startSession(atSourceTime: .zero)
    }
    
    private func setupScreenCapture() async throws {
        let content = try await SCShareableContent.current
        
        // Prioritize finding a suitable display
        guard let display = content.displays.first else {
            throw AudioRecorderError.noDisplayFound
        }
        
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true // Avoid feedback loop?
        // Capture at our processing rate to match the player node
        config.sampleRate = Int(processingSampleRate)
        config.channelCount = 2 // Capture stereo from system
        config.width = minVideoDimension
        config.height = minVideoDimension
        config.minimumFrameInterval = CMTime(value: 1, timescale: Int32(videoFrameRate))
        
        stream = SCStream(filter: filter, configuration: config, delegate: nil)
        
        let queue = DispatchQueue(label: "audio-capture")
        audioCaptureQueue = queue
        
        // Create output handler
        let output = AudioStreamOutput(playerNode: systemAudioPlayer, logger: logger)
        streamOutput = output
        
        do {
            try stream?.addStreamOutput(output, type: .audio, sampleHandlerQueue: queue)
        } catch {
            logger.error("Failed to add stream output: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func installTap() {
        let mainMixer = engine.mainMixerNode
        let format = mainMixer.outputFormat(forBus: 0) // The mixer's operating format
        
        // Remove existing tap if any
        mainMixer.removeTap(onBus: 0)
        
        mainMixer.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] (buffer, time) in
            guard let self = self,
                  let input = self.audioInput,
                  let writer = self.assetWriter,
                  writer.status == .writing,
                  input.isReadyForMoreMediaData else { return }
            
            // Create a CMSampleBuffer wrapping the data
            if let sampleBuffer = self.createSampleBuffer(from: buffer) {
                input.append(sampleBuffer)
            }
        }
    }
    
    /// Converts AVAudioPCMBuffer to CMSampleBuffer safely
    private func createSampleBuffer(from buffer: AVAudioPCMBuffer) -> CMSampleBuffer? {
        return createCMSampleBufferWithAudioBufferList(from: buffer, timestamp: getCurrentTimestamp(for: buffer))
    }
    
    private var totalFrames: AVAudioFramePosition = 0
    private let timestampLock = NSLock()
    
    private func getCurrentTimestamp(for buffer: AVAudioPCMBuffer) -> CMTime {
        timestampLock.lock()
        defer { timestampLock.unlock() }
        
        let time = CMTime(value: Int64(totalFrames), timescale: Int32(buffer.format.sampleRate))
        totalFrames += Int64(buffer.frameLength)
        return time
    }
    
    /// Safer creation of CMSampleBuffer using CMSampleBufferCreate and CMSampleBufferSetDataBufferFromAudioBufferList
    private func createCMSampleBufferWithAudioBufferList(from buffer: AVAudioPCMBuffer, timestamp: CMTime) -> CMSampleBuffer? {
        let formatDescription = buffer.format.formatDescription
        
        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: Int32(buffer.format.sampleRate)),
            presentationTimeStamp: timestamp,
            decodeTimeStamp: .invalid
        )
        
        var sampleBuffer: CMSampleBuffer?
        
        let status = CMSampleBufferCreate(
            allocator: kCFAllocatorDefault,
            dataBuffer: nil,
            dataReady: false,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: formatDescription,
            sampleCount: CMItemCount(buffer.frameLength),
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleSizeEntryCount: 0,
            sampleSizeArray: nil,
            sampleBufferOut: &sampleBuffer
        )
        
        guard status == noErr, let sBuffer = sampleBuffer else {
            logger.error("CMSampleBufferCreate failed: \(status)")
            return nil
        }
        
        let result = CMSampleBufferSetDataBufferFromAudioBufferList(
            sBuffer,
            blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault,
            flags: 0,
            bufferList: buffer.audioBufferList
        )
        
        if result != noErr {
            logger.error("CMSampleBufferSetDataBufferFromAudioBufferList failed: \(result)")
            return nil
        }
        
        return sBuffer
    }
    
    // MARK: - Helper Methods
    
    func hasPermission() async -> Bool {
        // Check Screen Recording (Silent check)
        let screenAuth = CGPreflightScreenCaptureAccess()
        if !screenAuth { return false }
        
        // Check Microphone (Silent check)
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        return micStatus == .authorized
    }
    
    func requestPermission() async {
        // Microphone (triggers prompt if needed)
        await AVCaptureDevice.requestAccess(for: .audio)
        
        // Screen Recording (triggers prompt if needed via SCKit)
        // There is no explicit request API for Screen Recording, 
        // calling SCShareableContent.current usually triggers it if not authorized.
        _ = try? await SCShareableContent.current
    }
    
    func openScreenRecordingSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }

    func openMicrophoneSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
        NSWorkspace.shared.open(url)
    }
    
    private func verifyFileIntegrity(url: URL) {
        let asset = AVAsset(url: url)
        Task {
            do {
                let duration = try await asset.load(.duration)
                logger.info("Recording saved: \(url.lastPathComponent) (\(duration.seconds)s)")
            } catch {
                logger.error("Verification failed: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Stream Output Handler

private class AudioStreamOutput: NSObject, SCStreamOutput {
    private let playerNode: AVAudioPlayerNode
    private let logger: Logger
    
    init(playerNode: AVAudioPlayerNode, logger: Logger) {
        self.playerNode = playerNode
        self.logger = logger
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio, sampleBuffer.isValid else { return }
        
        // Convert CMSampleBuffer to AVAudioPCMBuffer
        if let buffer = createPCMBuffer(from: sampleBuffer) {
            // Schedule the buffer to play
            playerNode.scheduleBuffer(buffer) {
                // Completion handler (optional)
            }
            
            // Ensure player is playing
            if !playerNode.isPlaying {
                playerNode.play()
            }
        }
    }
    
    private func createPCMBuffer(from sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else { return nil }
        let format = AVAudioFormat(cmAudioFormatDescription: formatDescription)
        
        let frames = AVAudioFrameCount(sampleBuffer.numSamples)
        
        // Ensure strictly that we can allocate this buffer
        guard frames > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return nil }
        buffer.frameLength = frames
        
        let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(
            sampleBuffer,
            at: 0,
            frameCount: Int32(frames),
            into: buffer.mutableAudioBufferList
        )
        
        return status == noErr ? buffer : nil
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
