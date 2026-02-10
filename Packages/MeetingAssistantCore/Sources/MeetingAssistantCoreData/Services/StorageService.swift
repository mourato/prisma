import CoreData
import Foundation
import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

// MARK: - Models

public enum RecordingType: String, Sendable {
    case microphone = "mic"
    case system = "sys"
    case merged
}

public struct RetentionCleanupAudioCandidate: Hashable, Sendable {
    public let url: URL
    public let byteSize: Int64

    public init(url: URL, byteSize: Int64) {
        self.url = url
        self.byteSize = byteSize
    }
}

public struct RetentionCleanupTranscriptionCandidate: Hashable, Sendable {
    public let id: UUID
    public let byteSize: Int64

    public init(id: UUID, byteSize: Int64) {
        self.id = id
        self.byteSize = byteSize
    }
}

public struct RetentionCleanupPreview: Hashable, Sendable {
    public let retentionDays: Int
    public let audioFiles: [RetentionCleanupAudioCandidate]
    public let transcriptions: [RetentionCleanupTranscriptionCandidate]

    public init(
        retentionDays: Int,
        audioFiles: [RetentionCleanupAudioCandidate],
        transcriptions: [RetentionCleanupTranscriptionCandidate]
    ) {
        self.retentionDays = retentionDays
        self.audioFiles = audioFiles
        self.transcriptions = transcriptions
    }

    public var audioCount: Int {
        audioFiles.count
    }

    public var transcriptionCount: Int {
        transcriptions.count
    }

    public var totalAudioBytes: Int64 {
        audioFiles.reduce(0) { $0 + $1.byteSize }
    }

    public var totalTranscriptionBytes: Int64 {
        transcriptions.reduce(0) { $0 + $1.byteSize }
    }
}

public struct RetentionCleanupResult: Hashable, Sendable {
    public let deletedAudioCount: Int
    public let deletedTranscriptionCount: Int

    public init(deletedAudioCount: Int, deletedTranscriptionCount: Int) {
        self.deletedAudioCount = deletedAudioCount
        self.deletedTranscriptionCount = deletedTranscriptionCount
    }
}

// MARK: - Protocol

public protocol StorageService: Sendable {
    /// Base directory for recordings.
    var recordingsDirectory: URL { get }

    /// Generate a URL for a new recording file.
    func createRecordingURL(for meeting: Meeting, type: RecordingType) -> URL

    /// Delete specified files.
    func cleanupTemporaryFiles(urls: [URL])

    /// Save a transcription to persistent storage.
    func saveTranscription(_ transcription: Transcription) async throws

    /// Load all transcriptions from storage.
    func loadTranscriptions() async throws -> [Transcription]

    /// Load lightweight metadata for all transcriptions.
    func loadAllMetadata() async throws -> [TranscriptionMetadata]

    /// Load a specific transcription by its ID.
    /// Load a specific transcription by its ID.
    func loadTranscription(by id: UUID) async throws -> Transcription?

    /// Delete a transcription by its ID.
    func deleteTranscription(by id: UUID) async throws

    /// Delete transcriptions older than the specified number of days.
    func cleanupOldTranscriptions(olderThanDays days: Int) async throws

    /// Computes what would be deleted by retention cleanup (audio files + transcription records).
    func computeRetentionCleanupPreview(olderThanDays days: Int) async throws -> RetentionCleanupPreview

    /// Performs retention cleanup using a previously computed preview.
    func performRetentionCleanup(preview: RetentionCleanupPreview) async throws -> RetentionCleanupResult
}

// MARK: - Implementation

public final class FileSystemStorageService: StorageService {
    public static let shared = FileSystemStorageService()

    private enum Keys {
        static let recordingsDirectory = "recordingsDirectory"
        static let didMigrateLegacyJSONTranscriptionsToCoreDataV1 = "storage.migrations.legacy_json_transcriptions_to_coredata.v1"
    }

    private static func wordCount(for text: String) -> Int {
        text.split(whereSeparator: \.isWhitespace).count
    }

