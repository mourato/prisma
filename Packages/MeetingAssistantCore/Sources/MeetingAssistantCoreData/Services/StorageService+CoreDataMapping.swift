import Foundation
import MeetingAssistantCoreDomain

extension FileSystemStorageService {
    // MARK: - Core Data helpers

    static func convertToEntity(_ transcription: Transcription) -> TranscriptionEntity {
        let meetingEntity = MeetingEntity(
            id: transcription.meeting.id,
            app: DomainMeetingApp(rawValue: transcription.meeting.app.rawValue) ?? .unknown,
            appBundleIdentifier: transcription.meeting.appBundleIdentifier,
            appDisplayName: transcription.meeting.appDisplayName,
            title: transcription.meeting.title,
            linkedCalendarEvent: transcription.meeting.linkedCalendarEvent,
            startTime: transcription.meeting.startTime,
            endTime: transcription.meeting.endTime,
            audioFilePath: transcription.meeting.audioFilePath
        )

        let segments = transcription.segments.map { segment in
            TranscriptionEntity.Segment(
                id: segment.id,
                speaker: segment.speaker,
                text: segment.text,
                startTime: segment.startTime,
                endTime: segment.endTime
            )
        }

        var config = TranscriptionEntity.Configuration(
            text: transcription.text,
            rawText: transcription.rawText,
            segments: segments,
            language: transcription.language
        )
        config.id = transcription.id
        config.contextItems = transcription.contextItems
        config.processedContent = transcription.processedContent
        config.canonicalSummary = transcription.canonicalSummary
        config.qualityProfile = transcription.qualityProfile
        config.postProcessingPromptId = transcription.postProcessingPromptId
        config.postProcessingPromptTitle = transcription.postProcessingPromptTitle
        config.createdAt = transcription.createdAt
        config.modelName = transcription.modelName
        config.inputSource = transcription.inputSource
        config.transcriptionDuration = transcription.transcriptionDuration
        config.postProcessingDuration = transcription.postProcessingDuration
        config.postProcessingModel = transcription.postProcessingModel
        config.meetingType = transcription.meetingType
        config.meetingConversationState = transcription.meetingConversationState

        return TranscriptionEntity(meeting: meetingEntity, config: config)
    }

    static func convertToMetadata(_ mo: TranscriptionMO) -> TranscriptionMetadata {
        let wordCount = wordCount(for: mo.text)
        let fallbackName = MeetingApp(rawValue: mo.meeting.appRawValue)?.displayName ?? mo.meeting.appRawValue
        let trimmedDisplayName = mo.meeting.appDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = (trimmedDisplayName?.isEmpty == false) ? trimmedDisplayName! : fallbackName

        return TranscriptionMetadata(
            id: mo.id,
            meetingId: mo.meeting.id,
            meetingTitle: mo.meeting.title,
            appName: resolvedName,
            appRawValue: mo.meeting.appRawValue,
            appBundleIdentifier: mo.meeting.appBundleIdentifier,
            startTime: mo.meeting.startTime,
            createdAt: mo.createdAt,
            previewText: String(mo.text.prefix(100)),
            wordCount: wordCount,
            language: mo.language,
            isPostProcessed: mo.processedContent != nil,
            duration: mo.meeting.endTime?.timeIntervalSince(mo.meeting.startTime) ?? 0,
            audioFilePath: mo.meeting.audioFilePath,
            inputSource: mo.inputSource,
            summarySchemaVersion: Int(mo.canonicalSummarySchemaVersion),
            summaryGroundedInTranscript: mo.summaryGroundedInTranscript,
            summaryContainsSpeculation: mo.summaryContainsSpeculation,
            summaryHumanReviewed: mo.summaryHumanReviewed,
            summaryConfidenceScore: mo.summaryConfidenceScore,
            transcriptConfidenceScore: mo.transcriptConfidenceScore,
            transcriptContainsUncertainty: mo.transcriptContainsUncertainty
        )
    }

    static func convertToModel(_ entity: TranscriptionEntity) -> Transcription {
        let meeting = Meeting(
            id: entity.meeting.id,
            app: MeetingApp(rawValue: entity.meeting.app.rawValue) ?? .unknown,
            appBundleIdentifier: entity.meeting.appBundleIdentifier,
            appDisplayName: entity.meeting.appDisplayName,
            title: entity.meeting.title,
            linkedCalendarEvent: entity.meeting.linkedCalendarEvent,
            startTime: entity.meeting.startTime,
            endTime: entity.meeting.endTime,
            audioFilePath: entity.meeting.audioFilePath
        )

        let segments = entity.segments.map { segment in
            Transcription.Segment(
                id: segment.id,
                speaker: segment.speaker,
                text: segment.text,
                startTime: segment.startTime,
                endTime: segment.endTime
            )
        }

        return Transcription(
            id: entity.id,
            meeting: meeting,
            contextItems: entity.contextItems,
            segments: segments,
            text: entity.text,
            rawText: entity.rawText,
            processedContent: entity.processedContent,
            canonicalSummary: entity.canonicalSummary,
            qualityProfile: entity.qualityProfile,
            postProcessingPromptId: entity.postProcessingPromptId,
            postProcessingPromptTitle: entity.postProcessingPromptTitle,
            language: entity.language,
            createdAt: entity.createdAt,
            modelName: entity.modelName,
            inputSource: entity.inputSource,
            transcriptionDuration: entity.transcriptionDuration,
            postProcessingDuration: entity.postProcessingDuration,
            postProcessingModel: entity.postProcessingModel,
            meetingType: entity.meetingType,
            meetingConversationState: entity.meetingConversationState
        )
    }
}
