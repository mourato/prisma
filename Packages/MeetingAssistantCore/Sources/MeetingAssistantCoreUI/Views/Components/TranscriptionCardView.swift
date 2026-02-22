import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

/// An expandable card for a transcription item.
public struct TranscriptionCardView: View {
    let transcription: TranscriptionMetadata
    let transcriptionDetail: Transcription?
    let isExpanded: Bool
    let audioURL: URL?
    let availablePrompts: [PostProcessingPrompt]
    let onToggleExpand: () -> Void
    let onAction: (TranscriptionAction) -> Void

    public init(
        transcription: TranscriptionMetadata,
        transcriptionDetail: Transcription? = nil,
        isExpanded: Bool,
        audioURL: URL?,
        availablePrompts: [PostProcessingPrompt] = [],
        onToggleExpand: @escaping () -> Void,
        onAction: @escaping (TranscriptionAction) -> Void
    ) {
        self.transcription = transcription
        self.transcriptionDetail = transcriptionDetail
        self.isExpanded = isExpanded
        self.audioURL = audioURL
        self.availablePrompts = availablePrompts
        self.onToggleExpand = onToggleExpand
        self.onAction = onAction
    }

    @State private var selectedTab: TranscriptionTab = .aiProcessed
    @State private var showInfoPopover = false

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
        MACard(
            cornerRadius: MeetingAssistantDesignSystem.Layout.largeCornerRadius,
            padding: isExpanded ? MeetingAssistantDesignSystem.Layout.spacing16 : MeetingAssistantDesignSystem.Layout.spacing12
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
            HStack(alignment: .center, spacing: 12) {
                TranscriptionAudioPlayerView(audioURL: audioURL)
                    .frame(maxWidth: 250)

                Spacer(minLength: 12)

                Picker("", selection: $selectedTab) {
                    ForEach(availableTabs, id: \.self) { tab in
                        Text(tab.localized).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: isSegmentedTabEnabled ? 300 : 220)
            }

            contentView
                .font(.body)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Spacer()

                HStack(spacing: 12) {
                    Button {
                        onAction(.askAboutMeeting)
                    } label: {
                        Label("transcription.qa.title".localized, systemImage: "bubble.left.and.bubble.right")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)

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
                        Image(systemName: "arrow.clockwise")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .menuStyle(.borderlessButton)
                    .help("transcription.actions.redo_post_processing".localized)
                    .fixedSize()
                    .disabled(filteredPrompts.isEmpty)

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
    }

    private var availableTabs: [TranscriptionTab] {
        if isSegmentedTabEnabled {
            return TranscriptionTab.allCases
        }
        return [.aiProcessed, .original]
    }

    private var isSegmentedTabEnabled: Bool {
        isMeetingSource && AppSettingsStore.shared.isDiarizationEnabled
    }

    private var isMeetingSource: Bool {
        appSource != .unknown && appSource != .importedFile
    }

    private var filteredPrompts: [PostProcessingPrompt] {
        let settings = AppSettingsStore.shared
        let typeSpecificPrompts = isMeetingSource ? settings.meetingAvailablePrompts : settings.dictationAvailablePrompts
        let allowedIDs = Set(availablePrompts.map { $0.id })

        guard !allowedIDs.isEmpty else {
            return typeSpecificPrompts
        }

        return typeSpecificPrompts.filter { allowedIDs.contains($0.id) }
    }

    private func ensureValidSelectedTab() {
        guard !availableTabs.contains(selectedTab) else { return }
        selectedTab = .aiProcessed
    }

    private var currentText: String {
        switch selectedTab {
        case .aiProcessed:
            transcriptionDetail?.processedContent ?? transcriptionDetail?.text ?? transcription.previewText
        case .original:
            transcriptionDetail?.rawText ?? transcription.previewText
        case .segmented:
            transcriptionDetail?.segments.map { "\($0.speaker): \($0.text)" }.joined(separator: "\n\n") ?? ""
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case .aiProcessed:
            Text(displayText(transcriptionDetail?.processedContent ?? transcriptionDetail?.text ?? transcription.previewText))
        case .original:
            Text(displayText(transcriptionDetail?.rawText ?? transcription.previewText))
        case .segmented:
            if let segments = transcriptionDetail?.segments, !segments.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(segments) { segment in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(segment.speaker)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.secondary)
                            Text(segment.text)
                        }
                    }
                }
            } else {
                Text("transcription.no_segments".localized)
                    .foregroundStyle(.secondary)
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
