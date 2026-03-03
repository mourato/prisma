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
    let effectiveModelSelection: MeetingQAModelSelection
    let modelOptions: [EnhancementsProviderModelOption]
    let isLoadingModelOptions: Bool
    let onModelChange: (EnhancementsProviderModelOption) -> Void
    let onRefreshModelOptions: () -> Void
    let dictationState: MeetingQuestionDictationService.State
    let dictationErrorMessage: String?
    let onToggleDictation: () -> Void
    let onBack: () -> Void

    @State private var isShowingModelSelector = false

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
        effectiveModelSelection: MeetingQAModelSelection,
        modelOptions: [EnhancementsProviderModelOption],
        isLoadingModelOptions: Bool,
        onModelChange: @escaping (EnhancementsProviderModelOption) -> Void,
        onRefreshModelOptions: @escaping () -> Void,
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
        self.effectiveModelSelection = effectiveModelSelection
        self.modelOptions = modelOptions
        self.isLoadingModelOptions = isLoadingModelOptions
        self.onModelChange = onModelChange
        self.onRefreshModelOptions = onRefreshModelOptions
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
        .background(AppDesignSystem.Colors.windowBackground)
        .sheet(isPresented: $isShowingModelSelector) {
            EnhancementsModelSelectionSheet(
                options: modelOptions,
                isSelected: { option in
                    option.provider.rawValue == effectiveModelSelection.providerRawValue
                        && option.modelID == effectiveModelSelection.modelID
                },
                onSelect: { option in
                    onModelChange(option)
                    isShowingModelSelector = false
                },
                onCancel: {
                    isShowingModelSelector = false
                }
            )
            .onAppear {
                onRefreshModelOptions()
            }
        }
    }

    private var header: some View {
        HStack(spacing: AppDesignSystem.Layout.spacing8) {
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
        .padding(AppDesignSystem.Layout.spacing16)
    }

    @ViewBuilder
    private var content: some View {
        if isLoadingTranscription {
            VStack(spacing: AppDesignSystem.Layout.spacing8) {
                Spacer()
                ProgressView()
                Text("settings.transcriptions.loading".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        } else if transcription == nil {
            VStack(spacing: AppDesignSystem.Layout.spacing8) {
                Spacer()
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundStyle(.tertiary)
                Text("settings.transcriptions.no_selection".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppDesignSystem.Layout.spacing16)
                Spacer()
            }
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: AppDesignSystem.Layout.spacing16) {
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
                        HStack(spacing: AppDesignSystem.Layout.spacing8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("transcription.qa.loading".localized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(AppDesignSystem.Layout.spacing16)
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.Layout.spacing8) {
            Text("transcription.qa.summary_title".localized)
                .font(.subheadline)
                .fontWeight(.semibold)

            Text(summaryText)
                .font(.body)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding(AppDesignSystem.Layout.spacing12)
        .background(
            AppDesignSystem.Colors.cardBackground,
            in: RoundedRectangle(cornerRadius: AppDesignSystem.Layout.smallCornerRadius)
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
        VStack(alignment: .leading, spacing: AppDesignSystem.Layout.spacing8) {
            HStack(alignment: .top, spacing: AppDesignSystem.Layout.spacing8) {
                Image(systemName: "person.fill")
                    .foregroundStyle(AppDesignSystem.Colors.accent)
                Text(turn.question)
                    .font(.body)
            }

            if let response = turn.response {
                if response.status == .notFound {
                    Text("transcription.qa.not_found".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: AppDesignSystem.Layout.spacing8) {
                        HStack(alignment: .top, spacing: AppDesignSystem.Layout.spacing8) {
                            Image(systemName: "sparkles")
                                .foregroundStyle(AppDesignSystem.Colors.iconHighlight)
                            Text(response.answer)
                                .font(.body)
                                .textSelection(.enabled)
                        }

                        if !response.evidence.isEmpty {
                            VStack(alignment: .leading, spacing: AppDesignSystem.Layout.spacing6) {
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
                VStack(alignment: .leading, spacing: AppDesignSystem.Layout.spacing8) {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(AppDesignSystem.Colors.error)

                    Button("transcription.qa.retry".localized) {
                        onRetry(turn.question)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(isAnswering)
                }
            }
        }
        .padding(AppDesignSystem.Layout.spacing12)
        .background(
            AppDesignSystem.Colors.subtleFill,
            in: RoundedRectangle(cornerRadius: AppDesignSystem.Layout.smallCornerRadius)
        )
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.Layout.spacing8) {
            if let currentErrorMessage, !currentErrorMessage.isEmpty {
                Text(currentErrorMessage)
                    .font(.caption)
                    .foregroundStyle(AppDesignSystem.Colors.error)
            }

            if let dictationErrorMessage, !dictationErrorMessage.isEmpty {
                Text(dictationErrorMessage)
                    .font(.caption)
                    .foregroundStyle(AppDesignSystem.Colors.error)
            }

            MeetingQuestionComposerTextView(
                text: Binding(
                    get: { questionText },
                    set: { onQuestionChange($0) }
                ),
                placeholder: "transcription.qa.placeholder".localized,
                onCommandReturn: onAsk
            )

            HStack(spacing: AppDesignSystem.Layout.spacing8) {
                modelSelectorButton

                dictationButton

                Spacer(minLength: 0)

                Button("transcription.qa.ask".localized) {
                    onAsk()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isAskDisabled)
            }
        }
        .padding(AppDesignSystem.Layout.spacing16)
    }

    private var modelSelectorButton: some View {
        Button {
            isShowingModelSelector = true
        } label: {
            if isLoadingModelOptions {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 18, height: 18)
            } else {
                Image(systemName: "brain.head.profile")
                    .font(.body)
            }
        }
        .buttonStyle(.bordered)
        .disabled(isLoadingTranscription)
        .help(modelSelectorHelpText)
        .accessibilityLabel(modelSelectorHelpText)
    }

    private var modelSelectorHelpText: String {
        let providerName = AIProvider(rawValue: effectiveModelSelection.providerRawValue)?.displayName
            ?? effectiveModelSelection.providerRawValue
        let modelName = effectiveModelSelection.modelID.trimmingCharacters(in: .whitespacesAndNewlines)
        if modelName.isEmpty {
            return "settings.enhancements.provider_models.summary.no_model".localized(with: providerName)
        }
        return "settings.enhancements.provider_models.summary".localized(with: providerName, modelName)
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
        .tint(dictationState == .recording ? AppDesignSystem.Colors.error : nil)
        .disabled(isLoadingTranscription || dictationState == .processing)
        .help(dictationHelpText)
        .accessibilityLabel(dictationHelpText)
    }

    private var dictationButtonIcon: String {
        switch dictationState {
        case .idle:
            "mic.fill"
        case .recording:
            "stop.fill"
        case .processing:
            "hourglass"
        }
    }

    private var dictationHelpText: String {
        switch dictationState {
        case .idle:
            "transcription.qa.dictation.start".localized
        case .recording:
            "transcription.qa.dictation.stop".localized
        case .processing:
            "transcription.qa.dictation.processing".localized
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
