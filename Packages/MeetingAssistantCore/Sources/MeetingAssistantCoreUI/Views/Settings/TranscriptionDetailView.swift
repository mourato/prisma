import SwiftUI
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

/// Detail view for a selected transcription.
public struct TranscriptionDetailView: View {
    let transcription: Transcription
    let isProcessing: Bool
    let onApplyPrompt: (PostProcessingPrompt) -> Void

    public init(
        transcription: Transcription,
        isProcessing: Bool = false,
        onApplyPrompt: @escaping (PostProcessingPrompt) -> Void = { _ in }
    ) {
        self.transcription = transcription
        self.isProcessing = isProcessing
        self.onApplyPrompt = onApplyPrompt
    }

    public var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    Divider()

                    if let processed = transcription.processedContent {
                        processedTranscriptSection(processed)
                        Divider()
                        originalTranscriptSection
                    } else {
                        transcriptSection
                    }
                }
                .padding()
            }
            .blur(radius: isProcessing ? 2 : 0)
            .disabled(isProcessing)

            if isProcessing {
                processingOverlay
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(transcription.formattedDate)
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                HStack(spacing: 12) {
                    aiActionsMenu

                    Menu {
                        Button("common.delete".localized, role: .destructive) {
                            // TODO: Implement delete
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                    }
                    .menuStyle(.borderlessButton)
                }
            }

            HStack(spacing: 8) {
                statusBadge(text: "transcription.completed".localized, color: .green, icon: "checkmark.circle.fill")
                statusBadge(text: transcription.meeting.appName, color: .blue, icon: "mic.fill")
                if transcription.isPostProcessed {
                    statusBadge(
                        text: transcription.postProcessingPromptTitle ?? "transcription.processed".localized,
                        color: .orange,
                        icon: "sparkles"
                    )
                }
            }

            Text("transcription.recorded_on".localized(with: transcription.formattedDate))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var aiActionsMenu: some View {
        Menu {
            Section("transcription.ai_post_processing".localized) {
                ForEach(PostProcessingPrompt.allPredefined) { prompt in
                    Button {
                        onApplyPrompt(prompt)
                    } label: {
                        Label(prompt.title, systemImage: prompt.icon)
                    }
                }
            }
        } label: {
            Label("transcription.ai_actions".localized, systemImage: "sparkles")
                .symbolEffect(.pulse, options: .repeating, value: isProcessing)
        }
        .buttonStyle(.bordered)
        .tint(.orange)
    }

    private var processingOverlay: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("transcription.processing_overlay_hint".localized)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .padding(30)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 10)
    }

    private func statusBadge(text: String, color: Color, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15), in: Capsule())
        .foregroundStyle(color)
    }

    // MARK: - Transcript Section

    private var transcriptSection: some View {
        contentBox(
            title: "transcription.title".localized,
            text: transcription.text,
            isOriginal: false
        )
    }

    private func processedTranscriptSection(_ text: String) -> some View {
        contentBox(
            title: transcription.postProcessingPromptTitle ?? "transcription.processed".localized,
            text: text,
            isOriginal: false,
            showSparkles: true
        )
    }

    private var originalTranscriptSection: some View {
        contentBox(
            title: "transcription.original_title".localized,
            text: transcription.rawText,
            isOriginal: true
        )
    }

    private func contentBox(title: String, text: String, isOriginal: Bool, showSparkles: Bool = false) -> some View {
        let displayText = transcriptionDisplayText(text)

        return VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing12) {
            HStack {
                HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing6) {
                    if showSparkles {
                        Image(systemName: "sparkles")
                            .foregroundStyle(MeetingAssistantDesignSystem.Colors.aiGradient)
                    }
                    Text(title)
                        .font(.headline)
                }

                Spacer()

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                } label: {
                    Label("common.copy".localized, systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
            }

            Text(displayText)
                .font(.body)
                .textSelection(.enabled)
                .padding(MeetingAssistantDesignSystem.Layout.spacing16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    isOriginal ? MeetingAssistantDesignSystem.Colors.subtleFill2 : MeetingAssistantDesignSystem.Colors.cardBackground,
                    in: RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.smallCornerRadius)
                )
        }
    }

    private func transcriptionDisplayText(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "transcription.empty_fallback".localized
        }
        return text
    }
}
