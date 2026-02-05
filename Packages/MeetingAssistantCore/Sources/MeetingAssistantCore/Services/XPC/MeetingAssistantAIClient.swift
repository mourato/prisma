import Foundation
import OSLog
 
private let meetingAssistantAIClientLogger = Logger(subsystem: "MeetingAssistant", category: "AIClient")

private final class ContinuationGate<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, Error>?
    
    init(_ continuation: CheckedContinuation<T, Error>) {
        self.continuation = continuation
    }
    
    func resume(returning value: T) {
        lock.lock()
        defer { lock.unlock() }
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(returning: value)
    }
    
    func resume(throwing error: Error) {
        lock.lock()
        defer { lock.unlock() }
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(throwing: error)
    }
}

private func makeXPCProxyErrorHandler<T: Sendable>(
    context: String,
    gate: ContinuationGate<T>
) -> @Sendable (Error) -> Void {
    { error in
        meetingAssistantAIClientLogger.error(
            "XPC Proxy Error (\(context, privacy: .public)): \(error.localizedDescription, privacy: .public)"
        )
        gate.resume(throwing: error)
    }
}

/// Client for communicating with the MeetingAssistant AI XPC Service.
@MainActor
public class MeetingAssistantAIClient {
    public static let shared = MeetingAssistantAIClient()
    
    private var connection: NSXPCConnection?
    
    private init() {
        // Connection is setup lazily upon first use
    }
    
    private func setupConnection() {
        let conn = NSXPCConnection(serviceName: MeetingAssistantXPCConstants.serviceName)
        conn.remoteObjectInterface = NSXPCInterface(with: MeetingAssistantXPCProtocol.self)
        
        conn.interruptionHandler = {
            meetingAssistantAIClientLogger.error("XPC Connection Interrupted")
        }
        
        conn.invalidationHandler = { [weak self] in
            meetingAssistantAIClientLogger.error("XPC Connection Invalidated")
            Task { @MainActor in
                self?.connection = nil
            }
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
            let gate = ContinuationGate(continuation)
            
            let proxy = connection.remoteObjectProxyWithErrorHandler(
                makeXPCProxyErrorHandler(context: "Transcribe", gate: gate)
            ) as? MeetingAssistantXPCProtocol
            
            guard let service = proxy else {
                gate.resume(throwing: TranscriptionError.serviceUnavailable)
                return
            }
            
            service.transcribe(audioURL: audioURL, settingsData: settingsData) { data, error in
                if let error = error {
                    gate.resume(throwing: error)
                    return
                }
                
                guard let data = data else {
                    gate.resume(throwing: TranscriptionError.invalidResponse)
                    return
                }
                
                do {
                    let response = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
                    gate.resume(returning: response)
                } catch {
                    gate.resume(throwing: error)
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
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<MeetingAssistantXPCModels.ServiceStatus, Error>) in
            let gate = ContinuationGate(continuation)
            
            let proxy = connection.remoteObjectProxyWithErrorHandler(
                makeXPCProxyErrorHandler(context: "Status", gate: gate)
            ) as? MeetingAssistantXPCProtocol
            
            guard let service = proxy else {
                gate.resume(throwing: TranscriptionError.serviceUnavailable)
                return
            }
            
            service.fetchServiceStatus { data, error in
                if let error = error {
                    gate.resume(throwing: error)
                    return
                }
                
                guard let data = data else {
                    gate.resume(throwing: TranscriptionError.invalidResponse)
                    return
                }
                
                do {
                    let status = try JSONDecoder().decode(MeetingAssistantXPCModels.ServiceStatus.self, from: data)
                    gate.resume(returning: status)
                } catch {
                    gate.resume(throwing: error)
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
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let gate = ContinuationGate(continuation)
            
            let proxy = connection.remoteObjectProxyWithErrorHandler(
                makeXPCProxyErrorHandler(context: "Warmup", gate: gate)
            ) as? MeetingAssistantXPCProtocol
            
            guard let service = proxy else {
                gate.resume(throwing: TranscriptionError.serviceUnavailable)
                return
            }
            
            service.warmupModel { error in
                if let error = error {
                    gate.resume(throwing: error)
                } else {
                    gate.resume(returning: ())
                }
            }
        }
    }
}
