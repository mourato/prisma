// RepositoryFactory - Centraliza a criação de repositórios para injeção de dependência
// Seguindo Clean Architecture e facilitando testes

import Foundation

/// Protocolo para fábrica de repositórios
@MainActor
public protocol RepositoryFactory {
    func makeMeetingRepository() -> MeetingRepository
    func makeTranscriptionStorageRepository() -> TranscriptionStorageRepository
    func makeRecordingRepository() -> RecordingRepository
    func makeAudioFileRepository() -> AudioFileRepository
    func makeTranscriptionRepository() -> TranscriptionRepository
    func makePostProcessingRepository() -> PostProcessingRepository?
}

/// Implementação padrão da fábrica de repositórios
@MainActor
public final class DefaultRepositoryFactory: RepositoryFactory {
    private let coreDataStack: CoreDataStack
    private let storageService: FileSystemStorageService

    public init(
        coreDataStack: CoreDataStack = .shared,
        storageService: FileSystemStorageService = .shared
    ) {
        self.coreDataStack = coreDataStack
        self.storageService = storageService
    }

    public func makeMeetingRepository() -> MeetingRepository {
        CoreDataMeetingRepository(stack: coreDataStack)
    }

    public func makeTranscriptionStorageRepository() -> TranscriptionStorageRepository {
        let coreDataRepo = CoreDataTranscriptionStorageRepository(stack: coreDataStack)
        let legacyRepo = TranscriptionStorageRepositoryAdapter(storageService: storageService)
        return HybridTranscriptionStorageRepository(coreDataRepo: coreDataRepo, legacyRepo: legacyRepo)
    }

    public func makeRecordingRepository() -> RecordingRepository {
        // Usar adaptador existente por enquanto
        RecordingRepositoryAdapter(recordingManager: RecordingManager.shared)
    }

    public func makeAudioFileRepository() -> AudioFileRepository {
        // Usar adaptador existente por enquanto
        AudioFileRepositoryAdapter(storageService: storageService)
    }

    public func makeTranscriptionRepository() -> TranscriptionRepository {
        // Usar adaptador existente por enquanto
        TranscriptionRepositoryAdapter(transcriptionService: TranscriptionClient.shared)
    }

    @MainActor
    public func makePostProcessingRepository() -> PostProcessingRepository? {
        // Usar adaptador existente por enquanto
        PostProcessingRepositoryAdapter(postProcessingService: PostProcessingService.shared)
    }
}
