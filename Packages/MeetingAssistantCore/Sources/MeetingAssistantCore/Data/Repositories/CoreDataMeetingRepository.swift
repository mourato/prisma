// CoreDataMeetingRepository - Implementação de MeetingRepository usando CoreData
// Thread-safe e isolado do domínio

import CoreData
import Foundation

/// Repositório de reuniões usando CoreData para persistência
public final class CoreDataMeetingRepository: MeetingRepository {
    private let stack: CoreDataStack

    public init(stack: CoreDataStack = .shared) {
        self.stack = stack
    }

    public func saveMeeting(_ meeting: MeetingEntity) async throws {
        try await self.stack.performBackgroundTask { context in
            _ = MeetingMO.create(from: meeting, in: context)
            try context.save()
        }
    }

    public func fetchMeeting(by id: UUID) async throws -> MeetingEntity? {
        try await self.stack.performBackgroundTask { context in
            let request = MeetingMO.fetchRequest(for: id)
            let result = try context.fetch(request)
            return result.first?.toDomain()
        }
    }

    public func fetchAllMeetings() async throws -> [MeetingEntity] {
        try await self.stack.performBackgroundTask { context in
            let request = MeetingMO.fetchRequest()
            let results = try context.fetch(request)
            return results.map { $0.toDomain() }
        }
    }

    public func deleteMeeting(by id: UUID) async throws {
        try await self.stack.performBackgroundTask { context in
            let request = MeetingMO.fetchRequest(for: id)
            if let meetingMO = try context.fetch(request).first {
                context.delete(meetingMO)
                try context.save()
            }
        }
    }

    public func updateMeeting(_ meeting: MeetingEntity) async throws {
        try await self.stack.performBackgroundTask { context in
            let request = MeetingMO.fetchRequest(for: meeting.id)
            if let meetingMO = try context.fetch(request).first {
                meetingMO.update(from: meeting)
                try context.save()
            } else {
                // Se não existe, cria um novo (upsert)
                _ = MeetingMO.create(from: meeting, in: context)
                try context.save()
            }
        }
    }
}
