import Foundation
import os.log

/// Client for communicating with the Python transcription service.
@MainActor
class TranscriptionClient {
    static let shared = TranscriptionClient()
    
    private let logger = Logger(subsystem: "MeetingAssistant", category: "TranscriptionClient")
    
    @UserDefaultsStorage("transcriptionServiceURL") private var baseURL = "http://127.0.0.1:8765"
    
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300 // 5 minutes for long transcriptions
        config.timeoutIntervalForResource = 600 // 10 minutes total
        session = URLSession(configuration: config)
    }
    
    /// Check if the transcription service is healthy.
    func healthCheck() async throws -> Bool {
        guard let url = URL(string: "\(baseURL)/health") else {
            throw TranscriptionError.invalidURL("\(baseURL)/health")
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return false
        }
        
        struct HealthResponse: Decodable {
            let status: String
            let modelLoaded: Bool
            let device: String
            
            enum CodingKeys: String, CodingKey {
                case status
                case modelLoaded = "model_loaded"
                case device
            }
        }
        
        let health = try JSONDecoder().decode(HealthResponse.self, from: data)
        logger.info("Service healthy. Model loaded: \(health.modelLoaded), Device: \(health.device)")
        
        return health.status == "healthy"
    }
    
    /// Fetch detailed service status.
    /// - Returns: ServiceStatusResponse with comprehensive service information.
    func fetchServiceStatus() async throws -> ServiceStatusResponse {
        guard let url = URL(string: "\(baseURL)/status") else {
            throw TranscriptionError.invalidURL("\(baseURL)/status")
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw TranscriptionError.serviceUnavailable
        }
        
        return try JSONDecoder().decode(ServiceStatusResponse.self, from: data)
    }
    
    /// Warm up the model by pre-loading it.
    func warmupModel() async throws {
        guard let url = URL(string: "\(baseURL)/warmup") else {
            throw TranscriptionError.invalidURL("\(baseURL)/warmup")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw TranscriptionError.warmupFailed
        }
        
        logger.info("Model warmup complete")
    }
    
    /// Transcribe an audio file.
    /// - Parameter audioURL: Path to the audio file (WAV, M4A, etc.)
    /// - Returns: Transcription response from the service
    func transcribe(audioURL: URL) async throws -> TranscriptionResponse {
        logger.info("Transcribing file: \(audioURL.lastPathComponent)")
        
        guard let url = URL(string: "\(baseURL)/transcribe") else {
            throw TranscriptionError.invalidURL("\(baseURL)/transcribe")
        }
        
        // Read audio file
        let audioData = try Data(contentsOf: audioURL)
        
        // Determine MIME type based on file extension
        let mimeType = mimeTypeForExtension(audioURL.pathExtension)
        
        // Create multipart form request
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Build multipart body
        var body = Data()
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"file\"; filename=\"\(audioURL.lastPathComponent)\"\r\n")
        body.appendString("Content-Type: \(mimeType)\r\n\r\n")
        body.append(audioData)
        body.appendString("\r\n--\(boundary)--\r\n")
        
        request.httpBody = body
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranscriptionError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("Transcription failed: \(errorMessage)")
            throw TranscriptionError.transcriptionFailed(errorMessage)
        }
        
        let result = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
        logger.info("Transcription complete: \(result.text.prefix(50))...")
        
        return result
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
        case "error": return .error
        default: return .unloaded
        }
    }
}

// MARK: - UserDefaultsStorage for non-View contexts

import SwiftUI

/// Custom property wrapper for UserDefaults access in non-View contexts.
/// Named differently from SwiftUI's @AppStorage to avoid conflicts.
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

// MARK: - Data Extension for Safe String Appending

private extension Data {
    /// Safely append a string to data, using UTF-8 encoding.
    /// Does nothing if string cannot be encoded (rare edge case).
    mutating func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

// MARK: - MIME Type Helper

/// Determine MIME type based on file extension.
/// - Parameter ext: File extension (without dot)
/// - Returns: MIME type string
private func mimeTypeForExtension(_ ext: String) -> String {
    switch ext.lowercased() {
    case "wav":
        return "audio/wav"
    case "m4a":
        return "audio/mp4"
    case "mp3":
        return "audio/mpeg"
    case "mp4":
        return "video/mp4"
    case "aac":
        return "audio/aac"
    case "flac":
        return "audio/flac"
    case "ogg":
        return "audio/ogg"
    default:
        return "application/octet-stream"
    }
}
