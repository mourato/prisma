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
            let url = URL(fileURLWithPath: configuredPath)
            // Ensure it exists when accessed - creating directories is thread-safe on FileManager.default
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            return url
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
        let appName = meeting.app.rawValue.replacingOccurrences(of: " ", with: "_")

        var filename = "\(appName)_\(timestamp)"

        switch type {
        case .microphone:
            // AudioRecorder writes AAC, so we must use .m4a to avoid format mismatch errors
            filename += "_mic.m4a"
        case .system:
            filename += "_sys.wav"
        case .merged:
            filename += ".m4a"
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
        try await Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            let contents = try fileManager.contentsOfDirectory(
                at: self.transcriptsDirectory,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: .skipsHiddenFiles
            )

            let jsonFiles = contents.filter { $0.pathExtension == "json" }
            var transcriptions: [Transcription] = []
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            for file in jsonFiles {
                if let transcription = try? self.decodeTranscription(from: file, using: decoder) {
                    transcriptions.append(transcription)
                }
            }

            // Sort by date, most recent first
            transcriptions.sort { $0.createdAt > $1.createdAt }

            AppLogger.info("Loaded transcriptions", category: .databaseManager, extra: ["count": transcriptions.count])
            return transcriptions
        }.value
    }

    private func decodeTranscription(from file: URL, using decoder: JSONDecoder) throws -> Transcription? {
        do {
            let data = try Data(contentsOf: file)
            return try decoder.decode(Transcription.self, from: data)
        } catch {
            AppLogger.error("Failed to load transcription", category: .databaseManager, error: error, extra: ["filename": file.lastPathComponent])
            return nil
        }
    }
}
