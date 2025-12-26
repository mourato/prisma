import Foundation
import FluidAudio
import os.log

@preconcurrency import AVFoundation

/// Manages the lifecycle of FluidAudio models (Download, Load, Initialize).
@MainActor
class FluidAIModelManager: ObservableObject {
    static let shared = FluidAIModelManager()
    
    private let logger = Logger(subsystem: "MeetingAssistant", category: "FluidAIModelManager")
    
    @Published var modelState: ModelState = .unloaded
    @Published var progress: Double = 0.0
    
    private(set) var asrManager: AsrManager?
    
    enum ModelState: String {
        case unloaded
        case downloading
        case loading
        case loaded
        case error
    }
    
    private init() {}
    
    /// Loads the ASR models. Downloads them if not present.
    func loadModels() async {
        guard modelState != .loaded && modelState != .loading else { return }
        
        modelState = .downloading
        logger.info("Starting model download/load...")
        
        do {
            // Use v3 (Multilingual)
            let models = try await AsrModels.downloadAndLoad(version: .v3)
            
            modelState = .loading
            logger.info("Initializing ASR Manager...")
            
            // AsrManager initialization
            let manager = AsrManager(config: .default)
            try await manager.initialize(models: models)
            
            self.asrManager = manager
            modelState = .loaded
            logger.info("ASR Manager initialized successfully.")
            
        } catch {
            logger.error("Failed to load models: \(error.localizedDescription)")
            modelState = .error
        }
    }
    
    /// Transcribe audio from a URL
    /// Returns: Transcription text
    func transcribe(audioURL: URL) async throws -> String {
        guard let manager = asrManager, modelState == .loaded else {
            throw FluidError.modelNotLoaded
        }
        
        logger.info("Transcribing audio file: \(audioURL.path)")
        
        let audioFile = try AVAudioFile(forReading: audioURL)
        let format = audioFile.processingFormat
        let frameCount = AVAudioFrameCount(audioFile.length)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
             throw FluidError.audioReadFailed
        }
        
        try audioFile.read(into: buffer)
        
        // Convert to 16kHz
        let convertedBuffer = try convertTo16kHz(buffer: buffer)
        let samples = arrayFloat(from: convertedBuffer)
        
        let result = try await manager.transcribe(samples)
        return result.text
    }
    
    private func convertTo16kHz(buffer: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer {
        let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!
        
        if buffer.format.sampleRate == 16000 && buffer.format.channelCount == 1 {
             return buffer
        }
        
        let converter = AVAudioConverter(from: buffer.format, to: targetFormat)!
        let targetFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * targetFormat.sampleRate / buffer.format.sampleRate)
        
        guard let targetBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: targetFrameCapacity) else {
            throw FluidError.conversionFailed
        }
        
        var error: NSError?
        
        // Use a local capture that is technically unsafe but safe in this context because convert is synchronous
        // To appease the compiler, we can't easily make AVAudioPCMBuffer sendable.
        // But we can define the block.
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        
        converter.convert(to: targetBuffer, error: &error, withInputFrom: inputBlock)
        
        if let error = error {
            throw error
        }
        
        return targetBuffer
    }
    
    private func arrayFloat(from buffer: AVAudioPCMBuffer) -> [Float] {
        guard let channelData = buffer.floatChannelData else { return [] }
        let channelPointer = channelData[0]
        return Array(UnsafeBufferPointer(start: channelPointer, count: Int(buffer.frameLength)))
    }
}

enum FluidError: Error {
    case modelNotLoaded
    case audioReadFailed
    case conversionFailed
}
