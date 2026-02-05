import Foundation
import os.log

/// Client for communicating with the MeetingAssistant AI XPC Service.
@MainActor
public class MeetingAssistantAIClient {
    public static let shared = MeetingAssistantAIClient()
    
    private var connection: NSXPCConnection?
    private let logger = Logger(subsystem: "MeetingAssistant", category: "AIClient")
    
    private init() {
        // Connection is setup lazily upon first use
    }
    
    private func setupConnection() {
        let conn = NSXPCConnection(serviceName: MeetingAssistantXPCConstants.serviceName)
        conn.remoteObjectInterface = NSXPCInterface(with: MeetingAssistantXPCProtocol.self)
        
        conn.interruptionHandler = { [weak self] in
            self?.logger.error("XPC Connection Interrupted")
        }
        
        conn.invalidationHandler = { [weak self] in
            self?.logger.error("XPC Connection Invalidated")
            // Note: self?.connection = nil causes a cycle/worker issue if not careful with actors
        }
        
        conn.resume()
        self.connection = conn
    }
    
    /// Transcribes an audio file using the XPC Service.
    public func transcribe(audioURL: URL) async throws -> TranscriptionResponse {
        guard let connection = connection else {
            setupConnection()
            return try await transcribe(audioURL: audioURL)
        }
        
        let proxy = connection.remoteObjectProxyWithErrorHandler { error in
            self.logger.error("XPC Proxy Error: \(error.localizedDescription)")
        } as? MeetingAssistantXPCProtocol
        
        guard let service = proxy else {
            throw TranscriptionError.serviceUnavailable
        }
        
        // Prepare settings from AppSettingsStore using shared model
        let store = AppSettingsStore.shared
        let settings = MeetingAssistantXPCModels.AppSettings(
            diarization: store.isDiarizationEnabled,
            minSpeakers: store.minSpeakers ?? 1,
            maxSpeakers: store.maxSpeakers ?? 10,
            numSpeakers: store.numSpeakers ?? 0
        )
        let settingsData = try JSONEncoder().encode(settings)
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<TranscriptionResponse, Error>) in
            service.transcribe(audioURL: audioURL, settingsData: settingsData) { data, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let data = data else {
                    continuation.resume(throwing: TranscriptionError.invalidResponse)
                    return
                }
                
                do {
                    let response = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
                    continuation.resume(returning: response)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Fetches the status of the AI service.
    public func fetchServiceStatus() async throws -> MeetingAssistantXPCModels.ServiceStatus {
        guard let connection = connection else {
            setupConnection()
            return try await fetchServiceStatus()
        }
        
        let proxy = connection.remoteObjectProxyWithErrorHandler { error in
            self.logger.error("XPC Proxy Error (Status): \(error.localizedDescription)")
        } as? MeetingAssistantXPCProtocol
        
        guard let service = proxy else {
            throw TranscriptionError.serviceUnavailable
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            service.fetchServiceStatus { data, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let data = data else {
                    continuation.resume(throwing: TranscriptionError.invalidResponse)
                    return
                }
                
                do {
                    let status = try JSONDecoder().decode(MeetingAssistantXPCModels.ServiceStatus.self, from: data)
                    continuation.resume(returning: status)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Warms up the models in the XPC service.
    public func warmupModel() async throws {
        guard let connection = connection else {
            setupConnection()
            return try await warmupModel()
        }
        
        let proxy = connection.remoteObjectProxyWithErrorHandler { error in
            self.logger.error("XPC Proxy Error (Warmup): \(error.localizedDescription)")
        } as? MeetingAssistantXPCProtocol
        
        guard let service = proxy else {
            throw TranscriptionError.serviceUnavailable
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            service.warmupModel { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}
