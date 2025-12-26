import Foundation

/// Represents a completed transcription.
public struct Transcription: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let meeting: Meeting

    /// Segments of the transcription with speaker identification.
    public let segments: [Segment]

    /// Primary text for display (processed if available, otherwise raw).
    public let text: String

    /// Original transcription from the ASR model.
    public let rawText: String

    /// Processed content from AI post-processing (nil if not processed).
    public var processedContent: String?

    /// ID of the prompt used for post-processing (nil if not processed).
    public var postProcessingPromptId: UUID?

    /// Title of the prompt used for post-processing (nil if not processed).
    public var postProcessingPromptTitle: String?

    public let language: String
    public let createdAt: Date
    public let modelName: String

    /// Full initializer with post-processing support.
    public init(
        id: UUID = UUID(),
        meeting: Meeting,
        segments: [Segment] = [],
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
        self.segments = segments
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
    public init(
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
            segments: [],
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
    public var isPostProcessed: Bool {
        processedContent != nil
    }

    /// Cached formatter for transcription dates.
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter
    }()

    /// Formatted date string for display.
    public var formattedDate: String {
        Self.dateFormatter.string(from: createdAt)
    }

    /// Duration from meeting data.
    public var formattedDuration: String {
        meeting.formattedDuration
    }

    /// Word count of transcription.
    public var wordCount: Int {
        text.split(separator: " ").count
    }

    /// Preview of transcription text (first 100 chars).
    public var preview: String {
        if text.count <= 100 {
            return text
        }
        return String(text.prefix(100)) + "..."
    }

    /// A segment of the transcription associated with a speaker.
    public struct Segment: Identifiable, Codable, Hashable, Sendable {
        public let id: UUID
        public let speaker: String
        public let text: String
        public let startTime: Double
        public let endTime: Double

        public init(
            id: UUID = UUID(),
            speaker: String,
            text: String,
            startTime: Double,
            endTime: Double
        ) {
            self.id = id
            self.speaker = speaker
            self.text = text
            self.startTime = startTime
            self.endTime = endTime
        }
    }
    /// Default string for unknown speaker.
    public static let unknownSpeaker = "Desconhecido"
}

/// Response from transcription API.
public struct TranscriptionResponse: Codable {
    public let text: String
    public let language: String
    public let durationSeconds: Double
    public let model: String
    public let processedAt: String
    public let segments: [Transcription.Segment]

    enum CodingKeys: String, CodingKey {
        case text
        case segments
        case language
        case durationSeconds = "duration_seconds"
        case model
        case processedAt = "processed_at"
    }

    public init(
        text: String,
        segments: [Transcription.Segment] = [],
        language: String,
        durationSeconds: Double,
        model: String,
        processedAt: String
    ) {
        self.text = text
        self.language = language
        self.durationSeconds = durationSeconds
        self.model = model
        self.processedAt = processedAt
        self.segments = segments
    }
}
