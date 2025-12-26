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
    @Published public var isDropTargeted = false
    @Published public var sourceFilter: RecordingSourceFilter = .all
    @Published public var dateFilter: DateFilter = .allEntries
    @Published public var errorMessage: String?

    private let storage = FileSystemStorageService.shared
    private let logger = Logger(subsystem: "MeetingAssistant", category: "TranscriptionSettingsViewModel")

    public init() {}

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
            self.errorMessage = "Não foi possível carregar as transcrições. Tente novamente."
        }
        self.isLoading = false
    }

    public func selectAndImportFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [
            .audio, .mpeg4Audio, .mp3, .wav,
            .movie, .mpeg4Movie, .quickTimeMovie,
        ]
        panel.message = "Selecione um arquivo de áudio ou vídeo para transcrever"
        panel.prompt = "Transcrever"

        if panel.runModal() == .OK, let url = panel.url {
            Task {
                await RecordingManager.shared.transcribeExternalAudio(from: url)
                await self.loadTranscriptions()
            }
        }
    }

    public func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil)
                else { return }

                let audioTypes = ["m4a", "mp3", "wav", "aac"]
                let videoTypes = ["mov", "mp4", "m4v"]
                let allTypes = audioTypes + videoTypes

                guard allTypes.contains(url.pathExtension.lowercased()) else { return }

                Task { @MainActor in
                    await RecordingManager.shared.transcribeExternalAudio(from: url)
                    await self?.loadTranscriptions()
                }
            }
        }
    }

    public func openRecordingsDirectory() {
        NSWorkspace.shared.open(self.storage.recordingsDirectory)
    }
}
