import AppKit
import Foundation
import OSLog
import SwiftUI
import UniformTypeIdentifiers

@MainActor
public class TranscriptionSettingsViewModel: ObservableObject {
    @Published public var transcriptions: [TranscriptionMetadata] = []
    @Published public var selectedTranscription: Transcription?
    @Published public var selectedId: UUID? {
        didSet {
            if let id = selectedId {
                Task { await self.loadFullTranscription(id: id) }
            } else {
                self.selectedTranscription = nil
            }
        }
    }

    @Published public var isLoading = true
    @Published public var sourceFilter: RecordingSourceFilter = .all
    @Published public var dateFilter: DateFilter = .allEntries
    @Published public var errorMessage: String?

    private let storage: StorageService
    private let recordingManager: RecordingManager
    private let logger = Logger(subsystem: "MeetingAssistant", category: "TranscriptionSettingsViewModel")

    public init(
        storage: StorageService = FileSystemStorageService.shared,
        recordingManager: RecordingManager = .shared
    ) {
        self.storage = storage
        self.recordingManager = recordingManager
    }

    public var filteredTranscriptions: [TranscriptionMetadata] {
        self.transcriptions.filter { transcription in
            let matchesSource = self.matchesSourceFilter(transcription)
            let matchesDate = self.dateFilter.contains(transcription.createdAt)
            return matchesSource && matchesDate
        }
    }

    private func matchesSourceFilter(_ transcription: TranscriptionMetadata) -> Bool {
        switch self.sourceFilter {
        case .all:
            true
        case .dictations:
            transcription.appRawValue != MeetingApp.importedFile.rawValue
        case .manualImports:
            transcription.appRawValue == MeetingApp.importedFile.rawValue
        }
    }

    public func loadTranscriptions() async {
        self.isLoading = true
        do {
            self.transcriptions = try await self.storage.loadAllMetadata()
        } catch {
            self.logger.error("Failed to load transcriptions: \(error.localizedDescription)")
            self.errorMessage = "settings.transcriptions.error_load".localized
        }
        self.isLoading = false
    }

    public func loadFullTranscription(id: UUID) async {
        do {
            self.selectedTranscription = try await self.storage.loadTranscription(by: id)
        } catch {
            self.logger.error("Failed to load full transcription: \(error.localizedDescription)")
        }
    }

    public func openRecordingsDirectory() {
        NSWorkspace.shared.open(self.storage.recordingsDirectory)
    }
}
