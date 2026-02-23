import Foundation

/// Lightweight representation of a transcription for list display and filtering.
public struct TranscriptionMetadata: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let meetingId: UUID
    public let appName: String
    public let appRawValue: String
    public let appBundleIdentifier: String?
    public let startTime: Date
    public let createdAt: Date
    public let previewText: String
    public let wordCount: Int
    public let language: String
    public let isPostProcessed: Bool
    public let duration: TimeInterval
    public let audioFilePath: String?
    public let inputSource: String?
    public let summarySchemaVersion: Int
    public let summaryGroundedInTranscript: Bool
    public let summaryContainsSpeculation: Bool
    public let summaryHumanReviewed: Bool
    public let summaryConfidenceScore: Double
    public let transcriptConfidenceScore: Double
    public let transcriptContainsUncertainty: Bool

    public var meetingApp: MeetingApp {
        MeetingApp(rawValue: appRawValue) ?? .unknown
    }

    /// Whether meeting-only conversation features should be enabled.
    public var supportsMeetingConversation: Bool {
        meetingApp.supportsMeetingConversation
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case meetingId
        case appName
        case appRawValue
        case appBundleIdentifier
        case startTime
        case createdAt
        case previewText
        case wordCount
        case language
        case isPostProcessed
        case duration
        case audioFilePath
        case inputSource
        case summarySchemaVersion
        case summaryGroundedInTranscript
        case summaryContainsSpeculation
        case summaryHumanReviewed
        case summaryConfidenceScore
        case transcriptConfidenceScore
        case transcriptContainsUncertainty
    }

    public init(
        id: UUID,
        meetingId: UUID,
        appName: String,
        appRawValue: String,
        appBundleIdentifier: String?,
        startTime: Date,
        createdAt: Date,
        previewText: String,
        wordCount: Int,
        language: String,
        isPostProcessed: Bool,
        duration: TimeInterval,
        audioFilePath: String?,
        inputSource: String?,
        summarySchemaVersion: Int = 0,
        summaryGroundedInTranscript: Bool = false,
        summaryContainsSpeculation: Bool = false,
        summaryHumanReviewed: Bool = false,
        summaryConfidenceScore: Double = 0.0,
        transcriptConfidenceScore: Double = 0.5,
        transcriptContainsUncertainty: Bool = false
    ) {
        self.id = id
        self.meetingId = meetingId
        self.appName = appName
        self.appRawValue = appRawValue
        self.appBundleIdentifier = appBundleIdentifier
        self.startTime = startTime
        self.createdAt = createdAt
        self.previewText = previewText
        self.wordCount = wordCount
        self.language = language
        self.isPostProcessed = isPostProcessed
        self.duration = duration
        self.audioFilePath = audioFilePath
        self.inputSource = inputSource
        self.summarySchemaVersion = summarySchemaVersion
        self.summaryGroundedInTranscript = summaryGroundedInTranscript
        self.summaryContainsSpeculation = summaryContainsSpeculation
        self.summaryHumanReviewed = summaryHumanReviewed
        self.summaryConfidenceScore = summaryConfidenceScore
        self.transcriptConfidenceScore = transcriptConfidenceScore
        self.transcriptContainsUncertainty = transcriptContainsUncertainty
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let id = try container.decode(UUID.self, forKey: .id)
        let meetingId = try container.decode(UUID.self, forKey: .meetingId)
        let appName = try container.decode(String.self, forKey: .appName)
        let appRawValue = try container.decode(String.self, forKey: .appRawValue)
        let appBundleIdentifier = try container.decodeIfPresent(String.self, forKey: .appBundleIdentifier)
        let startTime = try container.decode(Date.self, forKey: .startTime)
        let createdAt = try container.decode(Date.self, forKey: .createdAt)
        let previewText = try container.decode(String.self, forKey: .previewText)
        let wordCount = try container.decodeIfPresent(Int.self, forKey: .wordCount) ?? 0
        let language = try container.decode(String.self, forKey: .language)
        let isPostProcessed = try container.decode(Bool.self, forKey: .isPostProcessed)
        let duration = try container.decode(TimeInterval.self, forKey: .duration)
        let audioFilePath = try container.decodeIfPresent(String.self, forKey: .audioFilePath)
        let inputSource = try container.decodeIfPresent(String.self, forKey: .inputSource)
        let summarySchemaVersion = try container.decodeIfPresent(Int.self, forKey: .summarySchemaVersion) ?? 0
        let summaryGroundedInTranscript = try container.decodeIfPresent(Bool.self, forKey: .summaryGroundedInTranscript) ?? false
        let summaryContainsSpeculation = try container.decodeIfPresent(Bool.self, forKey: .summaryContainsSpeculation) ?? false
        let summaryHumanReviewed = try container.decodeIfPresent(Bool.self, forKey: .summaryHumanReviewed) ?? false
        let summaryConfidenceScore = try container.decodeIfPresent(Double.self, forKey: .summaryConfidenceScore) ?? 0.0
        let transcriptConfidenceScore = try container.decodeIfPresent(Double.self, forKey: .transcriptConfidenceScore) ?? 0.5
        let transcriptContainsUncertainty = try container.decodeIfPresent(Bool.self, forKey: .transcriptContainsUncertainty) ?? false

        self.init(
            id: id,
            meetingId: meetingId,
            appName: appName,
            appRawValue: appRawValue,
            appBundleIdentifier: appBundleIdentifier,
            startTime: startTime,
            createdAt: createdAt,
            previewText: previewText,
            wordCount: wordCount,
            language: language,
            isPostProcessed: isPostProcessed,
            duration: duration,
            audioFilePath: audioFilePath,
            inputSource: inputSource,
            summarySchemaVersion: summarySchemaVersion,
            summaryGroundedInTranscript: summaryGroundedInTranscript,
            summaryContainsSpeculation: summaryContainsSpeculation,
            summaryHumanReviewed: summaryHumanReviewed,
            summaryConfidenceScore: summaryConfidenceScore,
            transcriptConfidenceScore: transcriptConfidenceScore,
            transcriptContainsUncertainty: transcriptContainsUncertainty
        )
    }
}

/// Query options for loading transcription metadata directly from persistence.
public struct TranscriptionMetadataQuery: Hashable, Sendable {
    public let sourceFilter: RecordingSourceFilter
    public let dateFilter: DateFilter
    public let searchText: String
    public let appRawValue: String?

    public init(
        sourceFilter: RecordingSourceFilter = .all,
        dateFilter: DateFilter = .allEntries,
        searchText: String = "",
        appRawValue: String? = nil
    ) {
        self.sourceFilter = sourceFilter
        self.dateFilter = dateFilter
        self.searchText = searchText
        self.appRawValue = appRawValue
    }
}
