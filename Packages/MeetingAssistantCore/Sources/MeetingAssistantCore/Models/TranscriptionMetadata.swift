import Foundation

/// Lightweight representation of a transcription for list display and filtering.
public struct TranscriptionMetadata: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let meetingId: UUID
    public let appName: String
    public let appRawValue: String
    public let startTime: Date
    public let createdAt: Date
    public let previewText: String
    public let wordCount: Int
    public let language: String
    public let isPostProcessed: Bool
    public let duration: TimeInterval
    public let audioFilePath: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case meetingId
        case appName
        case appRawValue
        case startTime
        case createdAt
        case previewText
        case wordCount
        case language
        case isPostProcessed
        case duration
        case audioFilePath
    }

    public init(
        id: UUID,
        meetingId: UUID,
        appName: String,
        appRawValue: String,
        startTime: Date,
        createdAt: Date,
        previewText: String,
        wordCount: Int,
        language: String,
        isPostProcessed: Bool,
        duration: TimeInterval,
        audioFilePath: String?
    ) {
        self.id = id
        self.meetingId = meetingId
        self.appName = appName
        self.appRawValue = appRawValue
        self.startTime = startTime
        self.createdAt = createdAt
        self.previewText = previewText
        self.wordCount = wordCount
        self.language = language
        self.isPostProcessed = isPostProcessed
        self.duration = duration
        self.audioFilePath = audioFilePath
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let id = try container.decode(UUID.self, forKey: .id)
        let meetingId = try container.decode(UUID.self, forKey: .meetingId)
        let appName = try container.decode(String.self, forKey: .appName)
        let appRawValue = try container.decode(String.self, forKey: .appRawValue)
        let startTime = try container.decode(Date.self, forKey: .startTime)
        let createdAt = try container.decode(Date.self, forKey: .createdAt)
        let previewText = try container.decode(String.self, forKey: .previewText)
        let wordCount = try container.decodeIfPresent(Int.self, forKey: .wordCount) ?? 0
        let language = try container.decode(String.self, forKey: .language)
        let isPostProcessed = try container.decode(Bool.self, forKey: .isPostProcessed)
        let duration = try container.decode(TimeInterval.self, forKey: .duration)
        let audioFilePath = try container.decodeIfPresent(String.self, forKey: .audioFilePath)

        self.init(
            id: id,
            meetingId: meetingId,
            appName: appName,
            appRawValue: appRawValue,
            startTime: startTime,
            createdAt: createdAt,
            previewText: previewText,
            wordCount: wordCount,
            language: language,
            isPostProcessed: isPostProcessed,
            duration: duration,
            audioFilePath: audioFilePath
        )
    }
}
