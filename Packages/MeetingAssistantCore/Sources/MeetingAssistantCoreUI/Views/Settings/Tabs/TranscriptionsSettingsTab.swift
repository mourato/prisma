import Combine
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

// MARK: - Main Tab

/// Main tab for managing transcriptions in Settings.
public struct TranscriptionsSettingsTab: View {
    private enum Layout {
        static let controlHeight: CGFloat = AppDesignSystem.Layout.compactButtonHeight
        static let searchWidthRatio: CGFloat = 0.6
        static let minSearchWidth: CGFloat = 240
        static let maxSearchWidth: CGFloat = 520
    }

    @StateObject private var viewModel = TranscriptionSettingsViewModel()
    @StateObject private var dictationService = MeetingQuestionDictationService()
    @State private var searchReloadTask: Task<Void, Never>?
    @State private var navigationHistory = TranscriptionsNavigationHistory()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var currentRoute: TranscriptionsPageRoute {
        navigationHistory.currentRoute
    }

    public var body: some View {
        VStack(spacing: 0) {
            contentSection
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button(action: navigateBack) {
                    Image(systemName: "chevron.left")
                }
                .help("transcription.qa.navigation.back".localized)
                .accessibilityLabel("transcription.qa.navigation.back".localized)
                .disabled(!navigationHistory.canGoBack)

                Button(action: navigateForward) {
                    Image(systemName: "chevron.right")
                }
                .help("transcription.qa.navigation.forward".localized)
                .accessibilityLabel("transcription.qa.navigation.forward".localized)
                .disabled(!navigationHistory.canGoForward)
            }
        }
        .task {
            await viewModel.loadTranscriptions()
            syncSelectionForCurrentRoute()
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
            Task {
                await dictationService.cancel()
            }
        }
        .onChange(of: viewModel.transcriptions) { _, transcriptions in
            sanitizeNavigationHistory(using: transcriptions)
        }
    }

    // MARK: - Content Section

    @ViewBuilder
    private var contentSection: some View {
        switch currentRoute {
        case .list:
            listPage
        case let .conversation(transcriptionID):
            conversationPage(transcriptionID: transcriptionID)
        }
    }

    // MARK: - List Page

    private var listPage: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: AppDesignSystem.Layout.spacing16) {
                SettingsSectionHeader(
                    title: "settings.section.history".localized,
                    description: "settings.transcriptions.items_found".localized(with: viewModel.filteredTranscriptions.count)
                )

                searchAndFolderRow

                HStack(spacing: AppDesignSystem.Layout.spacing16) {
                    sourceFilterPicker
                        .frame(maxWidth: .infinity)

                    appFilterMenu
                        .frame(width: 170)

                    dateFilterMenu
                        .frame(width: AppDesignSystem.Layout.narrowPickerWidth)
                }

                if let errorMessage = viewModel.errorMessage {
                    SettingsStateBlock(
                        kind: .warning,
                        title: "settings.transcriptions.error_load".localized,
                        message: errorMessage,
                        actionTitle: "settings.service.verify".localized
                    ) {
                        Task {
                            await viewModel.loadTranscriptions()
                        }
                    }
                }
            }
            .padding(AppDesignSystem.Layout.spacing24)

            Divider()

            if viewModel.isLoading {
                SettingsStateBlock(
                    kind: .loading,
                    title: "settings.transcriptions.loading".localized
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(AppDesignSystem.Layout.spacing24)
            } else if viewModel.filteredTranscriptions.isEmpty {
                emptyState
            } else {
                transcriptionsList
            }
        }
        .background(AppDesignSystem.Colors.windowBackground)
    }

    private var searchAndFolderRow: some View {
        GeometryReader { geometry in
            let searchWidth = min(
                Layout.maxSearchWidth,
                max(Layout.minSearchWidth, geometry.size.width * Layout.searchWidthRatio)
            )

            HStack(spacing: AppDesignSystem.Layout.spacing16) {
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
                .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.Layout.smallCornerRadius))
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
        HStack(spacing: AppDesignSystem.Layout.spacing8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(
                "settings.transcriptions.search_placeholder".localized,
                text: $viewModel.searchText
            )
            .textFieldStyle(.plain)
        }
        .padding(.horizontal, AppDesignSystem.Layout.spacing10)
        .padding(.vertical, AppDesignSystem.Layout.spacing8)
        .frame(height: Layout.controlHeight)
        .background(AppDesignSystem.Colors.subtleFill)
        .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.Layout.smallCornerRadius))
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
                    .foregroundStyle(AppDesignSystem.Colors.accent)
                Text(selectedAppFilterLabel)
                    .font(.body)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .controlSize(.regular)
            .padding(.horizontal, AppDesignSystem.Layout.spacing10)
            .padding(.vertical, AppDesignSystem.Layout.spacing8)
            .background(AppDesignSystem.Colors.subtleFill)
            .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.Layout.smallCornerRadius))
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
                    .foregroundStyle(AppDesignSystem.Colors.accent)
                Text(viewModel.dateFilter.displayName)
                    .font(.body)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, AppDesignSystem.Layout.spacing10)
            .padding(.vertical, AppDesignSystem.Layout.spacing8)
            .background(AppDesignSystem.Colors.subtleFill)
            .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.Layout.smallCornerRadius))
        }
        .menuStyle(.borderlessButton)
    }

    private var selectedAppFilterLabel: String {
        viewModel.appFilterOptions.first(where: { $0.id == viewModel.appFilterId })?.displayName
            ?? "settings.transcriptions.filter_app_all".localized
    }

    private var emptyState: some View {
        SettingsStateBlock(
            kind: .empty,
            title: "settings.transcriptions.empty_title".localized,
            message: "settings.transcriptions.empty_desc".localized
        )
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
                        .padding(.top, AppDesignSystem.Layout.spacing16)
                        .padding(.bottom, AppDesignSystem.Layout.spacing8)
                ) {
                    ForEach(viewModel.groupedTranscriptions[date] ?? []) { transcription in
                        HStack(alignment: .top, spacing: AppDesignSystem.Layout.spacing16) {
                            Text(formatTime(transcription.createdAt))
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .padding(.top, 12)
                                .frame(width: 50, alignment: .trailing)

                            TranscriptionCardView(
                                transcription: transcription,
                                transcriptionDetail: viewModel.selectedId == transcription.id ? viewModel.selectedTranscription : nil,
                                isExpanded: viewModel.selectedId == transcription.id,
                                audioURL: transcription.audioFilePath != nil ? URL(fileURLWithPath: transcription.audioFilePath!) : nil,
                                availablePrompts: viewModel.availablePrompts(for: transcription),
                                isPostProcessing: viewModel.isPostProcessing(transcriptionID: transcription.id),
                                postProcessingErrorMessage: viewModel.postProcessingError(for: transcription.id),
                                onToggleExpand: {
                                    let toggleSelection = {
                                        if viewModel.selectedId == transcription.id {
                                            viewModel.selectedId = nil
                                        } else {
                                            viewModel.selectedId = transcription.id
                                        }
                                    }

                                    if reduceMotion {
                                        toggleSelection()
                                    } else {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                            toggleSelection()
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

    // MARK: - Conversation Page

    private func conversationPage(transcriptionID: UUID) -> some View {
        let activeTranscription = viewModel.selectedTranscription?.id == transcriptionID ? viewModel.selectedTranscription : nil

        return TranscriptionConversationPage(
            transcriptionID: transcriptionID,
            activeTranscription: activeTranscription,
            viewModel: viewModel,
            dictationService: dictationService,
            onToggleDictation: handleDictationToggle,
            onBack: navigateBack
        )
    }

    // MARK: - Navigation

    private func openConversation(for metadata: TranscriptionMetadata) {
        guard viewModel.canOpenMeetingConversation(for: metadata) else { return }
        navigationHistory.push(.conversation(metadata.id))
        viewModel.selectedId = metadata.id
        dictationService.clearError()
    }

    private func navigateBack() {
        guard navigationHistory.goBack() != nil else { return }
        syncSelectionForCurrentRoute()
    }

    private func navigateForward() {
        guard navigationHistory.goForward() != nil else { return }
        syncSelectionForCurrentRoute()
    }

    private func syncSelectionForCurrentRoute() {
        switch currentRoute {
        case .list:
            Task {
                await dictationService.cancel()
            }
        case let .conversation(transcriptionID):
            if viewModel.selectedId != transcriptionID {
                viewModel.selectedId = transcriptionID
            }
        }
    }

    private func sanitizeNavigationHistory(using transcriptions: [TranscriptionMetadata]) {
        let validIDs = Set(transcriptions.map(\.id))
        navigationHistory.sanitize(validConversationIDs: validIDs)
        syncSelectionForCurrentRoute()
    }

    // MARK: - Actions

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

    private func handleDictationToggle() {
        guard viewModel.selectedTranscription?.supportsMeetingConversation == true else {
            return
        }

        Task {
            if let transcribedText = await dictationService.toggleDictation() {
                appendDictationText(transcribedText)
            }
        }
    }

    private func appendDictationText(_ text: String) {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }

        let current = viewModel.qaQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        if current.isEmpty {
            viewModel.qaQuestion = normalized
            return
        }

        viewModel.qaQuestion = "\(current) \(normalized)"
    }

    // MARK: - Formatting

    private func formatHeaderDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale.current

        if Calendar.current.isDateInToday(date) {
            return "settings.transcriptions.today".localized
        } else if Calendar.current.isDateInYesterday(date) {
            return "settings.transcriptions.yesterday".localized
        }

        return formatter.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = Locale.current
        return formatter.string(from: date)
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
        formatter.locale = Locale.current
        return formatter.string(from: metadata.createdAt)
    }

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = Locale.current
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
                        .foregroundStyle(AppDesignSystem.Colors.iconHighlight)
                }
            }
        }
        .padding(.vertical, AppDesignSystem.Layout.spacing8)
    }
}

#Preview {
    TranscriptionsSettingsTab()
        .frame(width: 900, height: 620)
}
