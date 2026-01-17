import Foundation

/// Unified protocol for AI service providers (transcription, post-processing)
public protocol AIInfrastructureProvider: Sendable {
    /// Provider identifier for logging and analytics
    var providerName: String { get }

    /// Check if the service is available
    func healthCheck() async throws -> Bool

    /// Transcribe audio file to text
    func transcribe(audioURL: URL, language: String?) async throws -> AITranscriptionResult

    /// Process text with AI (summarization, formatting, etc.)
    func processText(_ text: String, prompt: String) async throws -> String
}

/// Transcription result from any AI provider
public struct AITranscriptionResult: Codable, Sendable {
    public let text: String
    public let language: String
    public let durationSeconds: Double
    public let segments: [AITranscriptionSegment]
    public let model: String

    public init(text: String, language: String, durationSeconds: Double, segments: [AITranscriptionSegment], model: String) {
        self.text = text
        self.language = language
        self.durationSeconds = durationSeconds
        self.segments = segments
        self.model = model
    }
}

public struct AITranscriptionSegment: Codable, Sendable {
    public let id: UUID
    public let speaker: String?
    public let text: String
    public let startTime: Double
    public let endTime: Double

    public init(id: UUID = UUID(), speaker: String?, text: String, startTime: Double, endTime: Double) {
        self.id = id
        self.speaker = speaker
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
    }
}
