import Foundation

/// Represents a completed transcription.
struct Transcription: Identifiable, Codable, Hashable {
    let id: UUID
    let meeting: Meeting
    
    /// Primary text for display (processed if available, otherwise raw).
    let text: String
    
    /// Original transcription from the ASR model.
    let rawText: String
    
    /// Processed content from AI post-processing (nil if not processed).
    var processedContent: String?
    
    /// ID of the prompt used for post-processing (nil if not processed).
    var postProcessingPromptId: UUID?
    
    /// Title of the prompt used for post-processing (nil if not processed).
    var postProcessingPromptTitle: String?
    
    let language: String
    let createdAt: Date
    let modelName: String
    
    /// Full initializer with post-processing support.
    init(
        id: UUID = UUID(),
        meeting: Meeting,
        text: String,
        rawText: String,
        processedContent: String? = nil,
        postProcessingPromptId: UUID? = nil,
        postProcessingPromptTitle: String? = nil,
        language: String = "pt",
        createdAt: Date = Date(),
        modelName: String = "parakeet-tdt-0.6b-v3"
    ) {
        self.id = id
        self.meeting = meeting
        self.text = text
        self.rawText = rawText
        self.processedContent = processedContent
        self.postProcessingPromptId = postProcessingPromptId
        self.postProcessingPromptTitle = postProcessingPromptTitle
        self.language = language
        self.createdAt = createdAt
        self.modelName = modelName
    }
    
    /// Convenience initializer for backward compatibility (no post-processing).
    init(
        id: UUID = UUID(),
        meeting: Meeting,
        text: String,
        language: String = "pt",
        createdAt: Date = Date(),
        modelName: String = "parakeet-tdt-0.6b-v3"
    ) {
        self.init(
            id: id,
            meeting: meeting,
            text: text,
            rawText: text,
            processedContent: nil,
            postProcessingPromptId: nil,
            postProcessingPromptTitle: nil,
            language: language,
            createdAt: createdAt,
            modelName: modelName
        )
    }
    
    /// Whether this transcription was post-processed.
    var isPostProcessed: Bool {
        processedContent != nil
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
