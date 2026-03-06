import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

/// An expandable card for a transcription item.
public struct TranscriptionCardView: View {
    private enum Layout {
        static let contentLineLimit = 8
    }

    let transcription: TranscriptionMetadata
    let transcriptionDetail: Transcription?
    let isExpanded: Bool
    let audioURL: URL?
    let availablePrompts: [PostProcessingPrompt]
    let isPostProcessing: Bool
    let postProcessingErrorMessage: String?
    let onToggleExpand: () -> Void
    let onAction: (TranscriptionAction) -> Void

    public init(
        transcription: TranscriptionMetadata,
        transcriptionDetail: Transcription? = nil,
        isExpanded: Bool,
        audioURL: URL?,
        availablePrompts: [PostProcessingPrompt] = [],
        isPostProcessing: Bool = false,
        postProcessingErrorMessage: String? = nil,
        onToggleExpand: @escaping () -> Void,
        onAction: @escaping (TranscriptionAction) -> Void
    ) {
        self.transcription = transcription
        self.transcriptionDetail = transcriptionDetail
        self.isExpanded = isExpanded
        self.audioURL = audioURL
        self.availablePrompts = availablePrompts
        self.isPostProcessing = isPostProcessing
        self.postProcessingErrorMessage = postProcessingErrorMessage
        self.onToggleExpand = onToggleExpand
        self.onAction = onAction
    }

    @State private var selectedTab: TranscriptionTab = .aiProcessed
    @State private var showInfoPopover = false
    @State private var expandedTabs: Set<TranscriptionTab> = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public enum TranscriptionAction {
        case askAboutMeeting
        case copy(text: String)
        case reprocess(prompt: PostProcessingPrompt)
        case retryTranscription
        case info
        case delete
    }

    public enum TranscriptionTab: CaseIterable {
        case aiProcessed
        case original
        case segmented

        var localized: String {
            switch self {
            case .aiProcessed:
                "transcription.tab.ai_processed".localized
            case .original:
                "transcription.tab.original".localized
            case .segmented:
                "transcription.tab.segmented".localized
            }
        }
    }

