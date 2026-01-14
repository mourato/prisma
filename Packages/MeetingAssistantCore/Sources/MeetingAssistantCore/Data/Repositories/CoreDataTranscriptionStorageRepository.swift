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
        try await self.stack.performBackgroundTask { context in
            // Buscar a reunião associada no contexto atual
                // swiftlint:disable line_length
        // swiftlint:disable line_length
        let meetingRequest = MeetingMO.fetchRequest(for: transcription.meeting.id)
        // swiftlint:enable line_length
    // swiftlint:enable line_length
            guard let meetingMO = try context.fetch(meetingRequest).first else {
                throw NSError(domain: "CoreDataTranscriptionStorageRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Meeting not found for transcription"])
            }

            _ = TranscriptionMO.create(from: transcription, meeting: meetingMO, in: context)
            try context.save()
        }
    }

    public func fetchTranscription(by id: UUID) async throws -> TranscriptionEntity? {
        try await self.stack.performBackgroundTask { context in
            let request = TranscriptionMO.fetchRequest(forTranscriptionId: id)
            let result = try context.fetch(request)
            return result.first?.toDomain()
        }
    }

    public func fetchTranscriptions(for meetingId: UUID) async throws -> [TranscriptionEntity] {
        try await self.stack.performBackgroundTask { context in
            let request = TranscriptionMO.fetchRequest(forMeetingId: meetingId)
            let results = try context.fetch(request)
            return results.map { $0.toDomain() }
        }
    }

    public func fetchAllTranscriptions() async throws -> [TranscriptionEntity] {
        try await self.stack.performBackgroundTask { context in
            let request = TranscriptionMO.fetchRequest()
            let results = try context.fetch(request)
            return results.map { $0.toDomain() }
        }
    }

    public func deleteTranscription(by id: UUID) async throws {
        try await self.stack.performBackgroundTask { context in
            let request = TranscriptionMO.fetchRequest(forTranscriptionId: id)
            if let transcriptionMO = try context.fetch(request).first {
                context.delete(transcriptionMO)
                try context.save()
            }
        }
    }

    public func updateTranscription(_ transcription: TranscriptionEntity) async throws {
        try await self.stack.performBackgroundTask { context in
            let request = TranscriptionMO.fetchRequest(forTranscriptionId: transcription.id)
            if let transcriptionMO = try context.fetch(request).first {
                transcriptionMO.update(from: transcription)
                try context.save()
            }
        }
    }
}
