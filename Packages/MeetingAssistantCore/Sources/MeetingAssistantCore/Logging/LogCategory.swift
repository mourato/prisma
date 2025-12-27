import Foundation

/// Application log categories for grouping logs in Console.app
public enum LogCategory: String, CaseIterable {
    case recordingManager = "RecordingManager"
    case transcriptionEngine = "TranscriptionEngine"
    case databaseManager = "DatabaseManager"
    case networkService = "NetworkService"
    case uiController = "UIController"

    // Default fallback
    case general = "General"
}
