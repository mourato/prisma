// TranscriptionStorageRepositoryAdapter - Adapter para TranscriptionStorageRepository usando FileSystemStorageService

import Foundation

/// Adapter que implementa TranscriptionStorageRepository usando FileSystemStorageService existente
public final class TranscriptionStorageRepositoryAdapter: TranscriptionStorageRepository {
    private let storageService: FileSystemStorageService

    public init(storageService: FileSystemStorageService) {
        self.storageService = storageService
    }

    public func saveTranscription(_ transcription: TranscriptionEntity) async throws {
        // Converter TranscriptionEntity para Transcription (antiga) para compatibilidade
        let legacyTranscription = Transcription(
            id: transcription.id,
            meeting: Meeting(
                id: transcription.meeting.id,
                app: MeetingApp(rawValue: transcription.meeting.app.rawValue) ?? .unknown,
                startTime: transcription.meeting.startTime,
                endTime: transcription.meeting.endTime,
                audioFilePath: transcription.meeting.audioFilePath
            ),
            segments: transcription.segments.map { segment in
                Transcription.Segment(
                    id: segment.id,
                    speaker: segment.speaker,
                    text: segment.text,
                    startTime: segment.startTime,
                    endTime: segment.endTime
                )
            },
            text: transcription.text,
            rawText: transcription.rawText,
            processedContent: transcription.processedContent,
            postProcessingPromptId: transcription.postProcessingPromptId,
            postProcessingPromptTitle: transcription.postProcessingPromptTitle,
            language: transcription.language,
            createdAt: transcription.createdAt,
            modelName: transcription.modelName,
            inputSource: transcription.inputSource,
            transcriptionDuration: transcription.transcriptionDuration,
            postProcessingDuration: transcription.postProcessingDuration,
            postProcessingModel: transcription.postProcessingModel
        )

        try await storageService.saveTranscription(legacyTranscription)
    }

    public func fetchTranscription(by id: UUID) async throws -> TranscriptionEntity? {
        guard let legacyTranscription = try await storageService.loadTranscription(by: id) else {
            return nil
        }

        return convertToEntity(legacyTranscription)
    }

    private func convertToEntity(_ legacyTranscription: Transcription) -> TranscriptionEntity {
        let meetingEntity = MeetingEntity(
            id: legacyTranscription.meeting.id,
            app: DomainMeetingApp(rawValue: legacyTranscription.meeting.app.rawValue) ?? .unknown,
            startTime: legacyTranscription.meeting.startTime,
            endTime: legacyTranscription.meeting.endTime,
            audioFilePath: legacyTranscription.meeting.audioFilePath
        )

        let segments = legacyTranscription.segments.map { segment in
            TranscriptionEntity.Segment(
                id: segment.id,
                speaker: segment.speaker,
                text: segment.text,
                startTime: segment.startTime,
                endTime: segment.endTime
            )
        }

        var config = TranscriptionEntity.Configuration(
            text: legacyTranscription.text,
            rawText: legacyTranscription.rawText,
            segments: segments,
            language: legacyTranscription.language
        )
        config.id = legacyTranscription.id
        config.processedContent = legacyTranscription.processedContent
        config.postProcessingPromptId = legacyTranscription.postProcessingPromptId
        config.postProcessingPromptTitle = legacyTranscription.postProcessingPromptTitle
        config.createdAt = legacyTranscription.createdAt
        config.modelName = legacyTranscription.modelName
        config.inputSource = legacyTranscription.inputSource
        config.transcriptionDuration = legacyTranscription.transcriptionDuration
        config.postProcessingDuration = legacyTranscription.postProcessingDuration
        config.postProcessingModel = legacyTranscription.postProcessingModel

        return TranscriptionEntity(meeting: meetingEntity, config: config)
    }

    public func fetchTranscriptions(for meetingId: UUID) async throws -> [TranscriptionEntity] {
        let allTranscriptions = try await fetchAllTranscriptions()
        return allTranscriptions.filter { $0.meeting.id == meetingId }
    }

    public func fetchAllTranscriptions() async throws -> [TranscriptionEntity] {
        let legacyTranscriptions = try await storageService.loadTranscriptions()
        return legacyTranscriptions.map { convertToEntity($0) }
    }

    public func fetchAllMetadata() async throws -> [DomainTranscriptionMetadata] {
        let metadataList = try await storageService.loadAllMetadata()
        return metadataList.map { meta in
            DomainTranscriptionMetadata(
                id: meta.id,
                meetingId: meta.meetingId,
                appName: meta.appName,
                appRawValue: meta.appRawValue,
                startTime: meta.startTime,
                createdAt: meta.createdAt,
                previewText: meta.previewText,
                language: meta.language,
                isPostProcessed: meta.isPostProcessed,
                duration: meta.duration,
                audioFilePath: nil
            )
        }
    }

    public func deleteTranscription(by id: UUID) async throws {
        // O StorageService atual não tem método de delete individual.
        // Como estamos migrando para CoreData, este adaptador JSON é mantido apenas para leitura.
        // Deleção em JSON não será implementada para evitar complexidade no legado.
        // swiftlint:disable line_length
        throw NSError(domain: "TranscriptionStorageRepositoryAdapter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Delete not supported for legacy JSON storage. Use CoreData for new data."])
        // swiftlint:enable line_length
    }

    public func updateTranscription(_ transcription: TranscriptionEntity) async throws {
        // Para atualizar, salvar novamente (o StorageService sobrescreve)
        try await saveTranscription(transcription)
    }
}
