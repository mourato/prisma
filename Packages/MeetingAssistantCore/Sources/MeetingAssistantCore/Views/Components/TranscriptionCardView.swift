import SwiftUI

/// An expandable card for a transcription item.
public struct TranscriptionCardView: View {
    let transcription: TranscriptionMetadata
    let transcriptionDetail: Transcription?
    let isExpanded: Bool
    let audioURL: URL?
    let onToggleExpand: () -> Void
    let onAction: (TranscriptionAction) -> Void

    public init(
        transcription: TranscriptionMetadata,
        transcriptionDetail: Transcription? = nil,
        isExpanded: Bool,
        audioURL: URL?,
        onToggleExpand: @escaping () -> Void,
        onAction: @escaping (TranscriptionAction) -> Void
    ) {
        self.transcription = transcription
        self.transcriptionDetail = transcriptionDetail
        self.isExpanded = isExpanded
        self.audioURL = audioURL
        self.onToggleExpand = onToggleExpand
        self.onAction = onAction
    }

    @State private var selectedTab: TranscriptionTab = .aiProcessed

    public enum TranscriptionAction {
        case copy
        case download
        case reprocess
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

            // Audio Player
            TranscriptionAudioPlayerView(audioURL: audioURL)

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
                    actionButton(icon: "doc.on.doc", action: .copy)
                    actionButton(icon: "arrow.down.circle", action: .download)
                    actionButton(icon: "arrow.clockwise", action: .reprocess)
                    actionButton(icon: "info.circle", action: .info)
                    actionButton(icon: "trash", action: .delete, isDestructive: true)
                }
            }
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
