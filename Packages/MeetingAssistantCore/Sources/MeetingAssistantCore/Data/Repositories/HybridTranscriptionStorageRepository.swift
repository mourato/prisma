// HybridTranscriptionStorageRepository - Implementação híbrida para migração gradual
// Lê de JSON (legado) e CoreData (novo), mas escreve apenas em CoreData

import Foundation

/// Repositório híbrido que suporta leitura de dados legados em JSON
public final class HybridTranscriptionStorageRepository: TranscriptionStorageRepository {
    private let coreDataRepo: CoreDataTranscriptionStorageRepository
    private let legacyRepo: TranscriptionStorageRepositoryAdapter

    public init(
        coreDataRepo: CoreDataTranscriptionStorageRepository,
        legacyRepo: TranscriptionStorageRepositoryAdapter
    ) {
        self.coreDataRepo = coreDataRepo
        self.legacyRepo = legacyRepo
    }

    public func saveTranscription(_ transcription: TranscriptionEntity) async throws {
        // Novos dados sempre vão para o CoreData
        try await self.coreDataRepo.saveTranscription(transcription)
    }

    public func fetchTranscription(by id: UUID) async throws -> TranscriptionEntity? {
        // Tentar CoreData primeiro
        if let transcription = try await coreDataRepo.fetchTranscription(by: id) {
            return transcription
        }
        // Se não encontrar, tentar legado
        return try await self.legacyRepo.fetchTranscription(by: id)
    }

    public func fetchTranscriptions(for meetingId: UUID) async throws -> [TranscriptionEntity] {
        let coreDataResults = try await coreDataRepo.fetchTranscriptions(for: meetingId)
        let legacyResults = try await legacyRepo.fetchTranscriptions(for: meetingId)

        // Combinar resultados (CoreData tem precedência se houver IDs duplicados,
        // o que não deve ocorrer)
        return coreDataResults + legacyResults
    }

    public func fetchAllTranscriptions() async throws -> [TranscriptionEntity] {
        let coreDataResults = try await coreDataRepo.fetchAllTranscriptions()
        let legacyResults = try await legacyRepo.fetchAllTranscriptions()

        return coreDataResults + legacyResults
    }

    public func deleteTranscription(by id: UUID) async throws {
        // Tentar deletar do CoreData
        do {
            try await self.coreDataRepo.deleteTranscription(by: id)
        } catch {
            // Se falhar ou não existir, tentar legado (que lançará erro conforme implementado)
            try await self.legacyRepo.deleteTranscription(by: id)
        }
    }

    public func updateTranscription(_ transcription: TranscriptionEntity) async throws {
        // Se existir no CoreData, atualizar lá
        if try await self.coreDataRepo.fetchTranscription(by: transcription.id) != nil {
            try await self.coreDataRepo.updateTranscription(transcription)
        } else {
            // Se for legado, não permitimos atualização direta no JSON para manter integridade.
            // Uma estratégia futura seria migrar para CoreData ao atualizar.
            throw NSError(
                domain: "HybridTranscriptionStorageRepository",
                code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey: "Updating legacy JSON transcriptions is not supported. Migrate to CoreData first.",
                ]
            )
        }
    }
}
