import MeetingAssistantCoreDomain

// TranscriptionMO - Managed Object para TranscriptionEntity
// Modelo CoreData thread-safe seguindo Clean Architecture

import CoreData
import Foundation

// swiftlint:disable force_unwrapping

/// Managed Object para entidade Transcription
@objc(TranscriptionMO)
public final class TranscriptionMO: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var text: String
    @NSManaged public var rawText: String
    @NSManaged public var processedContent: String?
    @NSManaged public var postProcessingPromptId: UUID?
    @NSManaged public var postProcessingPromptTitle: String?
    @NSManaged public var language: String
    @NSManaged public var createdAt: Date
    @NSManaged public var modelName: String

    // New Metadata Fields
    @NSManaged public var inputSource: String?
    @NSManaged public var transcriptionDuration: Double
    @NSManaged public var postProcessingDuration: Double
    @NSManaged public var postProcessingModel: String?
    @NSManaged public var meetingType: String?

    // Relacionamentos
    @NSManaged public var meeting: MeetingMO
    @NSManaged public var segments: Set<TranscriptionSegmentMO>
}

// MARK: - Fetch Requests

public extension TranscriptionMO {
    /// Fetch request para buscar todas as transcrições ordenadas por data
    @nonobjc class func fetchRequest() -> NSFetchRequest<TranscriptionMO> {
        let request = NSFetchRequest<TranscriptionMO>(entityName: "TranscriptionMO")
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        return request
    }

    // swiftlint:enable force_unwrapping

    /// Fetch request para buscar transcrição por ID
    @nonobjc class func fetchRequest(forTranscriptionId id: UUID) -> NSFetchRequest<TranscriptionMO> {
        let request = NSFetchRequest<TranscriptionMO>(entityName: "TranscriptionMO")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return request
    }

    /// Fetch request para buscar transcrições de uma reunião
    @nonobjc class func fetchRequest(forMeetingId meetingId: UUID) -> NSFetchRequest<TranscriptionMO> {
        let request = NSFetchRequest<TranscriptionMO>(entityName: "TranscriptionMO")
        request.predicate = NSPredicate(format: "meeting.id == %@", meetingId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        return request
    }
}

// MARK: - Conversion Methods

extension TranscriptionMO {
    /// Converte Managed Object para Domain Entity
    func toDomain() -> TranscriptionEntity {
        var config = TranscriptionEntity.Configuration(
            text: text,
            rawText: rawText,
            segments: segments.map { $0.toDomain() },
            language: language
        )
        config.id = id
        config.processedContent = processedContent
        config.postProcessingPromptId = postProcessingPromptId
        config.postProcessingPromptTitle = postProcessingPromptTitle
        config.createdAt = createdAt
        config.modelName = modelName
        config.inputSource = inputSource
        config.transcriptionDuration = transcriptionDuration
        config.postProcessingDuration = postProcessingDuration
        config.postProcessingModel = postProcessingModel
        config.meetingType = meetingType

        return TranscriptionEntity(meeting: meeting.toDomain(), config: config)
    }

    /// Atualiza Managed Object com dados da Domain Entity
    func update(from entity: TranscriptionEntity, meeting: MeetingMO) {
        id = entity.id
        text = entity.text
        rawText = entity.rawText
        processedContent = entity.processedContent
        postProcessingPromptId = entity.postProcessingPromptId
        postProcessingPromptTitle = entity.postProcessingPromptTitle
        language = entity.language
        createdAt = entity.createdAt
        modelName = entity.modelName
        inputSource = entity.inputSource
        transcriptionDuration = entity.transcriptionDuration
        postProcessingDuration = entity.postProcessingDuration
        postProcessingModel = entity.postProcessingModel
        meetingType = entity.meetingType

        self.meeting = meeting

        // Atualizar segmentos
        segments.forEach { self.managedObjectContext?.delete($0) }
        let newSegments = entity.segments.map {
            TranscriptionSegmentMO.create(from: $0, transcription: self, in: self.managedObjectContext!)
        }
        segments = Set(newSegments)
    }

    /// Cria novo Managed Object a partir de Domain Entity
    static func create(from entity: TranscriptionEntity, meeting: MeetingMO, in context: NSManagedObjectContext) -> TranscriptionMO {
        let transcriptionMO = TranscriptionMO(context: context)
        transcriptionMO.id = entity.id
        transcriptionMO.text = entity.text
        transcriptionMO.rawText = entity.rawText
        transcriptionMO.processedContent = entity.processedContent
        transcriptionMO.postProcessingPromptId = entity.postProcessingPromptId
        transcriptionMO.postProcessingPromptTitle = entity.postProcessingPromptTitle
        transcriptionMO.language = entity.language
        transcriptionMO.createdAt = entity.createdAt
        transcriptionMO.modelName = entity.modelName
        transcriptionMO.inputSource = entity.inputSource
        transcriptionMO.transcriptionDuration = entity.transcriptionDuration
        transcriptionMO.postProcessingDuration = entity.postProcessingDuration
        transcriptionMO.postProcessingModel = entity.postProcessingModel
        transcriptionMO.meetingType = entity.meetingType
        transcriptionMO.meeting = meeting

        // Criar segmentos
        let segments = entity.segments.map {
            TranscriptionSegmentMO.create(from: $0, transcription: transcriptionMO, in: context)
        }
        transcriptionMO.segments = Set(segments)

        return transcriptionMO
    }
}
