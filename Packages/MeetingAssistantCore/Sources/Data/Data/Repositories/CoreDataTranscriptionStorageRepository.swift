import MeetingAssistantCoreDomain

// CoreDataTranscriptionStorageRepository - Implementação de TranscriptionStorageRepository usando CoreData
// Thread-safe e isolado do domínio

import CoreData
import Foundation

/// Repositório de transcrições usando CoreData para persistência
public final class CoreDataTranscriptionStorageRepository: TranscriptionStorageRepository {
    private let stack: CoreDataStack

    public init(stack: CoreDataStack = .shared) {
        self.stack = stack
    }

    private func sanitizePersistentHistoryIfNeeded() async {
        await stack.sanitizeMockTranscriptionArtifactsIfNeeded()
        await stack.sanitizeMeetingOnlyPresentationDataIfNeeded()
    }

    public func saveTranscription(_ transcription: TranscriptionEntity) async throws {
        await sanitizePersistentHistoryIfNeeded()
        try validateCanonicalSummary(for: transcription)
        let sanitizedTranscription = Self.sanitizedTranscriptionEntity(from: transcription)
        try await stack.performBackgroundTask { context in
            let meetingRequest = MeetingMO.fetchRequest(for: sanitizedTranscription.meeting.id)
            let meetingMO = try context.fetch(meetingRequest).first ?? MeetingMO.create(from: sanitizedTranscription.meeting, in: context)
            meetingMO.update(from: sanitizedTranscription.meeting)

            let transcriptionRequest = TranscriptionMO.fetchRequest(forTranscriptionId: sanitizedTranscription.id)
            if let existing = try context.fetch(transcriptionRequest).first {
                existing.update(from: sanitizedTranscription, meeting: meetingMO)
            } else {
                _ = TranscriptionMO.create(from: sanitizedTranscription, meeting: meetingMO, in: context)
            }
            try context.save()
        }
    }

    public func fetchTranscription(by id: UUID) async throws -> TranscriptionEntity? {
        await sanitizePersistentHistoryIfNeeded()
        return try await stack.performBackgroundTask { context in
            let request = TranscriptionMO.fetchRequest(forTranscriptionId: id)
            let result = try context.fetch(request)
            return result.first.map { Self.sanitizedTranscriptionEntity(from: $0.toDomain()) }
        }
    }

    public func fetchTranscriptions(for meetingId: UUID) async throws -> [TranscriptionEntity] {
        await sanitizePersistentHistoryIfNeeded()
        return try await stack.performBackgroundTask { context in
            let request = TranscriptionMO.fetchRequest(forMeetingId: meetingId)
            let results = try context.fetch(request)
            return results.map { Self.sanitizedTranscriptionEntity(from: $0.toDomain()) }
        }
    }

    public func fetchAllTranscriptions() async throws -> [TranscriptionEntity] {
        await sanitizePersistentHistoryIfNeeded()
        return try await stack.performBackgroundTask { context in
            let request = TranscriptionMO.visibleHistoryFetchRequest()
            let results = try context.fetch(request)
            return results.map { Self.sanitizedTranscriptionEntity(from: $0.toDomain()) }
        }
    }

    public func fetchAllMetadata() async throws -> [DomainTranscriptionMetadata] {
        await sanitizePersistentHistoryIfNeeded()
        return try await stack.performBackgroundTask { context in
            let request = TranscriptionMO.visibleHistoryFetchRequest()
            let results = try context.fetch(request)
            return results.map { mo in
                let fallbackName = DomainMeetingApp(rawValue: mo.meeting.appRawValue)?.displayName ?? "Unknown"
                let trimmedDisplayName = mo.meeting.appDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines)
                let resolvedName = (trimmedDisplayName?.isEmpty == false) ? trimmedDisplayName! : fallbackName
                return DomainTranscriptionMetadata(
                    id: mo.id,
                    meetingId: mo.meeting.id,
                    meetingTitle: mo.meeting.preferredTitle,
                    appName: resolvedName,
                    appRawValue: mo.meeting.appRawValue,
                    capturePurpose: mo.meeting.capturePurpose,
                    appBundleIdentifier: mo.meeting.appBundleIdentifier,
                    startTime: mo.meeting.startTime,
                    createdAt: mo.createdAt,
                    previewText: String(mo.text.prefix(100)),
                    language: mo.language,
                    isPostProcessed: mo.processedContent != nil,
                    duration: mo.meeting.endTime?.timeIntervalSince(mo.meeting.startTime) ?? 0,
                    audioFilePath: mo.meeting.audioFilePath,
                    lifecycleState: TranscriptionLifecycleState(rawValue: mo.lifecycleStateRawValue) ?? .completed,
                    summarySchemaVersion: Int(mo.canonicalSummarySchemaVersion),
                    summaryGroundedInTranscript: mo.summaryGroundedInTranscript,
                    summaryContainsSpeculation: mo.summaryContainsSpeculation,
                    summaryHumanReviewed: mo.summaryHumanReviewed,
                    summaryConfidenceScore: mo.summaryConfidenceScore,
                    transcriptConfidenceScore: mo.transcriptConfidenceScore,
                    transcriptContainsUncertainty: mo.transcriptContainsUncertainty
                )
            }
        }
    }

    public func deleteTranscription(by id: UUID) async throws {
        try await stack.performBackgroundTask { context in
            let request = TranscriptionMO.fetchRequest(forTranscriptionId: id)
            if let transcriptionMO = try context.fetch(request).first {
                context.delete(transcriptionMO)
                try context.save()
            }
        }
    }

    public func updateTranscription(_ transcription: TranscriptionEntity) async throws {
        await sanitizePersistentHistoryIfNeeded()
        try validateCanonicalSummary(for: transcription)
        let sanitizedTranscription = Self.sanitizedTranscriptionEntity(from: transcription)
        try await stack.performBackgroundTask { context in
            let meetingRequest = MeetingMO.fetchRequest(for: sanitizedTranscription.meeting.id)
            let meetingMO = try context.fetch(meetingRequest).first ?? MeetingMO.create(from: sanitizedTranscription.meeting, in: context)
            meetingMO.update(from: sanitizedTranscription.meeting)

            let request = TranscriptionMO.fetchRequest(forTranscriptionId: sanitizedTranscription.id)
            if let transcriptionMO = try context.fetch(request).first {
                transcriptionMO.update(from: sanitizedTranscription, meeting: meetingMO)
                try context.save()
            }
        }
    }

    private func validateCanonicalSummary(for transcription: TranscriptionEntity) throws {
        guard let summary = transcription.canonicalSummary else { return }
        try summary.validate()
    }

    private static func sanitizedTranscriptionEntity(from transcription: TranscriptionEntity) -> TranscriptionEntity {
        let sanitizedMeeting = transcription.meeting.sanitizedForPersistence()
        var config = TranscriptionEntity.Configuration(
            text: transcription.text,
            rawText: transcription.rawText,
            segments: transcription.segments,
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
        config.lifecycleState = transcription.lifecycleState
        config.meetingConversationState = transcription.meetingConversationState
        return TranscriptionEntity(meeting: sanitizedMeeting, config: config)
    }
}