    public var recordingsDirectory: URL {
        // Read directly from UserDefaults to avoid MainActor isolation issues with AppSettingsStore
        let configuredPath = UserDefaults.standard.string(forKey: Keys.recordingsDirectory) ?? ""

        if !configuredPath.isEmpty {
            // Validate path before use
            do {
                let validatedURL = try validatePath(configuredPath)
                // Ensure it exists when accessed - creating directories is thread-safe on FileManager.default
                try? FileManager.default.createDirectory(at: validatedURL, withIntermediateDirectories: true)
                return validatedURL
            } catch {
                AppLogger.error("Invalid recording directory path, using default", category: .databaseManager, error: error)
                // Fall through to default
            }
        }
        return defaultRecordingsDirectory
    }

    private let defaultRecordingsDirectory: URL
    private let legacyTranscriptsDirectory: URL
    private let coreDataStack: CoreDataStack
    private let coreDataTranscriptionRepository: CoreDataTranscriptionStorageRepository

    public init() {
        // Setup default directories in Application Support
        let appSupportURLs = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        guard let appSupport = appSupportURLs.first else {
            fatalError("Critical: Could not access Application Support directory.")
        }

        let baseDir = appSupport.appendingPathComponent("MeetingAssistant", isDirectory: true)
        defaultRecordingsDirectory = baseDir.appendingPathComponent("recordings", isDirectory: true)
        legacyTranscriptsDirectory = baseDir.appendingPathComponent("transcripts", isDirectory: true)
        coreDataStack = .shared
        coreDataTranscriptionRepository = CoreDataTranscriptionStorageRepository(stack: coreDataStack)

        setupDirectories()
    }

    private func setupDirectories() {
        do {
            try FileManager.default.createDirectory(at: defaultRecordingsDirectory, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: legacyTranscriptsDirectory, withIntermediateDirectories: true)
        } catch {
            AppLogger.fault("Failed to create storage directories", category: .databaseManager, error: error)
        }
    }

