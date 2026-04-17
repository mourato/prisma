import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

public struct EnhancementsProviderModelsPage: View {
    enum ModelSelectionTarget: String, Identifiable {
        case meeting
        case dictation

        var id: String {
            rawValue
        }

        var mode: IntelligenceKernelMode {
            switch self {
            case .meeting: .meeting
            case .dictation: .dictation
            }
        }
    }

    struct RegistrationEditorContext: Identifiable {
        let id = UUID()
        let mode: EnhancementsProviderEditorMode
        let provider: AIProvider
        let registrationID: UUID?
    }

    @ObservedObject var viewModel: AISettingsViewModel
    @ObservedObject var postProcessingViewModel: PostProcessingSettingsViewModel

    @State var modelSelectionTarget: ModelSelectionTarget?
    @State var isShowingProviderPicker = false
    @State var registrationEditorContext: RegistrationEditorContext?

    @State var draftDisplayName = ""
    @State var draftBaseURL = ""
    @State var draftAPIKey = ""
    @State var draftHasSavedAPIKey = false
    @State var draftConnectionStatus: ConnectionStatus = .unknown
    @State var draftErrorMessage: String?

    public init(
        viewModel: AISettingsViewModel,
        postProcessingViewModel: PostProcessingSettingsViewModel,
        initialExpandedProvider: AIProvider? = nil
    ) {
        self.viewModel = viewModel
        self.postProcessingViewModel = postProcessingViewModel
        _ = initialExpandedProvider
    }

    public var body: some View {
        SettingsScrollableContent {
            DSCallout(
                kind: .info,
                title: "settings.enhancements.provider_models.context_title".localized,
                message: "settings.enhancements.provider_models.context_desc".localized
            )

            executionModelSelectorsSection
            providerRegistrationsSection
        }
        .onAppear {
            viewModel.refreshEnhancementsProviderModelsManually()
        }
        .sheet(item: $modelSelectionTarget) { target in
            EnhancementsModelSelectionSheet(
                options: viewModel.enhancementsProviderModels,
                isSelected: { option in
                    isSelectedOption(option, for: target)
                },
                onSelect: { option in
                    if let registrationID = option.registrationID {
                        postProcessingViewModel.settings.updateEnhancementsSelection(
                            registrationID: registrationID,
                            model: option.modelID,
                            for: target.mode
                        )
                    } else {
                        postProcessingViewModel.settings.updateEnhancementsSelection(
                            provider: option.provider,
                            model: option.modelID,
                            for: target.mode
                        )
                    }
                    modelSelectionTarget = nil
                },
                onCancel: {
                    modelSelectionTarget = nil
                }
            )
        }
        .sheet(isPresented: $isShowingProviderPicker) {
            EnhancementsProviderPickerSheet(
                registeredBuiltInProviders: registeredBuiltInProviders,
                onSelect: { provider in
                    isShowingProviderPicker = false
                    DispatchQueue.main.async {
                        beginCreateRegistration(provider)
                    }
                },
                onCancel: {
                    isShowingProviderPicker = false
                }
            )
        }
        .sheet(item: $registrationEditorContext) { context in
            EnhancementsProviderEditorSheet(
                mode: context.mode,
                provider: context.provider,
                displayName: $draftDisplayName,
                baseURL: $draftBaseURL,
                apiKey: $draftAPIKey,
                hasSavedAPIKey: draftHasSavedAPIKey,
                connectionStatus: draftConnectionStatus,
                errorMessage: draftErrorMessage,
                onSave: {
                    saveRegistration(from: context, shouldTestConnection: false)
                },
                onTestAndSave: {
                    saveRegistration(from: context, shouldTestConnection: true)
                },
                onDelete: context.mode == .edit ? {
                    deleteRegistration(from: context)
                } : nil,
                onRemoveKey: {
                    removeRegistrationKey(from: context)
                },
                onCancel: {
                    registrationEditorContext = nil
                }
            )
        }
    }
}

