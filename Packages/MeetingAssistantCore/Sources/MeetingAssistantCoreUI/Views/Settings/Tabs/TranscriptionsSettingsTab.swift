import Combine
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import OSLog
import SwiftUI

// MARK: - Main Tab

/// Main tab for managing transcriptions in Settings.
public struct TranscriptionsSettingsTab: View {
    private enum Layout {
        static let controlHeight: CGFloat = MeetingAssistantDesignSystem.Layout.compactButtonHeight
        static let searchWidthRatio: CGFloat = 0.6
        static let minSearchWidth: CGFloat = 240
        static let maxSearchWidth: CGFloat = 520
    }

    @StateObject private var viewModel = TranscriptionSettingsViewModel()
    @State private var searchReloadTask: Task<Void, Never>?
    @State private var conversationTranscriptionID: UUID?

    public var body: some View {
        VStack(spacing: 0) {
            contentSection
        }
        .task {
            await viewModel.loadTranscriptions()
        }
        .onReceive(NotificationCenter.default.publisher(for: .meetingAssistantTranscriptionSaved)) { _ in
            Task {
                await viewModel.loadTranscriptions()
            }
        }
        .onChange(of: viewModel.sourceFilter) { _, _ in
            Task {
                await viewModel.loadTranscriptions()
            }
        }
        .onChange(of: viewModel.dateFilter) { _, _ in
            Task {
                await viewModel.loadTranscriptions()
            }
        }
        .onChange(of: viewModel.appFilterId) { _, _ in
            Task {
                await viewModel.loadTranscriptions()
            }
        }
        .onChange(of: viewModel.searchText) { _, _ in
            searchReloadTask?.cancel()
            searchReloadTask = Task {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                await viewModel.loadTranscriptions()
            }
        }
        .onDisappear {
            searchReloadTask?.cancel()
            searchReloadTask = nil
        }
        .onChange(of: viewModel.transcriptions) { _, transcriptions in
            guard let conversationTranscriptionID else { return }
            if !transcriptions.contains(where: { $0.id == conversationTranscriptionID }) {
                closeConversationPanel()
            }
        }
        .alert(
            "settings.transcriptions.error_load".localized,
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("common.ok".localized, role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Content Section

    private var contentSection: some View {
        HSplitView {
            leftPanel
                .frame(minWidth: 620, idealWidth: 780, maxWidth: .infinity)

            if let conversationTranscriptionID {
                conversationPanel(transcriptionID: conversationTranscriptionID)
                    .frame(minWidth: 360, idealWidth: 480, maxWidth: 640)
            }
        }
    }

    // MARK: - Left Panel

    private var leftPanel: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing16) {
                searchAndFolderRow

                HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing16) {
                    sourceFilterPicker
                        .frame(maxWidth: .infinity)

                    appFilterMenu
                        .frame(width: 170)

                    dateFilterMenu
                        .frame(width: MeetingAssistantDesignSystem.Layout.narrowPickerWidth)
                }

                Text(
                    "settings.transcriptions.items_found".localized(with: viewModel.filteredTranscriptions.count)
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(MeetingAssistantDesignSystem.Layout.spacing24)

            Divider()

            if viewModel.isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.large)
                    Text("settings.transcriptions.loading".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, MeetingAssistantDesignSystem.Layout.spacing8)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.filteredTranscriptions.isEmpty {
                emptyState
            } else {
                transcriptionsList
            }
        }
        .background(MeetingAssistantDesignSystem.Colors.windowBackground)
    }

