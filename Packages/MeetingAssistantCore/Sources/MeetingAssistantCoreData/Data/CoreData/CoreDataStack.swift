import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain

// CoreDataStack - Stack thread-safe para gerenciamento de CoreData
// Seguindo Clean Architecture com isolamento de infraestrutura

import CoreData
import Foundation
import os.log

/// Stack CoreData thread-safe com suporte a operações em background
public final class CoreDataStack: Sendable {
    private let persistentContainer: NSPersistentContainer
    private let logger = Logger(subsystem: AppIdentity.logSubsystem, category: "CoreData")

    public static let shared = CoreDataStack()

    /// Contexto principal para operações na main thread
    public var mainContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }

    /// Cria novo contexto em background para operações assíncronas
    public var backgroundContext: NSManagedObjectContext {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        context.shouldDeleteInaccessibleFaults = true
        return context
    }

    /// Inicializa o stack CoreData
    /// - Parameter name: Nome do modelo CoreData
    /// - Parameter inMemory: Se true, usa banco em memória (para testes)
    public init(name: String = AppIdentity.appSupportDirectoryName, inMemory: Bool = false) {
        let model = CoreDataModel.createManagedObjectModel()
        persistentContainer = NSPersistentContainer(name: name, managedObjectModel: model)

        if inMemory {
            let description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
            description.shouldAddStoreAsynchronously = false
            persistentContainer.persistentStoreDescriptions = [description]
        } else {
            let storeURL = Self.persistentStoreURL(for: name)
            ensurePersistentStoreDirectoryExists(for: storeURL)

            let description = NSPersistentStoreDescription(url: storeURL)
            description.type = NSSQLiteStoreType
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
            description.shouldAddStoreAsynchronously = false
            persistentContainer.persistentStoreDescriptions = [description]
        }

        var loadError: Error?
        persistentContainer.loadPersistentStores { [weak self] storeDescription, error in
            if let error {
                self?.logger.error("Failed to load persistent stores: \(error.localizedDescription)")
                loadError = error
                return
            }

            self?.logger.info("CoreData store loaded successfully: \(storeDescription.url?.absoluteString ?? "unknown")")
        }

        if let loadError {
            logger.fault("Primary persistent store failed. Falling back to in-memory store: \(loadError.localizedDescription)")
            Self.installInMemoryFallbackStore(on: persistentContainer, logger: logger)
        }

        // Configurar contexto principal
        mainContext.automaticallyMergesChangesFromParent = true
        mainContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        mainContext.shouldDeleteInaccessibleFaults = true
    }

    private static func persistentStoreURL(for storeName: String) -> URL {
        let baseDirectory = AppIdentity.appSupportBaseDirectory(fileManager: .default)
        return baseDirectory.appendingPathComponent("\(storeName).sqlite", isDirectory: false)
    }

    private func ensurePersistentStoreDirectoryExists(for storeURL: URL) {
        let directory = storeURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            logger.error("Failed to create CoreData store directory: \(directory.path, privacy: .public). Error: \(error.localizedDescription)")
        }
    }

    private static func installInMemoryFallbackStore(on container: NSPersistentContainer, logger: Logger) {
        let coordinator = container.persistentStoreCoordinator
        for store in coordinator.persistentStores {
            do {
                try coordinator.remove(store)
            } catch {
                logger.error("Failed to remove persistent store before in-memory fallback: \(error.localizedDescription)")
            }
        }

        do {
            try coordinator.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil)
            logger.notice("In-memory CoreData fallback store installed")
        } catch {
            logger.fault("Failed to install in-memory CoreData fallback store: \(error.localizedDescription)")
        }
    }

    /// Executa operação em background context de forma thread-safe
    /// - Parameter operation: Bloco assíncrono a executar
    /// - Returns: Resultado da operação
    public func performBackgroundTask<T>(
        _ operation: @Sendable @escaping (NSManagedObjectContext) throws -> T
    ) async throws -> T {
        let context = backgroundContext
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    try continuation.resume(returning: operation(context))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
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
