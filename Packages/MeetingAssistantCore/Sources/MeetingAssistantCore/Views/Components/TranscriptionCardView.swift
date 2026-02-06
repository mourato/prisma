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
        VStack(alignment: .leading, spacing: 12) {
            // Content
            if isExpanded {
                expandedContent
            } else {
                collapsedContent
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
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
        VStack(alignment: .leading, spacing: 4) {
            Text(displayText(transcription.previewText))
                .font(.body)
                .lineLimit(2)
                .foregroundStyle(.primary)
        }
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Full Text
            contentView
                .font(.body)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Audio Player (resized to ~1/3 width)
            TranscriptionAudioPlayerView(audioURL: audioURL)
                .frame(maxWidth: 250) // Approx 1/3 of a typical card width, or usage of GeometryReader up hierarchy

            // Tabs and Actions
            HStack {
                // Tab Selector
                Picker("", selection: $selectedTab) {
                    ForEach(TranscriptionTab.allCases, id: \.self) { tab in
                        Text(tab.localized).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 250)

                Spacer()

                // Actions
                HStack(spacing: 12) {
                    // Copy (Context Aware)
                    Button {
                        onAction(.copy(text: currentText))
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("common.copy".localized)

                    // Redo Post-Processing
                    Menu {
                        ForEach(availablePrompts) { prompt in
                            Button(prompt.title) {
                                onAction(.reprocess(prompt: prompt))
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise") // User asked for rotating right arrow
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .menuStyle(.borderlessButton)
                    .help("transcription.actions.redo_post_processing".localized)
                    .fixedSize() // Prevent menu chevron if possible or accept it

                    // Retry Transcription
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

                    // Info
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

                    // Delete
                    actionButton(icon: "trash", action: .delete, isDestructive: true)
                }
            }
        }
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
}
