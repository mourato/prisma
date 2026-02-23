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
    let selectedProvider: AIProvider
    let selectedModel: String
    let availableModels: [LLMModel]
    let isLoadingModels: Bool
    let onModelChange: (String) -> Void
    let onRefreshModels: () -> Void
    let dictationState: MeetingQuestionDictationService.State
    let dictationErrorMessage: String?
    let onToggleDictation: () -> Void
    let onBack: () -> Void

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
        selectedProvider: AIProvider,
        selectedModel: String,
        availableModels: [LLMModel],
        isLoadingModels: Bool,
        onModelChange: @escaping (String) -> Void,
        onRefreshModels: @escaping () -> Void,
        dictationState: MeetingQuestionDictationService.State,
        dictationErrorMessage: String?,
        onToggleDictation: @escaping () -> Void,
        onBack: @escaping () -> Void
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
        self.selectedProvider = selectedProvider
        self.selectedModel = selectedModel
        self.availableModels = availableModels
        self.isLoadingModels = isLoadingModels
        self.onModelChange = onModelChange
        self.onRefreshModels = onRefreshModels
        self.dictationState = dictationState
        self.dictationErrorMessage = dictationErrorMessage
        self.onToggleDictation = onToggleDictation
        self.onBack = onBack
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
            Button {
                onBack()
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.borderless)
            .help("transcription.qa.navigation.back".localized)
            .accessibilityLabel("transcription.qa.navigation.back".localized)

            Label("transcription.qa.title".localized, systemImage: "bubble.left.and.bubble.right.fill")
                .font(.headline)

            Spacer()
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

            if let dictationErrorMessage, !dictationErrorMessage.isEmpty {
                Text(dictationErrorMessage)
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

                inlineModelControl

                dictationButton

                Button("transcription.qa.ask".localized) {
                    onAsk()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isAskDisabled)
            }
        }
        .padding(MeetingAssistantDesignSystem.Layout.spacing16)
    }

    @ViewBuilder
    private var inlineModelControl: some View {
        if selectedProvider == .custom {
            TextField(
                "settings.ai.model_placeholder".localized,
                text: Binding(
                    get: { selectedModel },
                    set: { onModelChange($0) }
                )
            )
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: MeetingAssistantDesignSystem.Layout.maxCompactTextFieldWidth)
            .accessibilityLabel("settings.ai.model".localized)
        } else {
            Picker(
                "",
                selection: Binding(
                    get: { selectedModel },
                    set: { onModelChange($0) }
                )
            ) {
                if isLoadingModels {
                    Text("settings.ai.loading".localized).tag("")
                } else if availableModels.isEmpty {
                    Text("settings.ai.no_models".localized).tag("")
                } else {
                    Text("settings.ai.model_select".localized).tag("")
                    ForEach(availableModels) { model in
                        Text(model.id).tag(model.id)
                    }
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .disabled(isLoadingModels || availableModels.isEmpty)
            .accessibilityLabel("settings.ai.model".localized)
        }
    }

    private var dictationButton: some View {
        Button {
            onToggleDictation()
        } label: {
            if dictationState == .processing {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 18, height: 18)
            } else {
                Image(systemName: dictationButtonIcon)
                    .font(.body)
            }
        }
        .buttonStyle(.bordered)
        .tint(dictationState == .recording ? MeetingAssistantDesignSystem.Colors.error : nil)
        .disabled(isLoadingTranscription || dictationState == .processing)
        .help(dictationHelpText)
        .accessibilityLabel(dictationHelpText)
    }

    private var dictationButtonIcon: String {
        switch dictationState {
        case .idle:
            return "mic.fill"
        case .recording:
            return "stop.fill"
        case .processing:
            return "hourglass"
        }
    }

    private var dictationHelpText: String {
        switch dictationState {
        case .idle:
            return "transcription.qa.dictation.start".localized
        case .recording:
            return "transcription.qa.dictation.stop".localized
        case .processing:
            return "transcription.qa.dictation.processing".localized
        }
    }

    private var isAskDisabled: Bool {
        questionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || isAnswering
            || isLoadingTranscription
            || dictationState == .processing
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
        selectedProvider: .openai,
        selectedModel: "gpt-4o",
        availableModels: [.init(id: "gpt-4o"), .init(id: "gpt-4.1-mini")],
        isLoadingModels: false,
        onModelChange: { _ in },
        onRefreshModels: {},
        dictationState: .idle,
        dictationErrorMessage: nil,
        onToggleDictation: {},
        onBack: {}
    )
    .frame(width: 700, height: 700)
}

#Preview("Dictation Recording") {
    MeetingConversationView(
        transcription: .previewConversation,
        isLoadingTranscription: false,
        turns: [],
        questionText: "",
        onQuestionChange: { _ in },
        onAsk: {},
        onRetry: { _ in },
        isAnswering: false,
        currentErrorMessage: nil,
        selectedProvider: .openai,
        selectedModel: "gpt-4o",
        availableModels: [.init(id: "gpt-4o")],
        isLoadingModels: false,
        onModelChange: { _ in },
        onRefreshModels: {},
        dictationState: .recording,
        dictationErrorMessage: nil,
        onToggleDictation: {},
        onBack: {}
    )
    .frame(width: 700, height: 700)
}

#Preview("Dictation Error") {
    MeetingConversationView(
        transcription: .previewConversation,
        isLoadingTranscription: false,
        turns: [],
        questionText: "",
        onQuestionChange: { _ in },
        onAsk: {},
        onRetry: { _ in },
        isAnswering: false,
        currentErrorMessage: nil,
        selectedProvider: .openai,
        selectedModel: "gpt-4o",
        availableModels: [.init(id: "gpt-4o")],
        isLoadingModels: false,
        onModelChange: { _ in },
        onRefreshModels: {},
        dictationState: .idle,
        dictationErrorMessage: "transcription.qa.dictation.error.transcription".localized,
        onToggleDictation: {},
        onBack: {}
    )
    .frame(width: 700, height: 700)
}

#Preview("Custom Provider Inline Model") {
    MeetingConversationView(
        transcription: .previewConversation,
        isLoadingTranscription: false,
        turns: [],
        questionText: "Summarize action items",
        onQuestionChange: { _ in },
        onAsk: {},
        onRetry: { _ in },
        isAnswering: false,
        currentErrorMessage: nil,
        selectedProvider: .custom,
        selectedModel: "my-local-model",
        availableModels: [],
        isLoadingModels: false,
        onModelChange: { _ in },
        onRefreshModels: {},
        dictationState: .idle,
        dictationErrorMessage: nil,
        onToggleDictation: {},
        onBack: {}
    )
    .frame(width: 700, height: 700)
}

#Preview("No Models Inline Picker") {
    MeetingConversationView(
        transcription: .previewConversation,
        isLoadingTranscription: false,
        turns: [],
        questionText: "What decisions were made?",
        onQuestionChange: { _ in },
        onAsk: {},
        onRetry: { _ in },
        isAnswering: false,
        currentErrorMessage: nil,
        selectedProvider: .openai,
        selectedModel: "",
        availableModels: [],
        isLoadingModels: false,
        onModelChange: { _ in },
        onRefreshModels: {},
        dictationState: .idle,
        dictationErrorMessage: nil,
        onToggleDictation: {},
        onBack: {}
    )
    .frame(width: 700, height: 700)
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
            processedContent: "Precisamos consolidar os previews da interface e priorizar, na sequencia, as telas com side effects.",
            postProcessingPromptTitle: "Planning summary",
            language: "pt"
        )
    }
}
