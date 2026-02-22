import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

public struct MeetingConversationView: View {
    let transcription: Transcription?
    let isLoadingTranscription: Bool
    let turns: [TranscriptionSettingsViewModel.QATurn]
    let questionText: String
    let onQuestionChange: (String) -> Void
    let onAsk: () -> Void
    let onRetry: (String) -> Void
    let isAnswering: Bool
    let currentErrorMessage: String?
    let onClose: () -> Void

    public init(
        transcription: Transcription?,
        isLoadingTranscription: Bool,
        turns: [TranscriptionSettingsViewModel.QATurn],
        questionText: String,
        onQuestionChange: @escaping (String) -> Void,
        onAsk: @escaping () -> Void,
        onRetry: @escaping (String) -> Void,
        isAnswering: Bool,
        currentErrorMessage: String?,
        onClose: @escaping () -> Void
    ) {
        self.transcription = transcription
        self.isLoadingTranscription = isLoadingTranscription
        self.turns = turns
        self.questionText = questionText
        self.onQuestionChange = onQuestionChange
        self.onAsk = onAsk
        self.onRetry = onRetry
        self.isAnswering = isAnswering
        self.currentErrorMessage = currentErrorMessage
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            composer
        }
        .background(MeetingAssistantDesignSystem.Colors.windowBackground)
    }

    private var header: some View {
        HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
            Label("transcription.qa.title".localized, systemImage: "bubble.left.and.bubble.right.fill")
                .font(.headline)

            Spacer()

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .help("common.cancel".localized)
        }
        .padding(MeetingAssistantDesignSystem.Layout.spacing16)
    }

    @ViewBuilder
    private var content: some View {
        if isLoadingTranscription {
            VStack(spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
                Spacer()
                ProgressView()
                Text("settings.transcriptions.loading".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        } else if transcription == nil {
            VStack(spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
                Spacer()
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundStyle(.tertiary)
                Text("settings.transcriptions.no_selection".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, MeetingAssistantDesignSystem.Layout.spacing16)
                Spacer()
            }
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing16) {
                    summaryCard

                    if turns.isEmpty {
                        Text("transcription.qa.placeholder".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(turns) { turn in
                            turnView(turn)
                        }
                    }

                    if isAnswering {
                        HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("transcription.qa.loading".localized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(MeetingAssistantDesignSystem.Layout.spacing16)
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
            Text("transcription.qa.summary_title".localized)
                .font(.subheadline)
                .fontWeight(.semibold)

            Text(summaryText)
                .font(.body)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding(MeetingAssistantDesignSystem.Layout.spacing12)
        .background(
            MeetingAssistantDesignSystem.Colors.cardBackground,
            in: RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.smallCornerRadius)
        )
    }

    private var summaryText: String {
        guard let transcription else {
            return "transcription.empty_fallback".localized
        }

        if let summary = transcription.canonicalSummary?.summary.trimmingCharacters(in: .whitespacesAndNewlines),
           !summary.isEmpty
        {
            return summary
        }

        if let processed = transcription.processedContent?.trimmingCharacters(in: .whitespacesAndNewlines),
           !processed.isEmpty
        {
            return processed
        }

        let text = transcription.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "transcription.empty_fallback".localized : text
    }

    private func turnView(_ turn: TranscriptionSettingsViewModel.QATurn) -> some View {
        VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
            HStack(alignment: .top, spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
                Image(systemName: "person.fill")
                    .foregroundStyle(MeetingAssistantDesignSystem.Colors.accent)
                Text(turn.question)
                    .font(.body)
            }

            if let response = turn.response {
                if response.status == .notFound {
                    Text("transcription.qa.not_found".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
                        HStack(alignment: .top, spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
                            Image(systemName: "sparkles")
                                .foregroundStyle(MeetingAssistantDesignSystem.Colors.iconHighlight)
                            Text(response.answer)
                                .font(.body)
                                .textSelection(.enabled)
                        }

                        if !response.evidence.isEmpty {
                            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing6) {
                                Text("transcription.qa.evidence_title".localized)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                ForEach(Array(response.evidence.enumerated()), id: \.offset) { _, item in
                                    Text("[\(formatTimestamp(item.startTime))–\(formatTimestamp(item.endTime))] \(item.speaker): \(item.excerpt)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            } else if let errorMessage = turn.errorMessage {
                VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(MeetingAssistantDesignSystem.Colors.error)

                    Button("transcription.qa.retry".localized) {
                        onRetry(turn.question)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(isAnswering)
                }
            }
        }
        .padding(MeetingAssistantDesignSystem.Layout.spacing12)
        .background(
            MeetingAssistantDesignSystem.Colors.subtleFill,
            in: RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.smallCornerRadius)
        )
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
            if let currentErrorMessage, !currentErrorMessage.isEmpty {
                Text(currentErrorMessage)
                    .font(.caption)
                    .foregroundStyle(MeetingAssistantDesignSystem.Colors.error)
            }

            HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
                TextField(
                    "transcription.qa.placeholder".localized,
                    text: Binding(
                        get: { questionText },
                        set: { onQuestionChange($0) }
                    )
                )
                .textFieldStyle(.roundedBorder)

                Button("transcription.qa.ask".localized) {
                    onAsk()
                }
                .buttonStyle(.borderedProminent)
                .disabled(questionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAnswering || isLoadingTranscription)
            }
        }
        .padding(MeetingAssistantDesignSystem.Layout.spacing16)
    }

    private func formatTimestamp(_ value: Double) -> String {
        let totalSeconds = max(0, Int(value.rounded()))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview("Conversation") {
    MeetingConversationView(
        transcription: .previewConversation,
        isLoadingTranscription: false,
        turns: [
            .init(
                question: "What did we decide about previews?",
                response: MeetingQAResponse(
                    status: .answered,
                    answer: "The team decided to prioritize screens with startup side effects.",
                    evidence: [
                        .init(
                            speaker: "Speaker 2",
                            startTime: 10,
                            endTime: 21,
                            excerpt: "Vou priorizar as telas com side effects na fase seguinte."
                        ),
                    ]
                ),
                errorMessage: nil
            ),
        ],
        questionText: "",
        onQuestionChange: { _ in },
        onAsk: {},
        onRetry: { _ in },
        isAnswering: false,
        currentErrorMessage: nil,
        onClose: {}
    )
    .frame(width: 520, height: 700)
}

private extension Transcription {
    static var previewConversation: Transcription {
        Transcription(
            meeting: Meeting(
                app: .slack,
                state: .completed,
                startTime: Date().addingTimeInterval(-1_800),
                endTime: Date().addingTimeInterval(-600),
                audioFilePath: nil
            ),
            segments: [
                .init(speaker: "Speaker 1", text: "Precisamos consolidar os previews da interface.", startTime: 0, endTime: 9),
                .init(speaker: "Speaker 2", text: "Vou priorizar as telas com side effects na fase seguinte.", startTime: 10, endTime: 21),
            ],
            text: "Precisamos consolidar os previews da interface. Vou priorizar as telas com side effects na fase seguinte.",
            rawText: "precisamos consolidar previews interface vou priorizar telas com side effects na fase seguinte",
            processedContent: "Precisamos consolidar os previews da interface e priorizar, na sequência, as telas com side effects.",
            postProcessingPromptTitle: "Planning summary",
            language: "pt"
        )
    }
}