    public var body: some View {
        DSCard(
            cornerRadius: AppDesignSystem.Layout.largeCornerRadius,
            padding: isExpanded ? AppDesignSystem.Layout.spacing16 : AppDesignSystem.Layout.spacing12
        ) {
            if isExpanded {
                expandedContent
            } else {
                collapsedContent
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onToggleExpand()
        }
        .onHover { isHovering in
            if isHovering {
                NSCursor.pointingHand.set()
            } else {
                NSCursor.arrow.set()
            }
        }
    }

    private var collapsedContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(displayTitle)
                .font(.headline)
                .lineLimit(1)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(displayText(transcription.previewText))
                .font(.body)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            sourceLabel(text: sourceDisplayName)
        }
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(displayTitle)
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)

                sourceLabel(text: sourceDisplayName)
            }

            HStack(alignment: .center, spacing: 12) {
                TranscriptionAudioPlayerView(audioURL: audioURL)

                Spacer(minLength: 12)

                if shouldShowTabPicker {
                    Picker("", selection: $selectedTab) {
                        ForEach(availableTabs, id: \.self) { tab in
                            Text(tab.localized).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: isSegmentedTabEnabled ? 300 : 220)
                }
            }

            contentView
                .font(.body)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let error = inlinePostProcessingErrorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(AppDesignSystem.Colors.error)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(AppDesignSystem.Colors.error)
                }
            }

            HStack {
                Spacer()

                HStack(spacing: 12) {
                    if transcription.supportsMeetingConversation {
                        Button {
                            onAction(.askAboutMeeting)
                        } label: {
                            Label("transcription.qa.title".localized, systemImage: "bubble.left.and.bubble.right")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                    }

                    Button {
                        onAction(.copy(text: currentText))
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("common.copy".localized)

                    Menu {
                        ForEach(filteredPrompts) { prompt in
                            Button(prompt.title) {
                                onAction(.reprocess(prompt: prompt))
                            }
                        }
                    } label: {
                        if isPostProcessing {
                            ProgressView()
                                .controlSize(.small)
                                .frame(width: 16, height: 16)
                        } else {
                            Image(systemName: "wand.and.sparkles")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .help("transcription.actions.redo_post_processing".localized)
                    .fixedSize()
                    .disabled(filteredPrompts.isEmpty || isPostProcessing)

                    Button {
                        onAction(.retryTranscription)
                    } label: {
                        Image(systemName: "arrow.clockwise.circle")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("transcription.actions.retry_transcription".localized)
                    .disabled(audioURL == nil)

                    Button {
                        showInfoPopover.toggle()
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showInfoPopover) {
                        if let details = transcriptionDetail {
                            TranscriptionInfoPopover(transcription: details)
                        } else {
                            Text("transcription.info.loading".localized)
                                .padding()
                        }
                    }

                    actionButton(icon: "trash", action: .delete, isDestructive: true)
                }
            }
        }
        .onAppear {
            ensureValidSelectedTab()
        }
        .onChange(of: isSegmentedTabEnabled) { _, _ in
            ensureValidSelectedTab()
        }
        .onChange(of: hasPostProcessingContent) { _, _ in
            ensureValidSelectedTab()
        }
    }

    private var availableTabs: [TranscriptionTab] {
        guard hasPostProcessingContent else {
            return [.original]
        }

        if isSegmentedTabEnabled {
            return TranscriptionTab.allCases
        }
        return [.aiProcessed, .original]
    }

    private var shouldShowTabPicker: Bool {
        availableTabs.count > 1
    }

    private var hasPostProcessingContent: Bool {
        if let processedContent = transcriptionDetail?.processedContent {
            return !processedContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return transcription.isPostProcessed
    }

    private var isSegmentedTabEnabled: Bool {
        hasPostProcessingContent
            && transcription.supportsMeetingConversation
            && AppSettingsStore.shared.isDiarizationEnabled
    }

    private var filteredPrompts: [PostProcessingPrompt] {
        let settings = AppSettingsStore.shared
        let typeSpecificPrompts = transcription.supportsMeetingConversation ? settings.meetingAvailablePrompts : settings.dictationAvailablePrompts
        let allowedIDs = Set(availablePrompts.map(\.id))

        guard !allowedIDs.isEmpty else {
            return typeSpecificPrompts
        }

        return typeSpecificPrompts.filter { allowedIDs.contains($0.id) }
    }

    private func ensureValidSelectedTab() {
        guard !availableTabs.contains(selectedTab) else { return }
        selectedTab = availableTabs.first ?? .original
    }

    private var currentText: String {
        switch selectedTab {
        case .aiProcessed:
            transcriptionDetail?.processedContent ?? transcriptionDetail?.text ?? transcription.previewText
        case .original:
            transcriptionDetail?.rawText ?? transcription.previewText
        case .segmented:
            sortedSegments(transcriptionDetail?.segments ?? [])
                .map { "\($0.speaker): \($0.text)" }
                .joined(separator: "\n\n")
        }
    }

    private var contentView: some View {
        let text = displayText(currentText)

        return VStack(alignment: .leading, spacing: AppDesignSystem.Layout.spacing8) {
            Text(text)
                .lineLimit(isTabExpanded(selectedTab) ? nil : Layout.contentLineLimit)
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(textOpacity)
                .animation(pulseAnimation, value: isPostProcessing)

            if shouldShowContentExpansionToggle(text: text) {
                Button(isTabExpanded(selectedTab) ? "transcription.content.show_less".localized : "transcription.content.show_all".localized) {
                    toggleTabExpansion(selectedTab)
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(AppDesignSystem.Colors.accent)
            }
        }
    }

    private func displayText(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "transcription.empty_fallback".localized
        }
        return text
    }

    private var textOpacity: Double {
        if isPostProcessing, !reduceMotion {
            return 0.45
        }
        return 1
    }

    private var pulseAnimation: Animation? {
        if isPostProcessing, !reduceMotion {
            return .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
        }
        return nil
    }

    private var inlinePostProcessingErrorMessage: String? {
        guard let postProcessingErrorMessage else { return nil }
        let trimmed = postProcessingErrorMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed
    }

    private func sortedSegments(_ segments: [Transcription.Segment]) -> [Transcription.Segment] {
        segments.sorted { lhs, rhs in
            if lhs.startTime != rhs.startTime {
                return lhs.startTime < rhs.startTime
            }
            if lhs.endTime != rhs.endTime {
                return lhs.endTime < rhs.endTime
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    private func isTabExpanded(_ tab: TranscriptionTab) -> Bool {
        expandedTabs.contains(tab)
    }

    private func toggleTabExpansion(_ tab: TranscriptionTab) {
        if expandedTabs.contains(tab) {
            expandedTabs.remove(tab)
        } else {
            expandedTabs.insert(tab)
        }
    }

    private func shouldShowContentExpansionToggle(text: String) -> Bool {
        let lineBreakCount = text.reduce(into: 0) { partialResult, character in
            if character == "\n" {
                partialResult += 1
            }
        }
        let estimatedLines = lineBreakCount + max(1, text.count / 110)
        return estimatedLines > Layout.contentLineLimit
    }

    private func actionButton(icon: String, action: TranscriptionAction, isDestructive: Bool = false) -> some View {
        Button {
            onAction(action)
        } label: {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(isDestructive ? .red : .secondary)
        }
        .buttonStyle(.plain)
    }

    private var appSource: MeetingApp {
        MeetingApp(rawValue: transcription.appRawValue) ?? .unknown
    }

    private var sourceDisplayName: String {
        let trimmed = transcription.appName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? appSource.displayName : trimmed
    }

    private var displayTitle: String {
        let trimmed = transcription.meetingTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? sourceDisplayName : trimmed
    }

    private func sourceLabel(text: String) -> some View {
        HStack(spacing: 6) {
            AppIconView(
                bundleIdentifier: transcription.appBundleIdentifier,
                fallbackSystemName: appSource.icon,
                size: 18,
                cornerRadius: 4
            )
            Text(text)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .foregroundStyle(.secondary)
    }
}

private struct TranscriptionCardPreviewContainer: View {
    @State private var isExpanded = true

    var body: some View {
        TranscriptionCardView(
            transcription: .previewMetadata,
            transcriptionDetail: .previewDetail,
            isExpanded: isExpanded,
            audioURL: nil,
            availablePrompts: PostProcessingPrompt.allPredefined,
            onToggleExpand: { isExpanded.toggle() },
            onAction: { _ in }
        )
        .padding()
        .frame(width: 760)
    }
}

private extension TranscriptionMetadata {
    static var previewMetadata: Self {
        .init(
            id: UUID(),
            meetingId: UUID(),
            meetingTitle: "Sprint Planning",
            appName: "Google Meet",
            appRawValue: "google-meet",
            appBundleIdentifier: "com.google.Chrome",
            startTime: Date().addingTimeInterval(-900),
            createdAt: Date(),
            previewText: "Resumo da sprint: concluímos os endpoints de transcrição, faltando validar tratamento de erros e UX da aba de settings.",
            wordCount: 24,
            language: "pt",
            isPostProcessed: true,
            duration: 540,
            audioFilePath: nil,
            inputSource: "microphone"
        )
    }
}

private extension Transcription {
    static var previewDetail: Self {
        .init(
            meeting: Meeting(
                app: .googleMeet,
                title: "Sprint Planning",
                state: .completed,
                startTime: Date().addingTimeInterval(-1_200),
                endTime: Date().addingTimeInterval(-600),
                audioFilePath: nil
            ),
            segments: [
                .init(speaker: "Speaker 1", text: "Finalizamos o fluxo principal do processamento.", startTime: 0, endTime: 12),
                .init(speaker: "Speaker 2", text: "Próximo passo é revisar os previews dos componentes.", startTime: 13, endTime: 24),
            ],
            text: "Finalizamos o fluxo principal do processamento. Próximo passo é revisar os previews dos componentes.",
            rawText: "finalizamos fluxo principal processamento proximo passo revisar previews componentes",
            processedContent: "Finalizamos o fluxo principal do processamento. O próximo passo é revisar os previews dos componentes.",
            postProcessingPromptTitle: "Clean transcription",
            language: "pt"
        )
    }
}

#Preview("Expanded") {
    TranscriptionCardPreviewContainer()
}

#Preview("Collapsed") {
    TranscriptionCardView(
        transcription: .previewMetadata,
        transcriptionDetail: .previewDetail,
        isExpanded: false,
        audioURL: nil,
        availablePrompts: PostProcessingPrompt.allPredefined,
        onToggleExpand: {},
        onAction: { _ in }
    )
    .padding()
    .frame(width: 760)
}
