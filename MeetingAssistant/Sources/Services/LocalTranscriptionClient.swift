import Foundation
import os.log

/// Client for local transcription using FluidAudio.
@MainActor
class LocalTranscriptionClient {
    static let shared = LocalTranscriptionClient()
    
    private let logger = Logger(subsystem: "MeetingAssistant", category: "LocalTranscriptionClient")
    private let manager = FluidAIModelManager.shared
    
    private init() {}
    
    /// Initializes and warms up the model.
    func prepare() async {
        await manager.loadModels()
    }
    
    /// Transcribe an audio file locally.
    /// - Parameter audioURL: Path to the audio file.
    /// - Returns: TranscriptionResponse compatible with existing app logic.
    func transcribe(audioURL: URL) async throws -> TranscriptionResponse {
        logger.info("Starting local transcription for: \(audioURL.lastPathComponent)")
        
        // Ensure models are loaded
        if manager.modelState != .loaded {
            await manager.loadModels()
        }
        
        let startTime = Date()
        
        // Perform transcription
        let text = try await manager.transcribe(audioURL: audioURL)
        
        let duration = Date().timeIntervalSince(startTime)
        let processedAt = ISO8601DateFormatter().string(from: Date())
        
        // Map FluidAudio result to App response
        return TranscriptionResponse(
            text: text,
            language: "auto", 
            durationSeconds: duration,
            model: "parakeet-tdt-0.6b-v3-coreml",
            processedAt: processedAt
        )
    }
}
