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
    public let language: String
    public let isPostProcessed: Bool
    public let duration: TimeInterval
    public let audioFilePath: String?

    public init(
        id: UUID,
        meetingId: UUID,
        appName: String,
        appRawValue: String,
        startTime: Date,
        createdAt: Date,
        previewText: String,
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
        self.language = language
        self.isPostProcessed = isPostProcessed
        self.duration = duration
        self.audioFilePath = audioFilePath
    }
}
