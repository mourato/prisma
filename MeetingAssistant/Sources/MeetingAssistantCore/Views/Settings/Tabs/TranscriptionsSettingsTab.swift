import SwiftUI
import UniformTypeIdentifiers

/// Main tab for managing transcriptions in Settings.
public struct TranscriptionsSettingsTab: View {
    @State private var transcriptions: [Transcription] = []
    @State private var selectedTranscription: Transcription?
    @State private var isLoading = true
    @State private var isDropTargeted = false

    private let storage = FileSystemStorageService.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            self.headerSection
            Divider()
            self.contentSection
        }
        .task {
            await self.loadTranscriptions()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            Text("Transcrições")
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()

            Button("Abrir Pasta") {
                NSWorkspace.shared.open(self.storage.recordingsDirectory)
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    // MARK: - Content Section

    private var contentSection: some View {
        HSplitView {
            self.leftPanel
                .frame(minWidth: 280, idealWidth: 320, maxWidth: 400)

            self.rightPanel
                .frame(minWidth: 400)
        }
    }

    // MARK: - Left Panel

    private var leftPanel: some View {
        VStack(spacing: 0) {
            self.dropZone
                .padding()

            Divider()

            if self.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if self.transcriptions.isEmpty {
                self.emptyState
            } else {
                self.transcriptionsList
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var dropZone: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.down.doc")
                .font(.title)
                .foregroundStyle(.secondary)

            VStack(spacing: 2) {
                Text("Solte arquivos de áudio ou vídeo")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("ou clique para importar • .aac, .m4a, .mp3, .wav")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    self.isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.3),
                    style: StrokeStyle(lineWidth: 2, dash: [6])
                )
                .background(
                    self.isDropTargeted
                        ? Color.accentColor.opacity(0.1)
                        : Color.clear
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            self.selectAndImportFile()
        }
        .onDrop(of: [.audio, .fileURL], isTargeted: self.$isDropTargeted) { providers in
            self.handleDrop(providers: providers)
            return true
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("Nenhuma transcrição")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Grave uma reunião ou importe um arquivo de áudio")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var transcriptionsList: some View {
        List(self.transcriptions, selection: self.$selectedTranscription) { transcription in
            TranscriptionRowView(transcription: transcription)
                .tag(transcription)
        }
        .listStyle(.plain)
    }

    // MARK: - Right Panel

    private var rightPanel: some View {
        Group {
            if let selected = selectedTranscription {
                TranscriptionDetailView(transcription: selected)
            } else {
                self.noSelectionView
            }
        }
    }

    private var noSelectionView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("Selecione uma transcrição")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func loadTranscriptions() async {
        self.isLoading = true
        do {
            self.transcriptions = try await self.storage.loadTranscriptions()
        } catch {
            print("Failed to load transcriptions: \(error)")
        }
        self.isLoading = false
    }

    private func selectAndImportFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.audio, .mpeg4Audio, .mp3, .wav]
        panel.message = "Selecione um arquivo de áudio para transcrever"
        panel.prompt = "Transcrever"

        if panel.runModal() == .OK, let url = panel.url {
            Task {
                await RecordingManager.shared.transcribeExternalAudio(from: url)
                await self.loadTranscriptions()
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil)
                else { return }

                let validExtensions = ["m4a", "mp3", "wav", "aac"]
                guard validExtensions.contains(url.pathExtension.lowercased()) else { return }

                Task { @MainActor in
                    await RecordingManager.shared.transcribeExternalAudio(from: url)
                    await self.loadTranscriptions()
                }
            }
        }
    }
}

// MARK: - Transcription Row View

struct TranscriptionRowView: View {
    let transcription: Transcription

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: self.transcription.meeting.appIcon)
                .font(.title2)
                .foregroundStyle(self.transcription.meeting.appColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(self.transcription.formattedDate)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(self.transcription.truncatedPreview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(self.transcription.formattedTime)
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                if self.transcription.isPostProcessed {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    TranscriptionsSettingsTab()
        .frame(width: 800, height: 600)
}
