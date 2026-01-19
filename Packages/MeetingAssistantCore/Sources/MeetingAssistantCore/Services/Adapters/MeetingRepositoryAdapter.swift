// MeetingRepositoryAdapter - Adapter para MeetingRepository usando FileSystemStorageService

import Foundation

/// Adapter que implementa MeetingRepository usando FileSystemStorageService existente
/// Nota: Como o StorageService atual não armazena reuniões separadamente,
/// este adapter mantém reuniões em memória para compatibilidade
public actor MeetingRepositoryAdapter: MeetingRepository {
    private var meetings: [UUID: MeetingEntity] = [:]
    private let storageService: FileSystemStorageService

    public init(storageService: FileSystemStorageService) {
        self.storageService = storageService
        // Carregar reuniões existentes dos arquivos de áudio, se possível
        // Por enquanto, manter em memória
    }

    public func saveMeeting(_ meeting: MeetingEntity) async throws {
        meetings[meeting.id] = meeting
    }

    public func fetchMeeting(by id: UUID) async throws -> MeetingEntity? {
        meetings[id]
    }

    public func fetchAllMeetings() async throws -> [MeetingEntity] {
        Array(meetings.values).sorted { $0.startTime > $1.startTime }
    }

    public func deleteMeeting(by id: UUID) async throws {
        meetings.removeValue(forKey: id)
    }

    public func updateMeeting(_ meeting: MeetingEntity) async throws {
        meetings[meeting.id] = meeting
    }
}