    private var searchAndFolderRow: some View {
        GeometryReader { geometry in
            let searchWidth = min(
                Layout.maxSearchWidth,
                max(Layout.minSearchWidth, geometry.size.width * Layout.searchWidthRatio)
            )

            HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing16) {
                searchField
                    .frame(width: searchWidth)

                Spacer(minLength: 0)

                openFolderButton
            }
        }
        .frame(height: Layout.controlHeight)
    }

    private var openFolderButton: some View {
        Button(action: { viewModel.openRecordingsDirectory() }) {
            Label("settings.transcriptions.open_folder".localized, systemImage: "folder")
                .font(.body)
                .clipShape(RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.smallCornerRadius))
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    private var sourceFilterPicker: some View {
        Picker(
            "",
            selection: $viewModel.sourceFilter
        ) {
            ForEach(RecordingSourceFilter.allCases, id: \.self) { filter in
                Text(filter.displayName).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .controlSize(.regular)
        .labelsHidden()
    }

    private var searchField: some View {
        HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(
                "settings.transcriptions.search_placeholder".localized,
                text: $viewModel.searchText
            )
            .textFieldStyle(.plain)
        }
        .padding(.horizontal, MeetingAssistantDesignSystem.Layout.spacing10)
        .padding(.vertical, MeetingAssistantDesignSystem.Layout.spacing8)
        .frame(height: Layout.controlHeight)
        .background(MeetingAssistantDesignSystem.Colors.subtleFill)
        .clipShape(RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.smallCornerRadius))
    }

    private var appFilterMenu: some View {
        Menu {
            ForEach(viewModel.appFilterOptions) { option in
                Button {
                    viewModel.appFilterId = option.id
                } label: {
                    HStack {
                        Text(option.displayName)
                        if viewModel.appFilterId == option.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack {
                Image(systemName: "desktopcomputer")
                    .foregroundStyle(MeetingAssistantDesignSystem.Colors.accent)
                Text(selectedAppFilterLabel)
                    .font(.body)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .controlSize(.regular)
            .padding(.horizontal, MeetingAssistantDesignSystem.Layout.spacing10)
            .padding(.vertical, MeetingAssistantDesignSystem.Layout.spacing8)
            .background(MeetingAssistantDesignSystem.Colors.subtleFill)
            .clipShape(RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.smallCornerRadius))
        }
        .menuStyle(.borderlessButton)
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
                    .foregroundStyle(MeetingAssistantDesignSystem.Colors.accent)
                Text(viewModel.dateFilter.displayName)
                    .font(.body)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, MeetingAssistantDesignSystem.Layout.spacing10)
            .padding(.vertical, MeetingAssistantDesignSystem.Layout.spacing8)
            .background(MeetingAssistantDesignSystem.Colors.subtleFill)
            .clipShape(RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.smallCornerRadius))
        }
        .menuStyle(.borderlessButton)
    }

    private var selectedAppFilterLabel: String {
        viewModel.appFilterOptions.first(where: { $0.id == viewModel.appFilterId })?.displayName
            ?? "settings.transcriptions.filter_app_all".localized
    }

    private var emptyState: some View {
        VStack(spacing: MeetingAssistantDesignSystem.Layout.spacing16) {
            Image(systemName: "doc.text.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)

            VStack(spacing: 4) {
                Text("settings.transcriptions.empty_title".localized)
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text("settings.transcriptions.empty_desc".localized)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var transcriptionsList: some View {
        List {
            ForEach(viewModel.sortedGroupDates, id: \.self) { date in
                Section(
                    header: Text(formatHeaderDate(date))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                        .padding(.top, MeetingAssistantDesignSystem.Layout.spacing16)
                        .padding(.bottom, MeetingAssistantDesignSystem.Layout.spacing8)
                ) {
                    ForEach(viewModel.groupedTranscriptions[date] ?? []) { transcription in
                        HStack(alignment: .top, spacing: MeetingAssistantDesignSystem.Layout.spacing16) {
                            Text(formatTime(transcription.createdAt))
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .padding(.top, 12) // Align with card content
                                .frame(width: 50, alignment: .trailing)

                            TranscriptionCardView(
                                transcription: transcription,
                                transcriptionDetail: viewModel.selectedId == transcription.id ? viewModel.selectedTranscription : nil,
                                isExpanded: viewModel.selectedId == transcription.id,
                                audioURL: transcription.audioFilePath != nil ? URL(fileURLWithPath: transcription.audioFilePath!) : nil,
                                availablePrompts: viewModel.availablePrompts(for: transcription),
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
                        }
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

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func handleTranscriptionAction(_ action: TranscriptionCardView.TranscriptionAction, for metadata: TranscriptionMetadata) {
        switch action {
        case .askAboutMeeting:
            openConversation(for: metadata)
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
                if conversationTranscriptionID == metadata.id {
                    closeConversationPanel()
                }
            }
        }
    }

    @ViewBuilder
    private func conversationPanel(transcriptionID: UUID) -> some View {
        let activeTranscription = viewModel.selectedTranscription?.id == transcriptionID ? viewModel.selectedTranscription : nil

        MeetingConversationView(
            transcription: activeTranscription,
            isLoadingTranscription: activeTranscription == nil,
            turns: viewModel.qaHistory(for: transcriptionID),
            questionText: viewModel.qaQuestion,
            onQuestionChange: { newValue in
                viewModel.qaQuestion = newValue
            },
            onAsk: {
                guard let transcription = viewModel.selectedTranscription, transcription.id == transcriptionID else { return }
                Task {
                    await viewModel.submitQuestion(for: transcription)
                }
            },
            onRetry: { question in
                guard let transcription = viewModel.selectedTranscription, transcription.id == transcriptionID else { return }
                Task {
                    await viewModel.retryQuestion(question, for: transcription)
                }
            },
            isAnswering: viewModel.isAnsweringQuestion,
            currentErrorMessage: viewModel.qaErrorMessage,
            onClose: {
                closeConversationPanel()
            }
        )
    }

    private func openConversation(for metadata: TranscriptionMetadata) {
        conversationTranscriptionID = metadata.id
        viewModel.selectedId = metadata.id
        viewModel.clearQuestionComposer()
        Task {
            await viewModel.loadFullTranscription(id: metadata.id)
        }
    }

    private func closeConversationPanel() {
        conversationTranscriptionID = nil
        viewModel.clearQuestionComposer()
    }

    // MARK: - Right Panel

    private var rightPanel: some View {
        Group {
            if let selected = viewModel.selectedTranscription {
                TranscriptionDetailView(
                    transcription: selected,
                    isProcessing: viewModel.isProcessingAI,
                    isSourceEditable: isSourceEditable(selected),
                    onApplyPrompt: { prompt in
                        Task {
                            await viewModel.applyPostProcessing(prompt: prompt, to: selected)
                        }
                    },
                    onUpdateSource: { isMeeting in
                        if let metadata = viewModel.transcriptions.first(where: { $0.id == selected.id }) {
                            Task {
                                await viewModel.updateSource(for: metadata, isMeeting: isMeeting)
                            }
                        }
                    },
                    isQnAEnabled: viewModel.isMeetingQnAEnabled,
                    qaQuestion: viewModel.qaQuestion,
                    onQuestionChange: { newValue in
                        viewModel.qaQuestion = newValue
                    },
                    onAskQuestion: {
                        Task {
                            await viewModel.submitQuestion(for: selected)
                        }
                    },
                    onRetryQuestion: {
                        Task {
                            await viewModel.retryLastQuestion(for: selected)
                        }
                    },
                    qaResponse: viewModel.qaResponse,
                    qaErrorMessage: viewModel.qaErrorMessage,
                    isAnsweringQuestion: viewModel.isAnsweringQuestion
                )
            } else {
                noSelectionView
            }
        }
    }

    private func isSourceEditable(_ transcription: Transcription) -> Bool {
        transcription.meeting.app == .unknown || transcription.meeting.app == .manualMeeting
    }

    private var noSelectionView: some View {
        VStack(spacing: MeetingAssistantDesignSystem.Layout.spacing16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 64))
                .foregroundStyle(.tertiary)
                .opacity(0.5)

            Text("settings.transcriptions.no_selection".localized)
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

                AppIconView(
                    bundleIdentifier: metadata.appBundleIdentifier,
                    fallbackSystemName: appIcon,
                    size: 22,
                    cornerRadius: 5
                )
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
                    .foregroundStyle(.tertiary)

                if metadata.isPostProcessed {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundStyle(MeetingAssistantDesignSystem.Colors.iconHighlight)
                }
            }
        }
        .padding(.vertical, MeetingAssistantDesignSystem.Layout.spacing8)
    }
}

#Preview {
    TranscriptionsSettingsTab()
        .frame(width: 800, height: 600)
}
