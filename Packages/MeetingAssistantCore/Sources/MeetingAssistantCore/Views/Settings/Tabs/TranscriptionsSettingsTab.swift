import OSLog
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Main Tab

/// Main tab for managing transcriptions in Settings.
public struct TranscriptionsSettingsTab: View {
    @StateObject private var viewModel = TranscriptionSettingsViewModel()
    @StateObject private var importViewModel: TranscriptionImportViewModel

    public init() {
        // Initialize importViewModel with a closure to refresh the list
        let vm = TranscriptionSettingsViewModel()
        _viewModel = StateObject(wrappedValue: vm)
        _importViewModel = StateObject(wrappedValue: TranscriptionImportViewModel(onImportSuccess: {
            await vm.loadTranscriptions()
        }))
    }

    public var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
            contentSection
        }
        .task {
            await viewModel.loadTranscriptions()
        }
        .alert(
            NSLocalizedString("settings.transcriptions.error_load", bundle: .safeModule, comment: ""),
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(NSLocalizedString("settings.transcriptions.title", bundle: .safeModule, comment: ""))
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                Text(
                    String.localizedStringWithFormat(
                        NSLocalizedString("settings.transcriptions.items_found", bundle: .safeModule, comment: ""),
                        viewModel.filteredTranscriptions.count
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button(
                action: { viewModel.openRecordingsDirectory() },
                label: {
                    Label(NSLocalizedString("settings.transcriptions.open_folder", bundle: .safeModule, comment: ""), systemImage: "folder")
                }
            )
            .buttonStyle(.bordered)
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    // MARK: - Content Section

    private var contentSection: some View {
        leftPanel
            .frame(maxWidth: .infinity)
    }

    // MARK: - Left Panel

    private var leftPanel: some View {
        VStack(spacing: 0) {
            VStack(spacing: 20) {
                dropZone

                HStack(spacing: 16) {
                    sourceFilterPicker
                        .frame(maxWidth: .infinity)

                    dateFilterMenu
                        .frame(width: 140)
                }
            }
            .padding(24)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

            Divider()

            if viewModel.isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.large)
                    Text(NSLocalizedString("settings.transcriptions.loading", bundle: .safeModule, comment: ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.filteredTranscriptions.isEmpty {
                emptyState
            } else {
                transcriptionsList
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
                Text(NSLocalizedString("settings.transcriptions.filters", bundle: .safeModule, comment: ""))
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
            }

            sourceFilterPicker

            dateFilterMenu
        }
    }

    private var sourceFilterPicker: some View {
        Picker(
            NSLocalizedString("settings.transcriptions.source", bundle: .safeModule, comment: ""),
            selection: $viewModel.sourceFilter
        ) {
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
                    viewModel.dateFilter = filter
                } label: {
                    HStack {
                        Text(filter.displayName)
                        if viewModel.dateFilter == filter {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(Color.accentColor)
                Text(viewModel.dateFilter.displayName)
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
                .foregroundStyle(SettingsDesignSystem.Colors.iconHighlight)
                .symbolEffect(.bounce, value: importViewModel.isDropTargeted)

            VStack(spacing: 4) {
                Text(NSLocalizedString("settings.transcriptions.import", bundle: .safeModule, comment: ""))
                    .font(.headline)

                Text(NSLocalizedString("settings.transcriptions.import_desc", bundle: .safeModule, comment: ""))
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
                    importViewModel.isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.2),
                    style: StrokeStyle(lineWidth: 2, dash: [4, 4])
                )
                .background(
                    importViewModel.isDropTargeted
                        ? Color.accentColor.opacity(0.1)
                        : Color.primary.opacity(0.02)
                )
        )
        .onTapGesture {
            importViewModel.selectAndImportFile()
        }
        .onDrop(of: [.audio, .fileURL], isTargeted: $importViewModel.isDropTargeted) { providers in
            importViewModel.handleDrop(providers: providers)
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
                Text(NSLocalizedString("settings.transcriptions.empty_title", bundle: .safeModule, comment: ""))
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text(NSLocalizedString("settings.transcriptions.empty_desc", bundle: .safeModule, comment: ""))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var transcriptionsList: some View {
        List(selection: $viewModel.selectedId) {
            ForEach(viewModel.sortedGroupDates, id: \.self) { date in
                Section(
                    header: Text(formatHeaderDate(date))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                ) {
                    ForEach(viewModel.groupedTranscriptions[date] ?? []) { transcription in
                        TranscriptionCardView(
                            transcription: transcription,
                            transcriptionDetail: viewModel.selectedId == transcription.id ? viewModel.selectedTranscription : nil,
                            isExpanded: viewModel.selectedId == transcription.id,
                            audioURL: transcription.audioFilePath != nil ? URL(fileURLWithPath: transcription.audioFilePath!) : nil,
                            availablePrompts: viewModel.availablePrompts,
                            onToggleExpand: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    if viewModel.selectedId == transcription.id {
                                        viewModel.selectedId = nil
                                    } else {
                                        viewModel.selectedId = transcription.id
                                    }
                                }
                            },
                            onAction: { action in
                                handleTranscriptionAction(action, for: transcription)
                            }
                        )
                        .tag(transcription.id)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 12, trailing: 16))
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private func formatHeaderDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "pt_BR")

        if Calendar.current.isDateInToday(date) {
            return "settings.transcriptions.today".localized
        } else if Calendar.current.isDateInYesterday(date) {
            return "settings.transcriptions.yesterday".localized
        }

        return formatter.string(from: date)
    }

    private func handleTranscriptionAction(_ action: TranscriptionCardView.TranscriptionAction, for metadata: TranscriptionMetadata) {
        switch action {
        case let .copy(text):
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        case let .reprocess(prompt):
            if let transcription = viewModel.selectedTranscription, transcription.id == metadata.id {
                Task {
                    await viewModel.applyPostProcessing(prompt: prompt, to: transcription)
                }
            }
        case .info:
            // Info is handled locally in the view via popover, this likely won't be called if logic is in view
            // But if we wanted to show a global panel, we'd do it here.
            // Since we implemented popover in card, this case might be unused or for logging.
            break
        case .retryTranscription:
            Task {
                await viewModel.retryTranscription(for: metadata)
            }
        case .delete:
            Task {
                await viewModel.deleteTranscription(metadata)
            }
        }
    }

    // MARK: - Right Panel

    private var rightPanel: some View {
        Group {
            if let selected = viewModel.selectedTranscription {
                TranscriptionDetailView(
                    transcription: selected,
                    isProcessing: viewModel.isProcessingAI,
                    onApplyPrompt: { prompt in
                        Task {
                            await viewModel.applyPostProcessing(prompt: prompt, to: selected)
                        }
                    }
                )
            } else {
                noSelectionView
            }
        }
    }

    private var noSelectionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 64))
                .foregroundStyle(.tertiary)
                .opacity(0.5)

            Text(NSLocalizedString("settings.transcriptions.no_selection", bundle: .safeModule, comment: ""))
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
    let metadata: TranscriptionMetadata

    private var appColor: Color {
        MeetingApp(rawValue: metadata.appRawValue)?.color ?? .gray
    }

    private var appIcon: String {
        MeetingApp(rawValue: metadata.appRawValue)?.icon ?? "questionmark.circle"
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: metadata.createdAt)
    }

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: metadata.createdAt)
    }

    private var previewText: String {
        let trimmed = metadata.previewText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "transcription.empty_fallback".localized
        }
        return metadata.previewText
    }

    private var isFallbackText: Bool {
        metadata.previewText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(appColor.opacity(0.1))
                    .frame(width: 40, height: 40)

                Image(systemName: appIcon)
                    .font(.title3)
                    .foregroundStyle(appColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(formattedDate)
                    .font(.body)
                    .fontWeight(.semibold)

                Text(previewText)
                    .font(isFallbackText ? .caption.italic() : .caption)
                    .foregroundStyle(isFallbackText ? .tertiary : .secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(formattedTime)
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)

                if metadata.isPostProcessed {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundStyle(SettingsDesignSystem.Colors.iconHighlight)
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
