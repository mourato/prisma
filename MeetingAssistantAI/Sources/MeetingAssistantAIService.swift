import Foundation
import MeetingAssistantCore
import os.log

/// Implementation of the MeetingAssistant XPC Service.
class MeetingAssistantAIService: NSObject, MeetingAssistantXPCProtocol {
    
    private let logger = Logger(subsystem: "com.mourato.my-meeting-assistant.ai-service", category: "AIService")
    
    func transcribe(
        audioURL: URL,
        settingsData: Data,
        withReply reply: @escaping (Data?, Error?) -> Void
    ) {
        logger.info("XPC Request: Transcribe \(audioURL.lastPathComponent)")
        
        Task {
            do {
                // Decode settings using shared model
                let decoder = JSONDecoder()
                let settings = try decoder.decode(MeetingAssistantXPCModels.AppSettings.self, from: settingsData)
                
                // Perform transcription in the XPC process
                let result = try await LocalTranscriptionClient.shared.transcribe(
                    audioURL: audioURL,
                    isDiarizationEnabled: settings.diarization,
                    minSpeakers: settings.minSpeakers,
                    maxSpeakers: settings.maxSpeakers,
                    numSpeakers: settings.numSpeakers
                )
                
                let encoder = JSONEncoder()
                let data = try encoder.encode(result)
                reply(data, nil)
                
            } catch {
                logger.error("XPC Transcription failed: \(error.localizedDescription)")
                reply(nil, error)
            }
        }
    }
    
    func fetchServiceStatus(withReply reply: @escaping (Data?, Error?) -> Void) {
        Task {
            do {
                let manager = FluidAIModelManager.shared
                let currentState = manager.modelState
                
                let status = MeetingAssistantXPCModels.ServiceStatus(
                    status: currentState == .error ? "unhealthy" : "healthy",
                    modelState: currentState.rawValue,
                    modelLoaded: currentState == .loaded,
                    device: "ANE",
                    modelName: "parakeet-tdt-0.6b-v3",
                    uptimeSeconds: 0 // Could be tracked
                )
                
                let encoder = JSONEncoder()
                let data = try encoder.encode(status)
                reply(data, nil)
            } catch {
                reply(nil, error)
            }
        }
    }
    
    func warmupModel(withReply reply: @escaping (Error?) -> Void) {
        Task {
            do {
                await FluidAIModelManager.shared.loadModels()
                reply(nil)
            } catch {
                reply(error)
            }
        }
    }
}
