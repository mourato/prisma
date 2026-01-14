// CoreDataModel - Definição programática do modelo CoreData
// Permite versionamento e migração automática seguindo Clean Architecture

import CoreData
import Foundation

/// Configuração programática do modelo CoreData
public enum CoreDataModel {
    /// Versão atual do modelo
    public static let currentVersion = "1.0"

    /// Cria o modelo CoreData programaticamente
    // swiftlint:disable function_body_length
    public static func createManagedObjectModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        // Entidade Meeting
        let meetingEntity = NSEntityDescription()
        meetingEntity.name = "MeetingMO"
        meetingEntity.managedObjectClassName = NSStringFromClass(MeetingMO.self)

        // Atributos Meeting
        let meetingIdAttribute = NSAttributeDescription()
        meetingIdAttribute.name = "id"
        meetingIdAttribute.attributeType = .UUIDAttributeType
        meetingIdAttribute.isOptional = false

        let meetingAppAttribute = NSAttributeDescription()
        meetingAppAttribute.name = "appRawValue"
        meetingAppAttribute.attributeType = .stringAttributeType
        meetingAppAttribute.isOptional = false

        let meetingStartTimeAttribute = NSAttributeDescription()
        meetingStartTimeAttribute.name = "startTime"
        meetingStartTimeAttribute.attributeType = .dateAttributeType
        meetingStartTimeAttribute.isOptional = false

        let meetingEndTimeAttribute = NSAttributeDescription()
        meetingEndTimeAttribute.name = "endTime"
        meetingEndTimeAttribute.attributeType = .dateAttributeType
        meetingEndTimeAttribute.isOptional = true

        let meetingAudioFilePathAttribute = NSAttributeDescription()
        meetingAudioFilePathAttribute.name = "audioFilePath"
        meetingAudioFilePathAttribute.attributeType = .stringAttributeType
        meetingAudioFilePathAttribute.isOptional = true

        meetingEntity.properties = [
            meetingIdAttribute,
            meetingAppAttribute,
            meetingStartTimeAttribute,
            meetingEndTimeAttribute,
            meetingAudioFilePathAttribute,
        ]

        // Entidade TranscriptionSegment
        let segmentEntity = NSEntityDescription()
        segmentEntity.name = "TranscriptionSegmentMO"
        segmentEntity.managedObjectClassName = NSStringFromClass(TranscriptionSegmentMO.self)

        // Atributos TranscriptionSegment
        let segmentIdAttribute = NSAttributeDescription()
        segmentIdAttribute.name = "id"
        segmentIdAttribute.attributeType = .UUIDAttributeType
        segmentIdAttribute.isOptional = false

        let segmentSpeakerAttribute = NSAttributeDescription()
        segmentSpeakerAttribute.name = "speaker"
        segmentSpeakerAttribute.attributeType = .stringAttributeType
        segmentSpeakerAttribute.isOptional = false

        let segmentTextAttribute = NSAttributeDescription()
        segmentTextAttribute.name = "text"
        segmentTextAttribute.attributeType = .stringAttributeType
        segmentTextAttribute.isOptional = false

        let segmentStartTimeAttribute = NSAttributeDescription()
        segmentStartTimeAttribute.name = "startTime"
        segmentStartTimeAttribute.attributeType = .doubleAttributeType
        segmentStartTimeAttribute.isOptional = false

        let segmentEndTimeAttribute = NSAttributeDescription()
        segmentEndTimeAttribute.name = "endTime"
        segmentEndTimeAttribute.attributeType = .doubleAttributeType
        segmentEndTimeAttribute.isOptional = false

        segmentEntity.properties = [
            segmentIdAttribute,
            segmentSpeakerAttribute,
            segmentTextAttribute,
            segmentStartTimeAttribute,
            segmentEndTimeAttribute,
        ]

        // Entidade Transcription
        let transcriptionEntity = NSEntityDescription()
        transcriptionEntity.name = "TranscriptionMO"
        transcriptionEntity.managedObjectClassName = NSStringFromClass(TranscriptionMO.self)

        // Atributos Transcription
        let transcriptionIdAttribute = NSAttributeDescription()
        transcriptionIdAttribute.name = "id"
        transcriptionIdAttribute.attributeType = .UUIDAttributeType
        transcriptionIdAttribute.isOptional = false

        let transcriptionTextAttribute = NSAttributeDescription()
        transcriptionTextAttribute.name = "text"
        transcriptionTextAttribute.attributeType = .stringAttributeType
        transcriptionTextAttribute.isOptional = false

        let transcriptionRawTextAttribute = NSAttributeDescription()
        transcriptionRawTextAttribute.name = "rawText"
        transcriptionRawTextAttribute.attributeType = .stringAttributeType
        transcriptionRawTextAttribute.isOptional = false

