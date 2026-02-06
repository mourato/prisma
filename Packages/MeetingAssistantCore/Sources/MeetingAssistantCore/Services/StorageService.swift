import Foundation
import os.log

// MARK: - Models

public enum RecordingType: String, Sendable {
    case microphone = "mic"
    case system = "sys"
    case merged
}

public struct RetentionCleanupCandidate: Hashable, Sendable {
    public let url: URL
    public let byteSize: Int64

    public init(url: URL, byteSize: Int64) {
        self.url = url
        self.byteSize = byteSize
    }
}

public struct RetentionCleanupPreview: Hashable, Sendable {
    public let retentionDays: Int
    public let audioFiles: [RetentionCleanupCandidate]
    public let transcriptionFiles: [RetentionCleanupCandidate]

    public init(
        retentionDays: Int,
        audioFiles: [RetentionCleanupCandidate],
        transcriptionFiles: [RetentionCleanupCandidate]
    ) {
        self.retentionDays = retentionDays
        self.audioFiles = audioFiles
        self.transcriptionFiles = transcriptionFiles
    }

    public var audioCount: Int { audioFiles.count }
    public var transcriptionCount: Int { transcriptionFiles.count }
    public var totalAudioBytes: Int64 { audioFiles.reduce(0) { $0 + $1.byteSize } }
    public var totalTranscriptionBytes: Int64 { transcriptionFiles.reduce(0) { $0 + $1.byteSize } }
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

    /// Computes what would be deleted by retention cleanup (audio files + transcription JSONs).
    func computeRetentionCleanupPreview(olderThanDays days: Int) async throws -> RetentionCleanupPreview

    /// Performs retention cleanup using a previously computed preview.
    func performRetentionCleanup(preview: RetentionCleanupPreview) async throws -> RetentionCleanupResult
}

// MARK: - Implementation

public final class FileSystemStorageService: StorageService {
    public static let shared = FileSystemStorageService()

    private enum Keys {
        static let recordingsDirectory = "recordingsDirectory"
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
    private let transcriptsDirectory: URL

    public init() {
        // Setup default directories in Application Support
        let appSupportURLs = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        guard let appSupport = appSupportURLs.first else {
            fatalError("Critical: Could not access Application Support directory.")
        }

        let baseDir = appSupport.appendingPathComponent("MeetingAssistant", isDirectory: true)
        defaultRecordingsDirectory = baseDir.appendingPathComponent("recordings", isDirectory: true)
        transcriptsDirectory = baseDir.appendingPathComponent("transcripts", isDirectory: true)

        setupDirectories()
    }

    private func setupDirectories() {
        do {
            try FileManager.default.createDirectory(at: defaultRecordingsDirectory, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: transcriptsDirectory, withIntermediateDirectories: true)
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
        let filename = "\(transcription.id.uuidString).json"
        let url = transcriptsDirectory.appendingPathComponent(filename)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        let data = try encoder.encode(transcription)
        try data.write(to: url)

        AppLogger.info("Saved transcription", category: .databaseManager, extra: ["filename": filename])
    }

    public func loadTranscriptions() async throws -> [Transcription] {
        let transcriptsDir = transcriptsDirectory
        return await Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            let contents: [URL]
            do {
                contents = try fileManager.contentsOfDirectory(
                    at: transcriptsDir,
                    includingPropertiesForKeys: [.contentModificationDateKey],
                    options: .skipsHiddenFiles
                )
            } catch {
                AppLogger.warning("Failed to read transcripts directory: \(error.localizedDescription)", category: .databaseManager)
                return []
            }

            let jsonFiles = contents.filter { $0.pathExtension == "json" }
            var transcriptions: [Transcription] = []
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            for file in jsonFiles {
                if let transcription = FileSystemStorageService.decodeTranscriptionSync(from: file, using: decoder) {
                    transcriptions.append(transcription)
                }
            }

            transcriptions.sort { $0.createdAt > $1.createdAt }

            AppLogger.info("Loaded transcriptions", category: .databaseManager, extra: ["count": transcriptions.count])
            return transcriptions
        }.value
    }

    public func loadAllMetadata() async throws -> [TranscriptionMetadata] {
        let transcriptsDir = transcriptsDirectory
        return await Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            let contents: [URL]
            do {
                contents = try fileManager.contentsOfDirectory(
                    at: transcriptsDir,
                    includingPropertiesForKeys: [.contentModificationDateKey],
                    options: .skipsHiddenFiles
                )
            } catch {
                return []
            }

            let jsonFiles = contents.filter { $0.pathExtension == "json" }
            var metadataList: [TranscriptionMetadata] = []
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            for file in jsonFiles {
                if let data = try? Data(contentsOf: file),
                   let meta = try? decoder.decode(MetadataDecoder.self, from: data)
                {
                    let wordCount = FileSystemStorageService.wordCount(for: meta.text)
                    metadataList.append(TranscriptionMetadata(
                        id: meta.id,
                        meetingId: meta.meeting.id,
                        appName: meta.meeting.app.rawValue,
                        appRawValue: meta.meeting.app.rawValue,
                        startTime: meta.meeting.startTime,
                        createdAt: meta.createdAt,
                        previewText: String(meta.text.prefix(100)),
                        wordCount: wordCount,
                        language: meta.language,
                        isPostProcessed: meta.processedContent != nil,
                        duration: meta.meeting.duration,
                        audioFilePath: meta.meeting.audioFilePath,
                        inputSource: meta.inputSource
                    ))
                }
            }

            metadataList.sort { $0.createdAt > $1.createdAt }
            return metadataList
        }.value
    }

