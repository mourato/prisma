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
        case info
        case delete
    }

    public enum TranscriptionTab: String, CaseIterable {
        case aiProcessed = "AI Processed"
        case original = "Original"
        case segmented = "Segmented"

        var localized: String {
            // TODO: Localize
            rawValue
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
            Text(transcription.previewText)
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
                    .help("Redo Post-processing")
                    .fixedSize() // Prevent menu chevron if possible or accept it

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
                            Text("Loading details...")
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
            Text(transcriptionDetail?.processedContent ?? transcriptionDetail?.text ?? transcription.previewText)
        case .original:
            Text(transcriptionDetail?.rawText ?? transcription.previewText)
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
                Text(NSLocalizedString("transcription.no_segments", bundle: .safeModule, comment: ""))
                    .foregroundStyle(.secondary)
            }
        }
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