        let transcriptionProcessedContentAttribute = NSAttributeDescription()
        transcriptionProcessedContentAttribute.name = "processedContent"
        transcriptionProcessedContentAttribute.attributeType = .stringAttributeType
        transcriptionProcessedContentAttribute.isOptional = true

        let transcriptionPromptIdAttribute = NSAttributeDescription()
        transcriptionPromptIdAttribute.name = "postProcessingPromptId"
        transcriptionPromptIdAttribute.attributeType = .UUIDAttributeType
        transcriptionPromptIdAttribute.isOptional = true

        let transcriptionPromptTitleAttribute = NSAttributeDescription()
        transcriptionPromptTitleAttribute.name = "postProcessingPromptTitle"
        transcriptionPromptTitleAttribute.attributeType = .stringAttributeType
        transcriptionPromptTitleAttribute.isOptional = true

        let transcriptionLanguageAttribute = NSAttributeDescription()
        transcriptionLanguageAttribute.name = "language"
        transcriptionLanguageAttribute.attributeType = .stringAttributeType
        transcriptionLanguageAttribute.isOptional = false

        let transcriptionCreatedAtAttribute = NSAttributeDescription()
        transcriptionCreatedAtAttribute.name = "createdAt"
        transcriptionCreatedAtAttribute.attributeType = .dateAttributeType
        transcriptionCreatedAtAttribute.isOptional = false

        let transcriptionModelNameAttribute = NSAttributeDescription()
        transcriptionModelNameAttribute.name = "modelName"
        transcriptionModelNameAttribute.attributeType = .stringAttributeType
        transcriptionModelNameAttribute.isOptional = false

        transcriptionEntity.properties = [
            transcriptionIdAttribute,
            transcriptionTextAttribute,
            transcriptionRawTextAttribute,
            transcriptionProcessedContentAttribute,
            transcriptionPromptIdAttribute,
            transcriptionPromptTitleAttribute,
            transcriptionLanguageAttribute,
            transcriptionCreatedAtAttribute,
            transcriptionModelNameAttribute,
        ]

        // Relacionamentos

        // Transcription -> Meeting (many-to-one)
        let transcriptionToMeetingRelationship = NSRelationshipDescription()
        transcriptionToMeetingRelationship.name = "meeting"
        transcriptionToMeetingRelationship.destinationEntity = meetingEntity
        transcriptionToMeetingRelationship.isOptional = false
        transcriptionToMeetingRelationship.deleteRule = .nullifyDeleteRule
        transcriptionToMeetingRelationship.maxCount = 1 // To-one

        // Meeting -> Transcriptions (one-to-many)
        let meetingToTranscriptionsRelationship = NSRelationshipDescription()
        meetingToTranscriptionsRelationship.name = "transcriptions"
        meetingToTranscriptionsRelationship.destinationEntity = transcriptionEntity
        meetingToTranscriptionsRelationship.inverseRelationship = transcriptionToMeetingRelationship
        meetingToTranscriptionsRelationship.isOptional = true
        meetingToTranscriptionsRelationship.deleteRule = .cascadeDeleteRule
        meetingToTranscriptionsRelationship.maxCount = 0 // To-many

        transcriptionToMeetingRelationship.inverseRelationship = meetingToTranscriptionsRelationship

        // Segment -> Transcription (many-to-one)
        let segmentToTranscriptionRelationship = NSRelationshipDescription()
        segmentToTranscriptionRelationship.name = "transcription"
        segmentToTranscriptionRelationship.destinationEntity = transcriptionEntity
        segmentToTranscriptionRelationship.isOptional = false
        segmentToTranscriptionRelationship.deleteRule = .nullifyDeleteRule
        segmentToTranscriptionRelationship.maxCount = 1 // To-one

        // Transcription -> Segments (one-to-many)
        let transcriptionToSegmentsRelationship = NSRelationshipDescription()
        transcriptionToSegmentsRelationship.name = "segments"
        transcriptionToSegmentsRelationship.destinationEntity = segmentEntity
        transcriptionToSegmentsRelationship.inverseRelationship = segmentToTranscriptionRelationship
        transcriptionToSegmentsRelationship.isOptional = true
        transcriptionToSegmentsRelationship.deleteRule = .cascadeDeleteRule
        transcriptionToSegmentsRelationship.maxCount = 0 // To-many

        segmentToTranscriptionRelationship.inverseRelationship = transcriptionToSegmentsRelationship

        // Adicionar relacionamentos às entidades
        meetingEntity.properties.append(meetingToTranscriptionsRelationship)
        transcriptionEntity.properties.append(contentsOf: [transcriptionToMeetingRelationship, transcriptionToSegmentsRelationship])
        segmentEntity.properties.append(segmentToTranscriptionRelationship)

        // Adicionar entidades ao modelo
        model.entities = [meetingEntity, transcriptionEntity, segmentEntity]

        return model
    }
    // swiftlint:enable function_body_length
}