extension EnhancementsProviderModelsPage {
    var providerRegistrationsSection: some View {
        DSCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("settings.enhancements.providers.active_title".localized)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("settings.enhancements.providers.active_desc".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        isShowingProviderPicker = true
                    } label: {
                        Label("settings.enhancements.providers.add".localized, systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }

                if activeRegistrations.isEmpty {
                    Text("settings.enhancements.providers.empty".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 6)
                } else {
                    ForEach(Array(activeRegistrations.enumerated()), id: \.element.id) { index, registration in
                        registrationRow(registration)
                        if index < activeRegistrations.count - 1 {
                            Divider()
                        }
                    }
                }

                if let fetchError = viewModel.enhancementsProviderModelsFetchError,
                   !fetchError.isEmpty
                {
                    DSCallout(
                        kind: .warning,
                        title: "settings.enhancements.provider_models.error.title".localized,
                        message: fetchError
                    )
                }
            }
        }
    }

    func registrationRow(_ registration: EnhancementsProviderRegistration) -> some View {
        let readinessIssue = registrationReadinessIssue(for: registration)
        let isReady = readinessIssue == nil

        return Button {
            beginEditRegistration(registration)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                EnhancementsProviderAvatar(provider: registration.provider)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(registration.displayName)
                            .font(.headline)

                        if isRegistrationSelected(registration.id, in: .meeting) {
                            DSBadge("settings.enhancements.selector.meeting.title".localized, kind: .success)
                        }

                        if isRegistrationSelected(registration.id, in: .dictation) {
                            DSBadge("settings.enhancements.selector.dictation.title".localized, kind: .neutral)
                        }
                    }

                    Text(providerDescription(for: registration.provider))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
                        Circle()
                            .fill(isReady ? AppDesignSystem.Colors.success : AppDesignSystem.Colors.warning)
                            .frame(width: 7, height: 7)
                        Text(providerStatusText(isReady: isReady, issue: readinessIssue))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    var executionModelSelectorsSection: some View {
        DSCard {
            VStack(alignment: .leading, spacing: 10) {
                selectorRow(
                    title: "settings.enhancements.selector.meeting.title".localized,
                    subtitle: "settings.enhancements.selector.meeting.subtitle".localized,
                    summary: selectionSummary(for: postProcessingViewModel.settings.enhancementsAISelection),
                    target: .meeting
                )

                Divider()

                selectorRow(
                    title: "settings.enhancements.selector.dictation.title".localized,
                    subtitle: "settings.enhancements.selector.dictation.subtitle".localized,
                    summary: selectionSummary(for: postProcessingViewModel.settings.enhancementsDictationAISelection),
                    target: .dictation
                )
            }
        }
    }

    func selectorRow(
        title: String,
        subtitle: String,
        summary: String,
        target: ModelSelectionTarget
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button(summary) {
                    modelSelectionTarget = target
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isLoadingEnhancementsProviderModels || viewModel.enhancementsProviderModels.isEmpty)

                Button {
                    viewModel.refreshEnhancementsProviderModelsManually()
                } label: {
                    if viewModel.isLoadingEnhancementsProviderModels {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .fontWeight(.medium)
                    }
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("settings.ai.model_refresh".localized)
                .disabled(viewModel.isLoadingEnhancementsProviderModels)
            }

            if viewModel.enhancementsProviderModels.isEmpty, !viewModel.isLoadingEnhancementsProviderModels {
                Text("settings.enhancements.model_selector.empty".localized)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    func selectionSummary(for selection: EnhancementsAISelection) -> String {
        let providerName = postProcessingViewModel.settings.enhancementsProviderDisplayName(for: selection)
        let model = selection.selectedModel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !model.isEmpty else {
            return "settings.enhancements.provider_models.summary.no_model".localized(with: providerName)
        }
        return "settings.enhancements.provider_models.summary".localized(with: providerName, model)
    }

    func isSelectedOption(_ option: EnhancementsProviderModelOption, for target: ModelSelectionTarget) -> Bool {
        let selection: EnhancementsAISelection = switch target {
        case .meeting:
            postProcessingViewModel.settings.enhancementsAISelection
        case .dictation:
            postProcessingViewModel.settings.enhancementsDictationAISelection
        }

        if let selectedRegistrationID = selection.registrationID,
           let optionRegistrationID = option.registrationID
        {
            return selectedRegistrationID == optionRegistrationID
                && selection.selectedModel == option.modelID
        }

        return selection.provider == option.provider && selection.selectedModel == option.modelID
    }

    func providerStatusText(isReady: Bool, issue: EnhancementsInferenceReadinessIssue?) -> String {
        guard !isReady else {
            return "settings.enhancements.provider_models.status.ready".localized
        }

        guard let issue else {
            return "settings.enhancements.provider_models.status.not_ready".localized
        }

        switch issue {
        case .missingModel:
            return "settings.enhancements.provider_models.status.not_ready_missing_model".localized
        case .missingAPIKey:
            return "settings.enhancements.provider_models.status.not_ready_missing_key".localized
        case .invalidBaseURL:
            return "settings.enhancements.provider_models.status.not_ready_invalid_url".localized
        }
    }

    func providerDescription(for provider: AIProvider) -> String {
        switch provider {
        case .openai:
            "settings.enhancements.provider.openai.desc".localized
        case .anthropic:
            "settings.enhancements.provider.anthropic.desc".localized
        case .groq:
            "settings.enhancements.provider.groq.desc".localized
        case .google:
            "settings.enhancements.provider.google.desc".localized
        case .custom:
            "settings.enhancements.provider.custom.desc".localized
        }
    }

}

extension EnhancementsProviderModelsPage {
    var activeRegistrations: [EnhancementsProviderRegistration] {
        postProcessingViewModel.settings.enhancementsProviderRegistrations
    }

    var registeredBuiltInProviders: Set<AIProvider> {
        Set(activeRegistrations.filter { $0.provider != .custom }.map(\.provider))
    }

    func isRegistrationSelected(_ registrationID: UUID, in mode: IntelligenceKernelMode) -> Bool {
        postProcessingViewModel.settings.enhancementsSelection(for: mode).registrationID == registrationID
    }

}
