import Foundation
import os.log

// MARK: - Models

public enum RecordingType: String, Sendable {
    case microphone = "mic"
    case system = "sys"
    case merged
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
    func loadTranscription(by id: UUID) async throws -> Transcription?
}

// MARK: - Implementation

public final class FileSystemStorageService: StorageService {
    public static let shared = FileSystemStorageService()

    private enum Keys {
        static let recordingsDirectory = "recordingsDirectory"
    }

    public var recordingsDirectory: URL {
        // Read directly from UserDefaults to avoid MainActor isolation issues with AppSettingsStore
        let configuredPath = UserDefaults.standard.string(forKey: Keys.recordingsDirectory) ?? ""

        if !configuredPath.isEmpty {
            // Validate path before use
            do {
                let validatedURL = try self.validatePath(configuredPath)
                // Ensure it exists when accessed - creating directories is thread-safe on FileManager.default
                try? FileManager.default.createDirectory(at: validatedURL, withIntermediateDirectories: true)
                return validatedURL
            } catch {
                AppLogger.error("Invalid recording directory path, using default", category: .databaseManager, error: error)
                // Fall through to default
            }
        }
        return self.defaultRecordingsDirectory
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
        self.defaultRecordingsDirectory = baseDir.appendingPathComponent("recordings", isDirectory: true)
        self.transcriptsDirectory = baseDir.appendingPathComponent("transcripts", isDirectory: true)

        self.setupDirectories()
    }

    private func setupDirectories() {
        do {
            try FileManager.default.createDirectory(at: self.defaultRecordingsDirectory, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: self.transcriptsDirectory, withIntermediateDirectories: true)
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

        return self.recordingsDirectory.appendingPathComponent(filename)
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
        let url = self.transcriptsDirectory.appendingPathComponent(filename)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        let data = try encoder.encode(transcription)
        try data.write(to: url)

        AppLogger.info("Saved transcription", category: .databaseManager, extra: ["filename": filename])
    }

    public func loadTranscriptions() async throws -> [Transcription] {
        let transcriptsDir = self.transcriptsDirectory
        return try await Task.detached(priority: .userInitiated) {
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
                if let transcription = try? FileSystemStorageService.decodeTranscriptionSync(from: file, using: decoder) {
                    transcriptions.append(transcription)
                }
            }

            transcriptions.sort { $0.createdAt > $1.createdAt }

            AppLogger.info("Loaded transcriptions", category: .databaseManager, extra: ["count": transcriptions.count])
            return transcriptions
        }.value
    }

    public func loadAllMetadata() async throws -> [TranscriptionMetadata] {
        let transcriptsDir = self.transcriptsDirectory
        return try await Task.detached(priority: .userInitiated) {
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
                    metadataList.append(TranscriptionMetadata(
                        id: meta.id,
                        meetingId: meta.meeting.id,
                        appName: meta.meeting.app.rawValue,
                        appRawValue: meta.meeting.app.rawValue,
                        startTime: meta.meeting.startTime,
                        createdAt: meta.createdAt,
                        previewText: String(meta.text.prefix(100)),
                        language: meta.language,
                        isPostProcessed: meta.processedContent != nil,
                        duration: meta.meeting.duration
                    ))
                }
            }

            metadataList.sort { $0.createdAt > $1.createdAt }
            return metadataList
        }.value
    }

    public func loadTranscription(by id: UUID) async throws -> Transcription? {
        let url = self.transcriptsDirectory.appendingPathComponent("\(id.uuidString).json")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try await Task.detached(priority: .userInitiated) {
            FileSystemStorageService.decodeTranscriptionSync(from: url, using: decoder)
        }.value
    }

    private struct MetadataDecoder: Codable {
        let id: UUID
        let meeting: Meeting
        let text: String
        let createdAt: Date
        let language: String
        let processedContent: String?
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
