import AppKit
import Foundation
import OSLog
import SwiftUI
import UniformTypeIdentifiers

@MainActor
public class TranscriptionSettingsViewModel: ObservableObject {
    @Published public var transcriptions: [Transcription] = []
    @Published public var selectedTranscription: Transcription?
    @Published public var isLoading = true
    @Published public var sourceFilter: RecordingSourceFilter = .all
    @Published public var dateFilter: DateFilter = .allEntries
    @Published public var errorMessage: String?

    private let storage: FileSystemStorageService
    private let recordingManager: RecordingManager
    private let logger = Logger(subsystem: "MeetingAssistant", category: "TranscriptionSettingsViewModel")

    public init(
        storage: FileSystemStorageService = .shared,
        recordingManager: RecordingManager = .shared
    ) {
        self.storage = storage
        self.recordingManager = recordingManager
    }

    public var filteredTranscriptions: [Transcription] {
        self.transcriptions.filter { transcription in
            let matchesSource = self.matchesSourceFilter(transcription)
            let matchesDate = self.dateFilter.contains(transcription.createdAt)
            return matchesSource && matchesDate
        }
    }

    private func matchesSourceFilter(_ transcription: Transcription) -> Bool {
        switch self.sourceFilter {
        case .all:
            true
        case .dictations:
            transcription.meeting.app != .importedFile
        case .manualImports:
            transcription.meeting.app == .importedFile
        }
    }

    public func loadTranscriptions() async {
        self.isLoading = true
        do {
            self.transcriptions = try await self.storage.loadTranscriptions()
        } catch {
            self.logger.error("Failed to load transcriptions: \(error.localizedDescription)")
            self.errorMessage = NSLocalizedString("settings.transcriptions.error_load", comment: "")
        }
        self.isLoading = false
    }

    public func openRecordingsDirectory() {
        NSWorkspace.shared.open(self.storage.recordingsDirectory)
    }
}
