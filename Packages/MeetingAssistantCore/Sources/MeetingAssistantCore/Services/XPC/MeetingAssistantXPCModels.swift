import Foundation

/// Centralized data structures for XPC communication.
public struct MeetingAssistantXPCModels {
    
    /// Settings passed from the app to the XPC service.
    public struct AppSettings: Codable {
        public var diarization: Bool
        public var minSpeakers: Int
        public var maxSpeakers: Int
        public var numSpeakers: Int
        
        public init(diarization: Bool, minSpeakers: Int, maxSpeakers: Int, numSpeakers: Int) {
            self.diarization = diarization
            self.minSpeakers = minSpeakers
            self.maxSpeakers = maxSpeakers
            self.numSpeakers = numSpeakers
        }
    }
    
    /// Service status information returned by the XPC service.
    public struct ServiceStatus: Codable {
        public let status: String
        public let modelState: String
        public let modelLoaded: Bool
        public let device: String
        public let modelName: String
        public let uptimeSeconds: Double
        
        public init(status: String, modelState: String, modelLoaded: Bool, device: String, modelName: String, uptimeSeconds: Double) {
            self.status = status
            self.modelState = modelState
            self.modelLoaded = modelLoaded
            self.device = device
            self.modelName = modelName
            self.uptimeSeconds = uptimeSeconds
        }
    }
}
