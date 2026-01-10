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
            modelName: transcription.modelName
        )

        try await storageService.saveTranscription(legacyTranscription)
    }

    public func fetchTranscription(by id: UUID) async throws -> TranscriptionEntity? {
        let transcriptions = try await storageService.loadTranscriptions()
        guard let legacyTranscription = transcriptions.first(where: { $0.id == id }) else {
            return nil
        }

        // Converter Transcription (antiga) para TranscriptionEntity
        return TranscriptionEntity(
            id: legacyTranscription.id,
            meeting: MeetingEntity(
                id: legacyTranscription.meeting.id,
                app: DomainMeetingApp(rawValue: legacyTranscription.meeting.app.rawValue) ?? .unknown,
                startTime: legacyTranscription.meeting.startTime,
                endTime: legacyTranscription.meeting.endTime,
                audioFilePath: legacyTranscription.meeting.audioFilePath
            ),
            segments: legacyTranscription.segments.map { segment in
                TranscriptionEntity.Segment(
                    id: segment.id,
                    speaker: segment.speaker,
                    text: segment.text,
                    startTime: segment.startTime,
                    endTime: segment.endTime
                )
            },
            text: legacyTranscription.text,
            rawText: legacyTranscription.rawText,
            processedContent: legacyTranscription.processedContent,
            postProcessingPromptId: legacyTranscription.postProcessingPromptId,
            postProcessingPromptTitle: legacyTranscription.postProcessingPromptTitle,
            language: legacyTranscription.language,
            createdAt: legacyTranscription.createdAt,
            modelName: legacyTranscription.modelName
        )
    }

    public func fetchTranscriptions(for meetingId: UUID) async throws -> [TranscriptionEntity] {
        let allTranscriptions = try await fetchAllTranscriptions()
        return allTranscriptions.filter { $0.meeting.id == meetingId }
    }

    public func fetchAllTranscriptions() async throws -> [TranscriptionEntity] {
        let legacyTranscriptions = try await storageService.loadTranscriptions()
        return legacyTranscriptions.map { legacyTranscription in
            TranscriptionEntity(
                id: legacyTranscription.id,
                meeting: MeetingEntity(
                    id: legacyTranscription.meeting.id,
                    app: DomainMeetingApp(rawValue: legacyTranscription.meeting.app.rawValue) ?? .unknown,
                    startTime: legacyTranscription.meeting.startTime,
                    endTime: legacyTranscription.meeting.endTime,
                    audioFilePath: legacyTranscription.meeting.audioFilePath
                ),
                segments: legacyTranscription.segments.map { segment in
                    TranscriptionEntity.Segment(
                        id: segment.id,
                        speaker: segment.speaker,
                        text: segment.text,
                        startTime: segment.startTime,
                        endTime: segment.endTime
                    )
                },
                text: legacyTranscription.text,
                rawText: legacyTranscription.rawText,
                processedContent: legacyTranscription.processedContent,
                postProcessingPromptId: legacyTranscription.postProcessingPromptId,
                postProcessingPromptTitle: legacyTranscription.postProcessingPromptTitle,
                language: legacyTranscription.language,
                createdAt: legacyTranscription.createdAt,
                modelName: legacyTranscription.modelName
            )
        }
    }

    public func deleteTranscription(by id: UUID) async throws {
        // O StorageService atual não tem método de delete individual.
        // Como estamos migrando para CoreData, este adaptador JSON é mantido apenas para leitura.
        // Deleção em JSON não será implementada para evitar complexidade no legado.
        throw NSError(domain: "TranscriptionStorageRepositoryAdapter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Delete not supported for legacy JSON storage. Use CoreData for new data."])
    }

    public func updateTranscription(_ transcription: TranscriptionEntity) async throws {
        // Para atualizar, salvar novamente (o StorageService sobrescreve)
        try await saveTranscription(transcription)
    }
}