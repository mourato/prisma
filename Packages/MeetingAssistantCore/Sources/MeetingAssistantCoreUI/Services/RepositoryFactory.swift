import Foundation
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

/// Factory that builds concrete repository implementations for dependency injection.
///
/// Note: this is part of the application composition layer (UI target) on purpose.
/// The lower-level modules (Domain/Data/Infrastructure/Audio/AI) should not depend
/// on the application wiring.
@MainActor
public protocol RepositoryFactory {
    func makeMeetingRepository() -> MeetingRepository
    func makeTranscriptionStorageRepository() -> TranscriptionStorageRepository
    func makeRecordingRepository() -> RecordingRepository
    func makeAudioFileRepository() -> AudioFileRepository
    func makeTranscriptionRepository() -> TranscriptionRepository
    func makePostProcessingRepository() -> PostProcessingRepository?
}

/// Default production repository factory.
@MainActor
public final class DefaultRepositoryFactory: RepositoryFactory {
    private let coreDataStack: CoreDataStack
    private let storageService: FileSystemStorageService
    private let recordingManager: RecordingManager
    private let transcriptionService: any TranscriptionService
    private let postProcessingService: any PostProcessingServiceProtocol

    public init(
        coreDataStack: CoreDataStack = .shared,
        storageService: FileSystemStorageService = .shared,
        recordingManager: RecordingManager = .shared,
        transcriptionService: any TranscriptionService = TranscriptionClient.shared,
        postProcessingService: any PostProcessingServiceProtocol = PostProcessingService.shared
    ) {
        self.coreDataStack = coreDataStack
        self.storageService = storageService
        self.recordingManager = recordingManager
        self.transcriptionService = transcriptionService
        self.postProcessingService = postProcessingService
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
        RecordingRepositoryAdapter(recordingManager: recordingManager)
    }

    public func makeAudioFileRepository() -> AudioFileRepository {
        AudioFileRepositoryAdapter(storageService: storageService)
    }

    public func makeTranscriptionRepository() -> TranscriptionRepository {
        TranscriptionRepositoryAdapter(transcriptionService: transcriptionService)
    }

    public func makePostProcessingRepository() -> PostProcessingRepository? {
        PostProcessingRepositoryAdapter(postProcessingService: postProcessingService)
    }
}
