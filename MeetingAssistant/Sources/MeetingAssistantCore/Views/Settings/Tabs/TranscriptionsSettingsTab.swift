import OSLog
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Main Tab

/// Main tab for managing transcriptions in Settings.
public struct TranscriptionsSettingsTab: View {
    @StateObject private var viewModel = TranscriptionSettingsViewModel()

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            self.headerSection
            Divider()
            self.contentSection
        }
        .task {
            await self.viewModel.loadTranscriptions()
        }
        .alert(
            "Erro ao carregar transcrições",
            isPresented: Binding(
                get: { self.viewModel.errorMessage != nil },
                set: { if !$0 { self.viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                self.viewModel.errorMessage = nil
            }
        } message: {
            if let errorMessage = self.viewModel.errorMessage {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Transcrições")
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                Text("\(self.viewModel.filteredTranscriptions.count) itens encontrados")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: { self.viewModel.openRecordingsDirectory() }) {
                Label("Abrir Pasta", systemImage: "folder")
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    // MARK: - Content Section

    private var contentSection: some View {
        HSplitView {
            self.leftPanel
                .frame(minWidth: 280, idealWidth: 320, maxWidth: 450)

            self.rightPanel
                .frame(minWidth: 420)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        }
    }

    // MARK: - Left Panel

    private var leftPanel: some View {
        VStack(spacing: 0) {
            self.dropZone
                .padding()

            Divider()

            self.filtersSection
                .padding(.horizontal)
                .padding(.vertical, 12)

            Divider()

            if self.viewModel.isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.large)
                    Text("Carregando...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if self.viewModel.filteredTranscriptions.isEmpty {
                self.emptyState
            } else {
                self.transcriptionsList
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Filters Section

    private var filtersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .foregroundStyle(.secondary)
                Text("FILTROS")
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
            }

            self.sourceFilterPicker

            self.dateFilterMenu
        }
    }

    private var sourceFilterPicker: some View {
        Picker("Origem", selection: self.$viewModel.sourceFilter) {
            ForEach(RecordingSourceFilter.allCases, id: \.self) { filter in
                Text(filter.displayName).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .controlSize(.small)
    }

    private var dateFilterMenu: some View {
        Menu {
            ForEach(DateFilter.allCases, id: \.self) { filter in
                Button {
                    self.viewModel.dateFilter = filter
                } label: {
                    HStack {
                        Text(filter.displayName)
                        if self.viewModel.dateFilter == filter {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(.accentColor)
                Text(self.viewModel.dateFilter.displayName)
                    .font(.subheadline)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .menuStyle(.borderlessButton)
    }

    private var dropZone: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray.and.arrow.down.fill")
                .font(.system(size: 28))
                .foregroundStyle(SettingsDesignSystem.Colors.aiGradient)
                .symbolEffect(.bounce, value: self.viewModel.isDropTargeted)

            VStack(spacing: 4) {
                Text("Importar Arquivo")
                    .font(.headline)

                Text("Arraste ou clique para importar áudio/vídeo")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    self.viewModel.isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.2),
                    style: StrokeStyle(lineWidth: 2, dash: [4, 4])
                )
                .background(
                    self.viewModel.isDropTargeted
                        ? Color.accentColor.opacity(0.1)
                        : Color.primary.opacity(0.02)
                )
        )
        .onTapGesture {
            self.viewModel.selectAndImportFile()
        }
        .onDrop(of: [.audio, .fileURL], isTargeted: self.$viewModel.isDropTargeted) { providers in
            self.viewModel.handleDrop(providers: providers)
            return true
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
                .symbolEffect(.pulse)

            VStack(spacing: 4) {
                Text("Sem transcrições")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text("Grave uma reunião ou importe um áudio")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var transcriptionsList: some View {
        List(self.viewModel.filteredTranscriptions, selection: self.$viewModel.selectedTranscription) { transcription in
            TranscriptionRowView(transcription: transcription)
                .tag(transcription)
                .listRowSeparator(.visible, edges: .bottom)
        }
        .listStyle(.inset)
    }

    // MARK: - Right Panel

    private var rightPanel: some View {
        Group {
            if let selected = self.viewModel.selectedTranscription {
                TranscriptionDetailView(transcription: selected)
            } else {
                self.noSelectionView
            }
        }
    }

    private var noSelectionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 64))
                .foregroundStyle(.tertiary)
                .opacity(0.5)

            Text("Selecione uma transcrição para visualizar os detalhes")
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Transcription Row View

struct TranscriptionRowView: View {
    let transcription: Transcription

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(self.transcription.meeting.appColor.opacity(0.1))
                    .frame(width: 40, height: 40)

                Image(systemName: self.transcription.meeting.appIcon)
                    .font(.title3)
                    .foregroundStyle(self.transcription.meeting.appColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(self.transcription.formattedDate)
                    .font(.body)
                    .fontWeight(.semibold)

                Text(self.transcription.truncatedPreview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(self.transcription.formattedTime)
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)

                if self.transcription.isPostProcessed {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundStyle(SettingsDesignSystem.Colors.aiGradient)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    TranscriptionsSettingsTab()
        .frame(width: 800, height: 600)
}
