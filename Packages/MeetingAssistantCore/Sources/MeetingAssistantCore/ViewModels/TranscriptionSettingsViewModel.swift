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
                selectedTranscription = nil
            }
        }
    }

    @Published public var isProcessingAI = false

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
        transcriptions.filter { transcription in
            let matchesSource = self.matchesSourceFilter(transcription)
            let matchesDate = self.dateFilter.contains(transcription.createdAt)
            return matchesSource && matchesDate
        }
    }

    private func matchesSourceFilter(_ transcription: TranscriptionMetadata) -> Bool {
        switch sourceFilter {
        case .all:
            true
        case .dictations:
            transcription.appRawValue != MeetingApp.importedFile.rawValue
        case .manualImports:
            transcription.appRawValue == MeetingApp.importedFile.rawValue
        }
    }

    public func loadTranscriptions() async {
        isLoading = true
        do {
            transcriptions = try await storage.loadAllMetadata()
        } catch {
            logger.error("Failed to load transcriptions: \(error.localizedDescription)")
            errorMessage = "settings.transcriptions.error_load".localized
        }
        isLoading = false
    }

    public func loadFullTranscription(id: UUID) async {
        do {
            selectedTranscription = try await storage.loadTranscription(by: id)
        } catch {
            logger.error("Failed to load full transcription: \(error.localizedDescription)")
        }
    }

    public func openRecordingsDirectory() {
        NSWorkspace.shared.open(storage.recordingsDirectory)
    }

    public func applyPostProcessing(prompt: PostProcessingPrompt, to transcription: Transcription) async {
        guard !isProcessingAI else { return }

        isProcessingAI = true
        defer { isProcessingAI = false }

        do {
            let processedText = try await PostProcessingService.shared.processTranscription(
                transcription.rawText,
                with: prompt
            )

            let updatedTranscription = Transcription(
                id: transcription.id,
                meeting: transcription.meeting,
                segments: transcription.segments,
                text: transcription.text,
                rawText: transcription.rawText,
                processedContent: processedText,
                postProcessingPromptId: prompt.id,
                postProcessingPromptTitle: prompt.title,
                language: transcription.language,
                createdAt: transcription.createdAt,
                modelName: transcription.modelName
            )

            try await storage.saveTranscription(updatedTranscription)

            // Update local state
            selectedTranscription = updatedTranscription

            // Refresh metadata to show the "sparkles" icon in the list if needed
            await loadTranscriptions()

        } catch {
            logger.error("Failed to apply post-processing: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
}
