import AppKit
import Foundation
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
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
                Task {
                    self.selectedTranscription = nil
                }
            }
        }
    }

    @Published public var isProcessingAI = false

    @Published public var isLoading = true
    @Published public var sourceFilter: RecordingSourceFilter = .all
    @Published public var dateFilter: DateFilter = .today
    @Published public var errorMessage: String?

    private let storage: StorageService
    private let recordingManager: RecordingManager
    private let meetingRepository: MeetingRepository
    private let logger = Logger(subsystem: "MeetingAssistant", category: "TranscriptionSettingsViewModel")

    public init(
        storage: StorageService = FileSystemStorageService.shared,
        recordingManager: RecordingManager = .shared,
        meetingRepository: MeetingRepository = CoreDataMeetingRepository()
    ) {
        self.storage = storage
        self.recordingManager = recordingManager
        self.meetingRepository = meetingRepository
    }

    public var filteredTranscriptions: [TranscriptionMetadata] {
        transcriptions.filter { transcription in
            let matchesSource = self.matchesSourceFilter(transcription)
            let matchesDate = self.dateFilter.contains(transcription.createdAt)
            return matchesSource && matchesDate
        }
    }

    /// Transcriptions grouped by date (start of day) for section headers.
    public var groupedTranscriptions: [Date: [TranscriptionMetadata]] {
        Dictionary(grouping: filteredTranscriptions) { metadata in
            Calendar.current.startOfDay(for: metadata.createdAt)
        }
    }

    /// Sorted list of dates for the group headers.
    public var sortedGroupDates: [Date] {
        groupedTranscriptions.keys.sorted(by: >)
    }

    private func matchesSourceFilter(_ transcription: TranscriptionMetadata) -> Bool {
        let app = MeetingApp(rawValue: transcription.appRawValue) ?? .unknown

        switch sourceFilter {
        case .all:
            return true
        case .dictations:
            // Dictation = Unknown app source (menu bar dictation) AND not imported file.
            if app == .importedFile { return false }
            return app == .unknown
        case .meetings:
            if app == .importedFile { return false }
            return app != .unknown
        case .manualImports:
            return app == .importedFile
        }
    }

    public func loadTranscriptions() async {
        isLoading = true
        do {
            let allTranscriptions = try await storage.loadAllMetadata()
            // Filter out items with errors or verify integrity if needed.
            // Assuming errors in capture manifest as 0 duration or specific metadata flags if we had them.
            // For now, ensuring we don't show items that are clearly failed (e.g. 0 duration and no text)
            transcriptions = allTranscriptions.filter { !($0.duration == 0 && $0.previewText.isEmpty) }
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

    public var availablePrompts: [PostProcessingPrompt] {
        AppSettingsStore.shared.allPrompts
    }

    public func applyPostProcessing(prompt: PostProcessingPrompt, to transcription: Transcription) async {
        guard !isProcessingAI else { return }

        isProcessingAI = true
        let startTime = Date()
        defer { isProcessingAI = false }

        do {
            let processedText = try await PostProcessingService.shared.processTranscription(
                transcription.rawText,
                with: prompt
            )

            let duration = Date().timeIntervalSince(startTime)
            let config = AppSettingsStore.shared.aiConfiguration
            let modelUsed = config.selectedModel

            let updatedTranscription = Transcription(
                id: transcription.id,
                meeting: transcription.meeting,
                contextItems: transcription.contextItems,
                segments: transcription.segments,
                text: transcription.text,
                rawText: transcription.rawText,
                processedContent: processedText,
                postProcessingPromptId: prompt.id,
                postProcessingPromptTitle: prompt.title,
                language: transcription.language,
                createdAt: transcription.createdAt,
                modelName: transcription.modelName,
                inputSource: transcription.inputSource,
                transcriptionDuration: transcription.transcriptionDuration,
                postProcessingDuration: duration,
                postProcessingModel: modelUsed
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

    public func deleteTranscription(_ metadata: TranscriptionMetadata) async {
        do {
            try await storage.deleteTranscription(by: metadata.id)
            if selectedId == metadata.id {
                selectedId = nil
            }
            await loadTranscriptions()
        } catch {
            logger.error("Failed to delete transcription: \(error.localizedDescription)")
            errorMessage = "Failed to delete: \(error.localizedDescription)"
        }
    }

    public func retryTranscription(for metadata: TranscriptionMetadata) async {
        guard !recordingManager.isTranscribing else {
            return
        }

        do {
            guard let transcription = try await storage.loadTranscription(by: metadata.id) else {
                errorMessage = "transcription.retry.missing_transcription".localized
                return
            }

            guard let audioURL = transcription.audioURL else {
                errorMessage = "transcription.retry.missing_audio".localized
                return
            }

            guard FileManager.default.fileExists(atPath: audioURL.path) else {
                errorMessage = "transcription.retry.missing_audio".localized
                return
            }

            await recordingManager.retryTranscription(for: transcription)
            await loadTranscriptions()
            if selectedId == metadata.id {
                await loadFullTranscription(id: metadata.id)
            }
        } catch {
            logger.error("Failed to retry transcription: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    public func updateSource(for metadata: TranscriptionMetadata, isMeeting: Bool) async {
        let app = MeetingApp(rawValue: metadata.appRawValue) ?? .unknown
        guard app != .importedFile else { return }
        guard app == .unknown || app == .manualMeeting else { return }

        let targetApp: DomainMeetingApp = isMeeting ? .manualMeeting : .unknown

        do {
            let existing = try await meetingRepository.fetchMeeting(by: metadata.meetingId)
            let endTime = metadata.duration > 0
                ? metadata.startTime.addingTimeInterval(metadata.duration)
                : nil

            let updatedMeeting = MeetingEntity(
                id: metadata.meetingId,
                app: targetApp,
                startTime: existing?.startTime ?? metadata.startTime,
                endTime: existing?.endTime ?? endTime,
                audioFilePath: existing?.audioFilePath ?? metadata.audioFilePath
            )

            try await meetingRepository.updateMeeting(updatedMeeting)
            await loadTranscriptions()
            if selectedId == metadata.id {
                await loadFullTranscription(id: metadata.id)
            }
        } catch {
            logger.error("Failed to update recording source: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
}
