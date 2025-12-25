import Foundation

/// Represents a completed transcription.
struct Transcription: Identifiable, Codable, Hashable {
    let id: UUID
    let meeting: Meeting
    let text: String
    let language: String
    let createdAt: Date
    let modelName: String
    
    init(
        id: UUID = UUID(),
        meeting: Meeting,
        text: String,
        language: String = "pt",
        createdAt: Date = Date(),
        modelName: String = "parakeet-tdt-0.6b-v3"
    ) {
        self.id = id
        self.meeting = meeting
        self.text = text
        self.language = language
        self.createdAt = createdAt
        self.modelName = modelName
    }
    
    /// Formatted date string for display.
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: createdAt)
    }
    
    /// Duration from meeting data.
    var formattedDuration: String {
        meeting.formattedDuration
    }
    
    /// Word count of transcription.
    var wordCount: Int {
        text.split(separator: " ").count
    }
    
    /// Preview of transcription text (first 100 chars).
    var preview: String {
        if text.count <= 100 {
            return text
        }
        return String(text.prefix(100)) + "..."
    }
}

/// Response from transcription API.
struct TranscriptionResponse: Codable {
    let text: String
    let language: String
    let durationSeconds: Double
    let model: String
    let processedAt: String
    
    enum CodingKeys: String, CodingKey {
        case text
        case language
        case durationSeconds = "duration_seconds"
        case model
        case processedAt = "processed_at"
    }
}
