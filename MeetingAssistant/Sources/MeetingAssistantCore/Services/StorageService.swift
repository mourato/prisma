import Foundation
import os.log

// MARK: - Models

public enum RecordingType: String, Sendable {
    case microphone = "mic"
    case system = "sys"
    case merged = "merged"
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
}

// MARK: - Implementation

public final class FileSystemStorageService: StorageService {
    public static let shared = FileSystemStorageService()
    
    private let logger = Logger(subsystem: "MeetingAssistant", category: "StorageService")
    
    public let recordingsDirectory: URL
    private let transcriptsDirectory: URL
    
    public init() {
        // Setup directories in Application Support
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Critical: Could not access Application Support directory.")
        }
        
        let baseDir = appSupport.appendingPathComponent("MeetingAssistant", isDirectory: true)
        self.recordingsDirectory = baseDir.appendingPathComponent("recordings", isDirectory: true)
        self.transcriptsDirectory = baseDir.appendingPathComponent("transcripts", isDirectory: true)
        
        setupDirectories()
    }
    
    private func setupDirectories() {
        do {
            try FileManager.default.createDirectory(at: recordingsDirectory, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: transcriptsDirectory, withIntermediateDirectories: true)
        } catch {
            logger.error("Failed to create storage directories: \(error.localizedDescription)")
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
            filename += "_mic.wav"
        case .system:
            filename += "_sys.wav"
        case .merged:
            filename += ".m4a"
        }
        
        return recordingsDirectory.appendingPathComponent(filename)
    }
    
    public func cleanupTemporaryFiles(urls: [URL]) {
        for url in urls {
            do {
                if FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.removeItem(at: url)
                    logger.debug("Deleted temporary file: \(url.lastPathComponent)")
                }
            } catch {
                logger.warning("Failed to delete file \(url.lastPathComponent): \(error.localizedDescription)")
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
        
        logger.info("Saved transcription to \(filename)")
    }
}