    public func loadTranscription(by id: UUID) async throws -> Transcription? {
        let url = transcriptsDirectory.appendingPathComponent("\(id.uuidString).json")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return await Task.detached(priority: .userInitiated) {
            FileSystemStorageService.decodeTranscriptionSync(from: url, using: decoder)
        }.value
    }

    public func deleteTranscription(by id: UUID) async throws {
        let filename = "\(id.uuidString).json"
        let url = transcriptsDirectory.appendingPathComponent(filename)

        try await Task.detached(priority: .userInitiated) {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
                AppLogger.info("Deleted transcription", category: .databaseManager, extra: ["filename": filename])
            } else {
                AppLogger.warning("Transcription file not found to delete", category: .databaseManager, extra: ["filename": filename])
            }
        }.value
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
        let transcriptsDir = transcriptsDirectory.standardizedFileURL

        let audioPathsToKeep: Set<String> = Set(transcriptionsToKeep.compactMap { meta in
            guard let path = meta.audioFilePath else { return nil }
            return FileSystemStorageService.standardizePath(path: path)
        })

        let audioPathsFromDeletedTranscriptions: Set<String> = Set(transcriptionsToDelete.compactMap { meta in
            guard let path = meta.audioFilePath else { return nil }
            return FileSystemStorageService.standardizePath(path: path)
        })

        return await Task.detached(priority: .userInitiated) {
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

            var transcriptionFiles: [RetentionCleanupCandidate] = []
            transcriptionFiles.reserveCapacity(transcriptionsToDelete.count)

            for item in transcriptionsToDelete {
                let url = transcriptsDir.appendingPathComponent("\(item.id.uuidString).json")
                if fileManager.fileExists(atPath: url.path) {
                    let bytes = fileByteSizeIfExists(url) ?? 0
                    transcriptionFiles.append(RetentionCleanupCandidate(url: url, byteSize: bytes))
                }
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
                var audioFiles: [RetentionCleanupCandidate] = []
                audioFiles.reserveCapacity(audioURLsToDelete.count)

                for url in audioURLsToDelete {
                    if fileManager.fileExists(atPath: url.path) {
                        let bytes = fileByteSizeIfExists(url) ?? 0
                        audioFiles.append(RetentionCleanupCandidate(url: url, byteSize: bytes))
                    }
                }

                audioFiles.sort { $0.url.lastPathComponent < $1.url.lastPathComponent }
                transcriptionFiles.sort { $0.url.lastPathComponent < $1.url.lastPathComponent }

                return RetentionCleanupPreview(
                    retentionDays: retentionDays,
                    audioFiles: audioFiles,
                    transcriptionFiles: transcriptionFiles
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

            var audioFiles: [RetentionCleanupCandidate] = []
            audioFiles.reserveCapacity(audioURLsToDelete.count)

            for url in audioURLsToDelete {
                if fileManager.fileExists(atPath: url.path) {
                    let bytes = fileByteSizeIfExists(url) ?? 0
                    audioFiles.append(RetentionCleanupCandidate(url: url, byteSize: bytes))
                }
            }

            audioFiles.sort { $0.url.lastPathComponent < $1.url.lastPathComponent }
            transcriptionFiles.sort { $0.url.lastPathComponent < $1.url.lastPathComponent }

            return RetentionCleanupPreview(
                retentionDays: retentionDays,
                audioFiles: audioFiles,
                transcriptionFiles: transcriptionFiles
            )
        }.value
    }

    public func performRetentionCleanup(preview: RetentionCleanupPreview) async throws -> RetentionCleanupResult {
        let audioToDelete = preview.audioFiles.map(\.url)
        let transcriptionsToDelete = preview.transcriptionFiles.map(\.url)
        let recordingsDirPath = recordingsDirectory.standardizedFileURL.path
        let transcriptsDirPath = transcriptsDirectory.standardizedFileURL.path

        return try await Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            var deletedAudio = 0
            var deletedTranscriptions = 0
            let allowedAudioExtensions: Set<String> = ["m4a", "wav"]

            let normalizedRecordingsDir = FileSystemStorageService.normalizeDirectoryPath(recordingsDirPath)
            let normalizedTranscriptsDir = FileSystemStorageService.normalizeDirectoryPath(transcriptsDirPath)

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

            for url in transcriptionsToDelete where isUnderDirectory(url, directoryPath: normalizedTranscriptsDir) {
                if try removeIfExists(url) {
                    deletedTranscriptions += 1
                }
            }

            for url in audioToDelete
            where isUnderDirectory(url, directoryPath: normalizedRecordingsDir) && isAllowedAudioFile(url) {
                if try removeIfExists(url) {
                    deletedAudio += 1
                }
            }

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
        }.value
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

    private struct MetadataDecoder: Codable {
        let id: UUID
        let meeting: Meeting
        let text: String
        let createdAt: Date
        let language: String
        let processedContent: String?
        let inputSource: String?
    }

    private static func decodeTranscriptionSync(from file: URL, using decoder: JSONDecoder) -> Transcription? {
        do {
            let data = try Data(contentsOf: file)
            return try decoder.decode(Transcription.self, from: data)
        } catch {
            AppLogger.error("Failed to load transcription", category: .databaseManager, error: error, extra: ["filename": file.lastPathComponent])
            return nil
        }
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
