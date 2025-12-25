import Foundation
import os.log

/// Client for communicating with the Python transcription service.
class TranscriptionClient {
    static let shared = TranscriptionClient()
    
    private let logger = Logger(subsystem: "MeetingAssistant", category: "TranscriptionClient")
    
    @AppStorage("transcriptionServiceURL") private var baseURL = "http://127.0.0.1:8765"
    
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300 // 5 minutes for long transcriptions
        config.timeoutIntervalForResource = 600 // 10 minutes total
        session = URLSession(configuration: config)
    }
    
    /// Check if the transcription service is healthy.
    func healthCheck() async throws -> Bool {
        let url = URL(string: "\(baseURL)/health")!
        
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
    
    /// Warm up the model by pre-loading it.
    func warmupModel() async throws {
        let url = URL(string: "\(baseURL)/warmup")!
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
    /// - Parameter audioURL: Path to the WAV file
    /// - Returns: Transcription response from the service
    func transcribe(audioURL: URL) async throws -> TranscriptionResponse {
        logger.info("Transcribing file: \(audioURL.lastPathComponent)")
        
        let url = URL(string: "\(baseURL)/transcribe")!
        
        // Read audio file
        let audioData = try Data(contentsOf: audioURL)
        
        // Create multipart form request
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Build multipart body
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(audioURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
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
    case transcriptionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .serviceUnavailable:
            return "Serviço de transcrição não disponível"
        case .warmupFailed:
            return "Falha ao pré-carregar modelo"
        case .invalidResponse:
            return "Resposta inválida do serviço"
        case .transcriptionFailed(let message):
            return "Falha na transcrição: \(message)"
        }
    }
}

// MARK: - AppStorage workaround for non-View contexts

import SwiftUI

@propertyWrapper
struct AppStorage<Value> {
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
