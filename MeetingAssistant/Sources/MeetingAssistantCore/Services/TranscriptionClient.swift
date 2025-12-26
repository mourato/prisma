import Foundation
import os.log
import Combine

/// Client for communicating with the local FluidAudio transcription service.
/// Adapts the local model manager to the existing client interface.
@MainActor
class TranscriptionClient {
    static let shared = TranscriptionClient()
    
    private let logger = Logger(subsystem: "MeetingAssistant", category: "TranscriptionClient")
    private let manager = FluidAIModelManager.shared
    
    // We observe the manager to update our synthetic "ServiceStatus" if needed,
    // but the fetchServiceStatus() method is pull-based, so we can just compute it on demand.
    
    private init() {
        Task {
            // Pre-load models on init (or we can wait for explicit warmup)
            await manager.loadModels()
        }
    }
    
    /// Check if the transcription service is healthy (local model manager).
    func healthCheck() async throws -> Bool {
        // Local service is always "healthy" if the app is running,
        // unless the model failed to load.
        // We trigger a load check if needed.
        if manager.modelState == .error {
            return false
        }
        return true
    }
    
    /// Fetch detailed service status.
    /// - Returns: ServiceStatusResponse with comprehensive service information.
    func fetchServiceStatus() async throws -> ServiceStatusResponse {
        // Construct a response based on local manager state
        
        let currentState = manager.modelState
        let isLoaded = currentState == .loaded
        
        // Map local state to the expected JSON response format
        // Logic:
        // - status: "healthy" if not error
        // - model_state: internal state string
        // - model_loaded: boolean
        // - device: "ANE" (since FluidAudio targets ANE)
        
        // Calculate uptime / stats if available (omitted for now or mocked)
        
        return ServiceStatusResponse(
            status: currentState == .error ? "unhealthy" : "healthy",
            modelState: currentState.rawValue,
            modelLoaded: isLoaded,
            device: "ANE", // FluidAudio uses Apple Neural Engine
            modelName: "parakeet-tdt-0.6b-v3",
            uptimeSeconds: 0,
            lastTranscriptionTime: nil,
            totalTranscriptions: 0,
            totalAudioProcessedSeconds: 0
        )
    }
    
    /// Warm up the model by pre-loading it.
    func warmupModel() async throws {
        await manager.loadModels()
    }
    
    /// Transcribe an audio file.
    /// - Parameter audioURL: Path to the audio file (WAV, M4A, etc.)
    /// - Returns: Transcription response from the service
    func transcribe(audioURL: URL) async throws -> TranscriptionResponse {
        logger.info("Transcribing file locally: \(audioURL.lastPathComponent)")
        
        
        // Use the manager to transcribe
        // Note: manager.transcribe returns a FluidAudio result, but we shouldn't access it directly here
        // to avoid tight coupling if possible?
        // Actually, LocalTranscriptionClient does this mapping. Let's reuse Logic from LocalTranscriptionClient
        // or just implement it here since TranscriptionClient IS the client now.
        
        // Wait, I created LocalTranscriptionClient. I should probably use it or merge it.
        // LocalTranscriptionClient matches the app usage pretty well.
        // I will delegate to LocalTranscriptionClient or just inline the logic since TranscriptionClient is the main entry point.
        // Let's use LocalTranscriptionClient as the implementation provider.
        
        return try await LocalTranscriptionClient.shared.transcribe(audioURL: audioURL)
    }
}

// MARK: - Errors

enum TranscriptionError: LocalizedError {
    case serviceUnavailable
    case warmupFailed
    case invalidResponse
    case invalidURL(String)
    case transcriptionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .serviceUnavailable:
            return "Serviço de transcrição não disponível"
        case .warmupFailed:
            return "Falha ao pré-carregar modelo"
        case .invalidResponse:
            return "Resposta inválida do serviço"
        case .invalidURL(let urlString):
            return "URL inválida: \(urlString)"
        case .transcriptionFailed(let message):
            return "Falha na transcrição: \(message)"
        }
    }
}

// MARK: - Service Status Response

/// Response from the /status endpoint with detailed service information.
struct ServiceStatusResponse: Codable {
    let status: String
    let modelState: String
    let modelLoaded: Bool
    let device: String
    let modelName: String
    let uptimeSeconds: Double
    let lastTranscriptionTime: String?
    let totalTranscriptions: Int
    let totalAudioProcessedSeconds: Double
    
    enum CodingKeys: String, CodingKey {
        case status
        case modelState = "model_state"
        case modelLoaded = "model_loaded"
        case device
        case modelName = "model_name"
        case uptimeSeconds = "uptime_seconds"
        case lastTranscriptionTime = "last_transcription_time"
        case totalTranscriptions = "total_transcriptions"
        case totalAudioProcessedSeconds = "total_audio_processed_seconds"
    }
    
    /// Convert model state string to ModelState enum.
    var modelStateEnum: ModelState {
        switch modelState {
        case "loaded": return .loaded
        case "loading": return .loading
        case "downloading": return .downloading
        case "error": return .error
        default: return .unloaded
        }
    }
}

// MARK: - UserDefaultsStorage for non-View contexts
// (Kept if needed for other settings, though baseURL is no longer used)

import SwiftUI

@propertyWrapper
struct UserDefaultsStorage<Value> {
    private let key: String
    private let defaultValue: Value
    
    init(wrappedValue: Value, _ key: String) {
        self.key = key
        self.defaultValue = wrappedValue
    }
    
    var wrappedValue: Value {
        get {
            UserDefaults.standard.object(forKey: key) as? Value ?? defaultValue
        }
        set {
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }
}