    public func createRecordingURL(for meeting: Meeting, type: RecordingType) -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: meeting.startTime)
        let appName = InputSanitizer.sanitizeFilename(meeting.app.rawValue)

        var filename = "\(appName)_\(timestamp)"

        // Read audio format directly from UserDefaults to avoid MainActor isolation issues
        // Key matches AppSettingsStore.PostProcessingKeys.audioFormat
        let formatRaw = UserDefaults.standard.string(forKey: AppSettingsStore.PostProcessingKeys.audioFormat)
        // Default to .wav if nil or invalid
        let format = formatRaw.flatMap { AppSettingsStore.AudioFormat(rawValue: $0) } ?? .wav
        let fileExtension = format.fileExtension

        switch type {
        case .microphone:
            // AudioRecorder now supports both M4A and WAV
            filename += "_mic.\(fileExtension)"
        case .system:
            // System audio is captured as raw PCM, so usually kept as WAV if saved individually
            filename += "_sys.wav"
        case .merged:
            filename += ".\(fileExtension)"
        }

        return recordingsDirectory.appendingPathComponent(filename)
    }

    public func cleanupTemporaryFiles(urls: [URL]) {
        for url in urls {
            do {
                if FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.removeItem(at: url)
                    AppLogger.debug("Deleted temporary file", category: .databaseManager, extra: ["filename": url.lastPathComponent])
                }
            } catch {
                AppLogger.error("Failed to delete file", category: .databaseManager, error: error, extra: ["filename": url.lastPathComponent])
            }
        }
    }

    public func saveTranscription(_ transcription: Transcription) async throws {
        let entity = Self.convertToEntity(transcription)
        try await coreDataTranscriptionRepository.saveTranscription(entity)
        AppLogger.info("Saved transcription (Core Data)", category: .databaseManager, extra: ["id": transcription.id.uuidString])
    }

    public func loadTranscriptions() async throws -> [Transcription] {
        let entities = try await coreDataTranscriptionRepository.fetchAllTranscriptions()
        let models = entities.map(Self.convertToModel)
        AppLogger.info("Loaded transcriptions (Core Data)", category: .databaseManager, extra: ["count": models.count])
        return models
    }

    public func loadAllMetadata() async throws -> [TranscriptionMetadata] {
        try await coreDataStack.performBackgroundTask { context in
            let request = TranscriptionMO.fetchRequest()
            let results = try context.fetch(request)

            return results.map { mo in
                let wordCount = Self.wordCount(for: mo.text)
                return TranscriptionMetadata(
                    id: mo.id,
                    meetingId: mo.meeting.id,
                    appName: mo.meeting.appRawValue,
                    appRawValue: mo.meeting.appRawValue,
                    startTime: mo.meeting.startTime,
                    createdAt: mo.createdAt,
                    previewText: String(mo.text.prefix(100)),
                    wordCount: wordCount,
                    language: mo.language,
                    isPostProcessed: mo.processedContent != nil,
                    duration: mo.meeting.endTime?.timeIntervalSince(mo.meeting.startTime) ?? 0,
                    audioFilePath: mo.meeting.audioFilePath,
                    inputSource: mo.inputSource
                )
            }
        }
    }

    public func loadTranscription(by id: UUID) async throws -> Transcription? {
        guard let entity = try await coreDataTranscriptionRepository.fetchTranscription(by: id) else {
            return nil
        }
        return Self.convertToModel(entity)
    }

    public func deleteTranscription(by id: UUID) async throws {
        try await coreDataTranscriptionRepository.deleteTranscription(by: id)
        AppLogger.info("Deleted transcription (Core Data)", category: .databaseManager, extra: ["id": id.uuidString])
    }

    public func cleanupOldTranscriptions(olderThanDays days: Int) async throws {
        let allMetadata = try await loadAllMetadata()
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()

        let toDelete = allMetadata.filter { $0.createdAt < cutoffDate }

        for item in toDelete {
            try await deleteTranscription(by: item.id)
        }

        if !toDelete.isEmpty {
            AppLogger.info("Cleanup completed", category: .databaseManager, extra: ["deletedCount": toDelete.count])
        }

        try? await cleanupOrphanedRecordings()
    }

    public func computeRetentionCleanupPreview(olderThanDays days: Int) async throws -> RetentionCleanupPreview {
        let retentionDays = max(1, days)
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) ?? Date()

        let allMetadata = try await loadAllMetadata()
        let transcriptionsToDelete = allMetadata.filter { $0.createdAt < cutoffDate }
        let transcriptionsToKeep = allMetadata.filter { $0.createdAt >= cutoffDate }

        let recordingsDir = recordingsDirectory.standardizedFileURL

        let audioPathsToKeep = Self.standardizedAudioPaths(from: transcriptionsToKeep)
        let audioPathsFromDeletedTranscriptions = Self.standardizedAudioPaths(from: transcriptionsToDelete)
        let transcriptionCandidates = transcriptionsToDelete.map { meta in
            RetentionCleanupTranscriptionCandidate(id: meta.id, byteSize: 0)
        }

        return await Task.detached(priority: .userInitiated) {
            Self.computeRetentionCleanupPreviewSync(
                retentionDays: retentionDays,
                cutoffDate: cutoffDate,
                recordingsDir: recordingsDir,
                audioPathsToKeep: audioPathsToKeep,
                audioPathsFromDeletedTranscriptions: audioPathsFromDeletedTranscriptions,
                transcriptionCandidates: transcriptionCandidates
            )
        }.value
    }

    private static func standardizedAudioPaths(from transcriptions: [TranscriptionMetadata]) -> Set<String> {
        Set(transcriptions.compactMap { meta in
            guard let path = meta.audioFilePath else { return nil }
            return FileSystemStorageService.standardizePath(path: path)
        })
    }

    private static func computeRetentionCleanupPreviewSync(
        retentionDays: Int,
        cutoffDate: Date,
        recordingsDir: URL,
        audioPathsToKeep: Set<String>,
        audioPathsFromDeletedTranscriptions: Set<String>,
        transcriptionCandidates: [RetentionCleanupTranscriptionCandidate]
    ) -> RetentionCleanupPreview {
        let fileManager = FileManager.default
        let allowedAudioExtensions: Set<String> = ["m4a", "wav"]
        let recordingsDirPath = recordingsDir.path

        func isAudioFile(_ url: URL) -> Bool {
            allowedAudioExtensions.contains(url.pathExtension.lowercased())
        }

        func isPathInsideRecordingsDirectory(_ path: String) -> Bool {
            let normalizedRecordings = FileSystemStorageService.normalizeDirectoryPath(recordingsDirPath)
            let normalizedPath = FileSystemStorageService.normalizeDirectoryPath(path)
            return normalizedPath == normalizedRecordings || normalizedPath.hasPrefix(normalizedRecordings + "/")
        }

        func fileByteSizeIfExists(_ url: URL) -> Int64? {
            guard fileManager.fileExists(atPath: url.path) else { return nil }
            let values = try? url.resourceValues(forKeys: [.fileSizeKey])
            if let fileSize = values?.fileSize {
                return Int64(fileSize)
            }
            let attributes = try? fileManager.attributesOfItem(atPath: url.path)
            if let size = attributes?[.size] as? NSNumber {
                return size.int64Value
            }
            return nil
        }

        var audioURLsToDelete: Set<URL> = []
        audioURLsToDelete.reserveCapacity(audioPathsFromDeletedTranscriptions.count)

        for audioPath in audioPathsFromDeletedTranscriptions {
            guard isPathInsideRecordingsDirectory(audioPath) else { continue }
            let url = URL(fileURLWithPath: audioPath).standardizedFileURL
            guard isAudioFile(url) else { continue }
            audioURLsToDelete.insert(url)
        }

        let resourceKeys: [URLResourceKey] = [
            .contentModificationDateKey,
            .creationDateKey,
            .fileSizeKey,
            .isDirectoryKey,
        ]

        let files: [URL]
        do {
            files = try fileManager.contentsOfDirectory(
                at: recordingsDir,
                includingPropertiesForKeys: resourceKeys,
                options: [.skipsHiddenFiles]
            )
        } catch {
            let audioFiles = computeAudioCandidates(
                audioURLsToDelete: audioURLsToDelete,
                fileByteSizeIfExists: fileByteSizeIfExists,
                fileManager: fileManager
            )
            let sortedTranscriptions = transcriptionCandidates.sorted { $0.id.uuidString < $1.id.uuidString }
            return RetentionCleanupPreview(
                retentionDays: retentionDays,
                audioFiles: audioFiles,
                transcriptions: sortedTranscriptions
            )
        }

        for fileURL in files {
            let values = try? fileURL.resourceValues(forKeys: Set(resourceKeys))
            if values?.isDirectory == true {
                continue
            }

            guard isAudioFile(fileURL) else { continue }

            let standardizedPath = fileURL.standardizedFileURL.path
            if audioPathsToKeep.contains(standardizedPath) {
                continue
            }

            let referenceDate = values?.contentModificationDate ?? values?.creationDate
            if let referenceDate, referenceDate >= cutoffDate {
                continue
            }

            audioURLsToDelete.insert(fileURL.standardizedFileURL)
        }

        let audioFiles = computeAudioCandidates(
            audioURLsToDelete: audioURLsToDelete,
            fileByteSizeIfExists: fileByteSizeIfExists,
            fileManager: fileManager
        )
        let sortedTranscriptions = transcriptionCandidates.sorted { $0.id.uuidString < $1.id.uuidString }

        return RetentionCleanupPreview(
            retentionDays: retentionDays,
            audioFiles: audioFiles,
            transcriptions: sortedTranscriptions
        )
    }

    private static func computeAudioCandidates(
        audioURLsToDelete: Set<URL>,
        fileByteSizeIfExists: (URL) -> Int64?,
        fileManager: FileManager
    ) -> [RetentionCleanupAudioCandidate] {
        var audioFiles: [RetentionCleanupAudioCandidate] = []
        audioFiles.reserveCapacity(audioURLsToDelete.count)

        for url in audioURLsToDelete {
            if fileManager.fileExists(atPath: url.path) {
                let bytes = fileByteSizeIfExists(url) ?? 0
                audioFiles.append(RetentionCleanupAudioCandidate(url: url, byteSize: bytes))
            }
        }

        audioFiles.sort { $0.url.lastPathComponent < $1.url.lastPathComponent }
        return audioFiles
    }

    public func performRetentionCleanup(preview: RetentionCleanupPreview) async throws -> RetentionCleanupResult {
        let audioToDelete = preview.audioFiles.map(\.url)
        let recordingsDirPath = recordingsDirectory.standardizedFileURL.path
        let transcriptionIdsToDelete = preview.transcriptions.map(\.id)

        let deletedTranscriptions = try await coreDataStack.performBackgroundTask { context in
            var deleted = 0
            for id in transcriptionIdsToDelete {
                let request = TranscriptionMO.fetchRequest(forTranscriptionId: id)
                if let transcriptionMO = try context.fetch(request).first {
                    context.delete(transcriptionMO)
                    deleted += 1
                }
            }
            if context.hasChanges {
                try context.save()
            }
            return deleted
        }

        let deletedAudio = try await Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            var deletedAudio = 0
            let allowedAudioExtensions: Set<String> = ["m4a", "wav"]

            let normalizedRecordingsDir = FileSystemStorageService.normalizeDirectoryPath(recordingsDirPath)

            func isUnderDirectory(_ url: URL, directoryPath: String) -> Bool {
                let standardized = url.standardizedFileURL.path
                return standardized == directoryPath || standardized.hasPrefix(directoryPath + "/")
            }

            func isAllowedAudioFile(_ url: URL) -> Bool {
                allowedAudioExtensions.contains(url.pathExtension.lowercased())
            }

            func removeIfExists(_ url: URL) throws -> Bool {
                if fileManager.fileExists(atPath: url.path) {
                    try fileManager.removeItem(at: url)
                    return true
                }
                return false
            }

            for url in audioToDelete
                where isUnderDirectory(url, directoryPath: normalizedRecordingsDir) && isAllowedAudioFile(url)
            {
                if try removeIfExists(url) {
                    deletedAudio += 1
                }
            }

            return deletedAudio
        }.value

        if deletedAudio > 0 || deletedTranscriptions > 0 {
            AppLogger.info(
                "Retention cleanup completed",
                category: .databaseManager,
                extra: [
                    "deletedAudioCount": "\(deletedAudio)",
                    "deletedTranscriptionCount": "\(deletedTranscriptions)",
                ]
            )
        }

        return RetentionCleanupResult(
            deletedAudioCount: deletedAudio,
            deletedTranscriptionCount: deletedTranscriptions
        )
    }

    public func cleanupOrphanedRecordings() async throws {
        let allMetadata = try await loadAllMetadata()
        let knownAudioPaths = Set(allMetadata.compactMap(\.audioFilePath))
        let recordingsDir = recordingsDirectory

        // Use a detached task for file system operations to avoid blocking
        await Task.detached(priority: .background) {
            let fileManager = FileManager.default

            // Enum all files in recordings dir
            guard let files = try? fileManager.contentsOfDirectory(at: recordingsDir, includingPropertiesForKeys: [.creationDateKey]) else { return }

            var deletedCount = 0

            for file in files {
                // Check if file is an audio file (wav, m4a)
                let ext = file.pathExtension.lowercased()
                if ["wav", "m4a"].contains(ext) {
                    if !knownAudioPaths.contains(file.path) {
                        // Safe guard: only delete if older than 24h
                        if let attr = try? fileManager.attributesOfItem(atPath: file.path),
                           let creationDate = attr[.creationDate] as? Date,
                           Date().timeIntervalSince(creationDate) > 86_400
                        { // 24 hours

                            do {
                                try fileManager.removeItem(at: file)
                                deletedCount += 1
                                AppLogger.info("Deleted orphaned recording", category: .databaseManager, extra: ["filename": file.lastPathComponent])
                            } catch {
                                AppLogger.error("Failed to delete orphan", category: .databaseManager, error: error)
                            }
                        }
                    }
                }
            }

            if deletedCount > 0 {
                AppLogger.info("Orphan cleanup completed", category: .databaseManager, extra: ["deletedCount": deletedCount])
            }
        }.value
    }

    private static func standardizePath(path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }

    private static func normalizeDirectoryPath(_ path: String) -> String {
        var normalized = path
        while normalized.hasSuffix("/") {
            normalized.removeLast()
        }
        return normalized
    }

    // MARK: - Legacy JSON migration

    /// One-time migration for legacy JSON transcriptions into Core Data.
    ///
    /// This is designed to be idempotent:
    /// - Transcriptions are upserted into Core Data by `id`.
    /// - Migrated JSON files are moved to `transcripts/legacy-json-archive/`.
    /// - The `UserDefaults` checkpoint is only marked complete when there are no
    ///   remaining `.json` files in the legacy directory root.
    public func migrateLegacyJSONTranscriptionsToCoreDataIfNeeded() async {
        guard !UserDefaults.standard.bool(forKey: Keys.didMigrateLegacyJSONTranscriptionsToCoreDataV1) else {
            return
        }

        let legacyDirectory = legacyTranscriptsDirectory
        let archiveDirectory = legacyDirectory.appendingPathComponent("legacy-json-archive", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: archiveDirectory, withIntermediateDirectories: true)
        } catch {
            AppLogger.error("Failed to create legacy JSON archive directory", category: .databaseManager, error: error)
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let legacyJSONFiles: [URL]
        do {
            legacyJSONFiles = try FileManager.default.contentsOfDirectory(
                at: legacyDirectory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
            .filter { $0.pathExtension.lowercased() == "json" }
        } catch {
            AppLogger.error("Failed to enumerate legacy transcripts directory", category: .databaseManager, error: error)
            return
        }

        guard !legacyJSONFiles.isEmpty else {
            UserDefaults.standard.set(true, forKey: Keys.didMigrateLegacyJSONTranscriptionsToCoreDataV1)
            return
        }

        var migratedCount = 0
        var failedCount = 0

        for fileURL in legacyJSONFiles {
            do {
                let data = try Data(contentsOf: fileURL)
                let legacy = try decoder.decode(Transcription.self, from: data)
                let entity = Self.convertToEntity(legacy)

                try await coreDataTranscriptionRepository.saveTranscription(entity)

                let destinationURL = archiveDirectory.appendingPathComponent(fileURL.lastPathComponent)
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.moveItem(at: fileURL, to: destinationURL)

                migratedCount += 1
            } catch {
                failedCount += 1
                AppLogger.error(
                    "Failed to migrate legacy JSON transcription",
                    category: .databaseManager,
                    error: error,
                    extra: ["filename": fileURL.lastPathComponent]
                )
            }
        }

        let remainingJSONFiles: [URL]
        do {
            remainingJSONFiles = try FileManager.default.contentsOfDirectory(
                at: legacyDirectory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
            .filter { $0.pathExtension.lowercased() == "json" }
        } catch {
            remainingJSONFiles = []
        }

        if remainingJSONFiles.isEmpty {
            UserDefaults.standard.set(true, forKey: Keys.didMigrateLegacyJSONTranscriptionsToCoreDataV1)
        }

        AppLogger.info(
            "Legacy JSON → Core Data migration finished",
            category: .databaseManager,
            extra: [
                "migratedCount": "\(migratedCount)",
                "failedCount": "\(failedCount)",
            ]
        )
    }

    // MARK: - Core Data helpers

    private static func convertToEntity(_ transcription: Transcription) -> TranscriptionEntity {
        let meetingEntity = MeetingEntity(
            id: transcription.meeting.id,
            app: DomainMeetingApp(rawValue: transcription.meeting.app.rawValue) ?? .unknown,
            startTime: transcription.meeting.startTime,
            endTime: transcription.meeting.endTime,
            audioFilePath: transcription.meeting.audioFilePath
        )

        let segments = transcription.segments.map { segment in
            TranscriptionEntity.Segment(
                id: segment.id,
                speaker: segment.speaker,
                text: segment.text,
                startTime: segment.startTime,
                endTime: segment.endTime
            )
        }

        var config = TranscriptionEntity.Configuration(
            text: transcription.text,
            rawText: transcription.rawText,
            segments: segments,
            language: transcription.language
        )
        config.id = transcription.id
        config.processedContent = transcription.processedContent
        config.postProcessingPromptId = transcription.postProcessingPromptId
        config.postProcessingPromptTitle = transcription.postProcessingPromptTitle
        config.createdAt = transcription.createdAt
        config.modelName = transcription.modelName
        config.inputSource = transcription.inputSource
        config.transcriptionDuration = transcription.transcriptionDuration
        config.postProcessingDuration = transcription.postProcessingDuration
        config.postProcessingModel = transcription.postProcessingModel
        config.meetingType = transcription.meetingType

        return TranscriptionEntity(meeting: meetingEntity, config: config)
    }

    private static func convertToModel(_ entity: TranscriptionEntity) -> Transcription {
        let meeting = Meeting(
            id: entity.meeting.id,
            app: MeetingApp(rawValue: entity.meeting.app.rawValue) ?? .unknown,
            startTime: entity.meeting.startTime,
            endTime: entity.meeting.endTime,
            audioFilePath: entity.meeting.audioFilePath
        )

        let segments = entity.segments.map { segment in
            Transcription.Segment(
                id: segment.id,
                speaker: segment.speaker,
                text: segment.text,
                startTime: segment.startTime,
                endTime: segment.endTime
            )
        }

        return Transcription(
            id: entity.id,
            meeting: meeting,
            segments: segments,
            text: entity.text,
            rawText: entity.rawText,
            processedContent: entity.processedContent,
            postProcessingPromptId: entity.postProcessingPromptId,
            postProcessingPromptTitle: entity.postProcessingPromptTitle,
            language: entity.language,
            createdAt: entity.createdAt,
            modelName: entity.modelName,
            inputSource: entity.inputSource,
            transcriptionDuration: entity.transcriptionDuration,
            postProcessingDuration: entity.postProcessingDuration,
            postProcessingModel: entity.postProcessingModel,
            meetingType: entity.meetingType
        )
    }

    deinit {
        AppLogger.debug("FileSystemStorageService deinitialized", category: .databaseManager)
    }

    // MARK: - Path Validation

    private enum PathValidationError: Error, LocalizedError {
        case pathTraversalDetected(String)
        case invalidPath(String)
        case outsideContainer(String)

        var errorDescription: String? {
            switch self {
            case let .pathTraversalDetected(path):
                "Security: Path traversal attempt detected - \(path)"
            case let .invalidPath(path):
                "Security: Invalid path format - \(path)"
            case let .outsideContainer(path):
                "Security: Path outside app container - \(path)"
            }
        }
    }

    /// Validates that a path is safe and within the app container.
    private func validatePath(_ path: String) throws -> URL {
        // 1. Check for obvious traversal patterns
        do {
            try InputSanitizer.validatePathComponent(path)
        } catch {
            AppLogger.warning("Path traversal attempt blocked", category: .databaseManager, extra: ["path": path])
            throw PathValidationError.pathTraversalDetected(path)
        }

        // 2. Resolve to canonical path
        let url = URL(fileURLWithPath: path)
        let resolvedPath = url.resolvingSymlinksInPath().path

        // 3. Validate within app container (Application Support)
        let appSupportURLs = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        guard let appSupport = appSupportURLs.first else {
            throw PathValidationError.invalidPath(path)
        }

        let containerPath = appSupport.appendingPathComponent("MeetingAssistant").path
        guard resolvedPath.hasPrefix(containerPath) else {
            AppLogger.warning("Path outside container blocked", category: .databaseManager, extra: [
                "path": path,
                "resolved": resolvedPath,
                "container": containerPath,
            ])
            throw PathValidationError.outsideContainer(path)
        }

        return URL(fileURLWithPath: resolvedPath)
    }
}
