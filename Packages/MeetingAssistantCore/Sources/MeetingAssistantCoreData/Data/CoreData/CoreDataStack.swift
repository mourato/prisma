import MeetingAssistantCoreDomain
// CoreDataStack - Stack thread-safe para gerenciamento de CoreData
// Seguindo Clean Architecture com isolamento de infraestrutura

import CoreData
import Foundation
import os.log

/// Stack CoreData thread-safe com suporte a operações em background
public final class CoreDataStack: Sendable {
    private let persistentContainer: NSPersistentContainer
    private let logger = Logger(subsystem: "com.meetingassistant", category: "CoreData")

    public static let shared = CoreDataStack()

    /// Contexto principal para operações na main thread
    public var mainContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }

    /// Cria novo contexto em background para operações assíncronas
    public var backgroundContext: NSManagedObjectContext {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        return context
    }

    /// Inicializa o stack CoreData
    /// - Parameter name: Nome do modelo CoreData
    /// - Parameter inMemory: Se true, usa banco em memória (para testes)
    public init(name: String = "MeetingAssistant", inMemory: Bool = false) {
        let model = CoreDataModel.createManagedObjectModel()
        persistentContainer = NSPersistentContainer(name: name, managedObjectModel: model)

        if inMemory {
            let description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
            persistentContainer.persistentStoreDescriptions = [description]
        } else {
            persistentContainer.persistentStoreDescriptions.forEach { description in
                description.shouldMigrateStoreAutomatically = true
                description.shouldInferMappingModelAutomatically = true
            }
        }

        persistentContainer.loadPersistentStores { [weak self] storeDescription, error in
            if let error {
                self?.logger.error("Failed to load persistent stores: \(error.localizedDescription)")
                fatalError("CoreData store failed to load: \(error.localizedDescription)")
            }

            self?.logger.info("CoreData store loaded successfully: \(storeDescription.url?.absoluteString ?? "unknown")")
        }

        // Configurar contexto principal
        mainContext.automaticallyMergesChangesFromParent = true
        mainContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
    }

    /// Executa operação em background context de forma thread-safe
    /// - Parameter operation: Bloco assíncrono a executar
    /// - Returns: Resultado da operação
    public func performBackgroundTask<T>(
        _ operation: @escaping (NSManagedObjectContext) async throws -> T
    ) async throws -> T {
        let context = backgroundContext

        return try await operation(context)
    }

    /// Salva contexto de forma segura
    /// - Parameter context: Contexto a salvar
    public func save(context: NSManagedObjectContext) throws {
        guard context.hasChanges else { return }

        try context.save()

        if context == mainContext {
            logger.debug("Main context saved")
        } else {
            logger.debug("Background context saved")
        }
    }

    /// Salva contexto em background de forma assíncrona
    /// - Parameter context: Contexto a salvar
    public func saveAsync(context: NSManagedObjectContext) async throws {
        try await context.perform {
            try self.save(context: context)
        }
    }

    /// Reseta o stack (útil para testes)
    public func reset() throws {
        let stores = persistentContainer.persistentStoreCoordinator.persistentStores
        for store in stores {
            try persistentContainer.persistentStoreCoordinator.remove(store)
        }

        // Recarregar stores
        try persistentContainer.persistentStoreCoordinator.addPersistentStore(
            ofType: NSInMemoryStoreType,
            configurationName: nil,
            at: nil
        )
    }
}
