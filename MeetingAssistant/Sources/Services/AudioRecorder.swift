import Foundation
@preconcurrency import ScreenCaptureKit
import AVFoundation
import CoreGraphics
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
    
    // Video capture (minimal)
    private let minVideoDimension = 2
    private let videoFrameRate = 1
    
    private init() {
        setupAudioEngine()
    }
    
    private func setupAudioEngine() {
        engine.attach(systemAudioPlayer)
        
        // Connect system audio player to main mixer
        // We'll configure format later when we start recording and know the hardware format
        let mainMixer = engine.mainMixerNode
        engine.connect(systemAudioPlayer, to: mainMixer, format: nil)
        
        // Microphone input is connected automatically by the engine when we access inputNode,
        // but we need to ensure volume is up and format is compatible.
        // We'll do this in startRecording.
    }
    
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
        
        // 1. Prepare Audio Engine
        try prepareEngine()
        
        // 2. Setup Asset Writer
        try setupAssetWriter(outputURL: outputURL)
        
        // 3. Setup ScreenCaptureKit (System Audio)
        try await setupScreenCapture()
        
        // 4. Install Tap on Main Mixer to write to file
        installTap()
        
        // 5. Start Engine
        try engine.start()
        
        // 6. Start Screen Capture
        try await stream?.startCapture()
        
        isRecording = true
        currentRecordingURL = outputURL
        logger.info("Audio Engine & Screen Capture started")
    }
    
    /// Stop recording.
    @discardableResult
    func stopRecording() async throws -> URL? {
        guard isRecording else { return nil }
        
        logger.info("Stopping recording...")
        
        // Stop capture related items
        if let stream = stream {
            try await stream.stopCapture()
        }
        
        engine.stop()
        engine.mainMixerNode.removeTap(onBus: 0)
        
        // Finish writing
        if let assetWriter = assetWriter, assetWriter.status == .writing {
            audioInput?.markAsFinished()
            await assetWriter.finishWriting()
        }
        
        // Cleanup
        stream = nil
        streamOutput = nil
        assetWriter = nil
        audioInput = nil
        isRecording = false
        
        // Validate
        if let url = currentRecordingURL {
            verifyFileIntegrity(url: url)
            return url
        }
        return nil
    }
    
    // MARK: - Setup Methods
    
    private func prepareEngine() throws {
        let inputNode = engine.inputNode
        let mainMixer = engine.mainMixerNode
        
        // Configure Microphone Input
        // Note: inputNode format is read-only and determined by hardware.
        // We connect it to mixer, allowing mixer to handle resampling if needed.
        let inputFormat = inputNode.inputFormat(forBus: 0)
        engine.connect(inputNode, to: mainMixer, format: inputFormat)
        
        // Configure System Audio Player
        // We'll feed it buffers at the processing rate
        let stereoFormat = AVAudioFormat(standardFormatWithSampleRate: processingSampleRate, channels: 2)!
        engine.connect(systemAudioPlayer, to: mainMixer, format: stereoFormat)
        
        engine.prepare()
    }
    
    private func setupAssetWriter(outputURL: URL) throws {
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }
        
        assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .m4a)
        
        // Output format: AAC, 16kHz, Mono
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: outputSampleRate,
            AVNumberOfChannelsKey: outputChannels,
            AVEncoderBitRateKey: audioBitRate
        ]
        
        audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: outputSettings)
        audioInput?.expectsMediaDataInRealTime = true
        
        guard let writer = assetWriter, let input = audioInput else { return }
        
        if writer.canAdd(input) {
            writer.add(input)
        }
        
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
    }
    
    private func setupScreenCapture() async throws {
        let content = try await SCShareableContent.current
        guard let display = content.displays.first else {
            throw AudioRecorderError.noDisplayFound
        }
        
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        
        config.capturesAudio = true
        // Capture at our processing rate to match the player node
        config.sampleRate = Int(processingSampleRate)
        config.channelCount = 2 // Capture stereo from system
        config.width = minVideoDimension
        config.height = minVideoDimension
        config.minimumFrameInterval = CMTime(value: 1, timescale: Int32(videoFrameRate))
        
        stream = SCStream(filter: filter, configuration: config, delegate: nil)
        
        audioCaptureQueue = DispatchQueue(label: "audio-capture")
        streamOutput = AudioStreamOutput(playerNode: systemAudioPlayer, logger: logger)
        
        try stream?.addStreamOutput(streamOutput!, type: .audio, sampleHandlerQueue: audioCaptureQueue!)
    }
    
    private func installTap() {
        let mainMixer = engine.mainMixerNode
        let format = mainMixer.outputFormat(forBus: 0) // The mixer's operating format
        
        mainMixer.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] (buffer, time) in
            guard let self = self,
                  let input = self.audioInput,
                  let writer = self.assetWriter,
                  writer.status == .writing,
                  input.isReadyForMoreMediaData else { return }
            
            // Adjust timestamp to be continuous
            // Note: In a real app, we might need robust timestamp logic.
            // For now, we rely on the continuous stream from the mixer.
            
            // Convert AVAudioPCMBuffer to CMSampleBuffer for AVAssetWriter
            if let sampleBuffer = self.createSampleBuffer(from: buffer) {
                input.append(sampleBuffer)
            }
        }
    }
    
    /// Converts AVAudioPCMBuffer to CMSampleBuffer
    private func createSampleBuffer(from buffer: AVAudioPCMBuffer) -> CMSampleBuffer? {
        return createCMSampleBuffer(from: buffer, timestamp: getCurrentTimestamp(for: buffer))
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
    
    private func createCMSampleBuffer(from buffer: AVAudioPCMBuffer, timestamp: CMTime) -> CMSampleBuffer? {
        var backingASBD = buffer.format.streamDescription.pointee
        
        var formatDesc: CMAudioFormatDescription?
        CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault, asbd: &backingASBD, layoutSize: 0, layout: nil, magicCookieSize: 0, magicCookie: nil, extensions: nil, formatDescriptionOut: &formatDesc)
        
        guard let format = formatDesc else { return nil }
        
        var sampleBuffer: CMSampleBuffer?
        var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: Int32(backingASBD.mSampleRate)), presentationTimeStamp: timestamp, decodeTimeStamp: .invalid)
        
        CMSampleBufferCreate(
            allocator: kCFAllocatorDefault,
            dataBuffer: nil,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: format,
            sampleCount: CMItemCount(buffer.frameLength),
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleSizeEntryCount: 0,
            sampleSizeArray: nil,
            sampleBufferOut: &sampleBuffer
        )
        
        guard let sBuffer = sampleBuffer else { return nil }
        
        // Copy data
        let status = CMSampleBufferSetDataBufferFromAudioBufferList(
            sBuffer,
            blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault,
            flags: 0,
            bufferList: buffer.audioBufferList
        )
        
        return status == noErr ? sBuffer : nil
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
        // Screen Recording (triggers prompt if needed)
        _ = try? await SCShareableContent.current
        
        // Microphone (triggers prompt if needed)
        await AVCaptureDevice.requestAccess(for: .audio)
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
        // We know we requested 48kHz Stereo, which connects to our player
        if let buffer = createPCMBuffer(from: sampleBuffer) {
            playerNode.scheduleBuffer(buffer)
            if !playerNode.isPlaying {
                playerNode.play()
            }
        }
    }
    
    private func createPCMBuffer(from sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else { return nil }
        let format = AVAudioFormat(cmAudioFormatDescription: formatDescription)
        
        let frames = AVAudioFrameCount(sampleBuffer.numSamples)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return nil }
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
