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

    public func saveTranscription(_ transcription: TranscriptionEntity) async throws {
        try await stack.performBackgroundTask { context in
            let meetingRequest = MeetingMO.fetchRequest(for: transcription.meeting.id)
            let meetingMO = try context.fetch(meetingRequest).first ?? MeetingMO.create(from: transcription.meeting, in: context)
            meetingMO.update(from: transcription.meeting)

            let transcriptionRequest = TranscriptionMO.fetchRequest(forTranscriptionId: transcription.id)
            if let existing = try context.fetch(transcriptionRequest).first {
                existing.update(from: transcription, meeting: meetingMO)
            } else {
                _ = TranscriptionMO.create(from: transcription, meeting: meetingMO, in: context)
            }
            try context.save()
        }
    }

    public func fetchTranscription(by id: UUID) async throws -> TranscriptionEntity? {
        try await stack.performBackgroundTask { context in
            let request = TranscriptionMO.fetchRequest(forTranscriptionId: id)
            let result = try context.fetch(request)
            return result.first?.toDomain()
        }
    }

    public func fetchTranscriptions(for meetingId: UUID) async throws -> [TranscriptionEntity] {
        try await stack.performBackgroundTask { context in
            let request = TranscriptionMO.fetchRequest(forMeetingId: meetingId)
            let results = try context.fetch(request)
            return results.map { $0.toDomain() }
        }
    }

    public func fetchAllTranscriptions() async throws -> [TranscriptionEntity] {
        try await stack.performBackgroundTask { context in
            let request = TranscriptionMO.fetchRequest()
            let results = try context.fetch(request)
            return results.map { $0.toDomain() }
        }
    }

    public func fetchAllMetadata() async throws -> [DomainTranscriptionMetadata] {
        try await stack.performBackgroundTask { context in
            let request = TranscriptionMO.fetchRequest()
            let results = try context.fetch(request)
            return results.map { mo in
                DomainTranscriptionMetadata(
                    id: mo.id,
                    meetingId: mo.meeting.id,
                    appName: DomainMeetingApp(rawValue: mo.meeting.appRawValue)?.displayName ?? "Unknown",
                    appRawValue: mo.meeting.appRawValue,
                    startTime: mo.meeting.startTime,
                    createdAt: mo.createdAt,
                    previewText: String(mo.text.prefix(100)),
                    language: mo.language,
                    isPostProcessed: mo.processedContent != nil,
                    duration: mo.meeting.endTime?.timeIntervalSince(mo.meeting.startTime) ?? 0,
                    audioFilePath: mo.meeting.audioFilePath
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
        try await stack.performBackgroundTask { context in
            let meetingRequest = MeetingMO.fetchRequest(for: transcription.meeting.id)
            let meetingMO = try context.fetch(meetingRequest).first ?? MeetingMO.create(from: transcription.meeting, in: context)
            meetingMO.update(from: transcription.meeting)

            let request = TranscriptionMO.fetchRequest(forTranscriptionId: transcription.id)
            if let transcriptionMO = try context.fetch(request).first {
                transcriptionMO.update(from: transcription, meeting: meetingMO)
                try context.save()
            }
        }
    }
}
