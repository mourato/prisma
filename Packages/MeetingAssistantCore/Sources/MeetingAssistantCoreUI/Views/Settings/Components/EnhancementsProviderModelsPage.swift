import AppKit
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

public struct EnhancementsProviderModelsPage: View {
    private enum ModelSelectionTarget: String, Identifiable {
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

    @ObservedObject private var viewModel: AISettingsViewModel
    @ObservedObject private var postProcessingViewModel: PostProcessingSettingsViewModel
    @State private var expandedProvider: AIProvider?
    @State private var editingAPIKeyProvider: AIProvider?
    @State private var modelSelectionTarget: ModelSelectionTarget?
    @State private var modelSearchText = ""

    public init(
        viewModel: AISettingsViewModel,
        postProcessingViewModel: PostProcessingSettingsViewModel,
        initialExpandedProvider: AIProvider? = nil
    ) {
        self.viewModel = viewModel
        self.postProcessingViewModel = postProcessingViewModel
        _expandedProvider = State(initialValue: initialExpandedProvider)
    }

    public var body: some View {
        SettingsScrollableContent {
            MACallout(
                kind: .info,
                title: "settings.enhancements.provider_models.context_title".localized,
                message: "settings.enhancements.provider_models.context_desc".localized
            )

            executionModelSelectorsSection

            VStack(spacing: MeetingAssistantDesignSystem.Layout.spacing12) {
                ForEach(AIProvider.allCases, id: \.self) { provider in
                    providerCard(for: provider)
                }
            }
        }
        .navigationTitle("settings.enhancements.provider_models.title".localized)
        .onAppear {
            let initialProvider = expandedProvider ?? viewModel.activeEnhancementsProvider
            expandedProvider = initialProvider
            viewModel.prepareEnhancementsProvider(initialProvider)
            viewModel.refreshEnhancementsProviderModelsManually()
        }
        .sheet(item: $modelSelectionTarget) { target in
            modelSelectionSheet(for: target)
        }
        .onChange(of: modelSelectionTarget) { _, target in
            if target == nil {
                modelSearchText = ""
            }
        }
    }

    private func providerCard(for provider: AIProvider) -> some View {
        let isExpanded = expandedProvider == provider
        let readinessIssue = viewModel.enhancementsReadinessIssue(for: provider)
        let isReady = readinessIssue == nil

        return MACard {
            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing10) {
                providerHeader(
                    for: provider,
                    isExpanded: isExpanded,
                    isReady: isReady,
                    readinessIssue: readinessIssue
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    handleExpansionToggle(for: provider)
                }

                if isExpanded {
                    Divider()
                    expandedProviderContent(for: provider)
                        .transition(SettingsMotion.sectionTransition())
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityHint("settings.enhancements.provider_models.card.accessibility_hint".localized)
    }

    private func providerHeader(
        for provider: AIProvider,
        isExpanded: Bool,
        isReady: Bool,
        readinessIssue: EnhancementsInferenceReadinessIssue?
    ) -> some View {
        HStack(alignment: .top, spacing: MeetingAssistantDesignSystem.Layout.spacing12) {
            providerAvatar(for: provider)

            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing6) {
                HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
                    Text(provider.displayName)
                        .font(.headline)

                    if isRecommended(provider) {
                        MABadge("settings.enhancements.badge.recommended".localized, kind: .success)
                    }
                }

                Text(providerDescription(for: provider))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
                    providerMetaTag("settings.enhancements.badge.requires_api_key".localized)
                }

                HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing6) {
                    Circle()
                        .fill(isReady ? MeetingAssistantDesignSystem.Colors.success : MeetingAssistantDesignSystem.Colors.warning)
                        .frame(width: 7, height: 7)
                    Text(providerStatusText(isReady: isReady, issue: readinessIssue))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, MeetingAssistantDesignSystem.Layout.spacing4)
        }
    }

    private func expandedProviderContent(for provider: AIProvider) -> some View {
        VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing10) {
            apiKeySection(for: provider)

            if let actionError = viewModel.enhancementsActionError,
               !actionError.isEmpty
            {
                MACallout(
                    kind: .warning,
                    title: "settings.enhancements.provider_models.error.title".localized,
                    message: actionError
                )
            }

            footerActions(for: provider)
        }
    }

    private func apiKeySection(for provider: AIProvider) -> some View {
        VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing6) {
            Text("settings.ai.api_key".localized)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if shouldShowAPIKeyEditor(for: provider) {
                SecureField(
                    "settings.ai.api_key_placeholder".localized,
                    text: $viewModel.enhancementsAPIKeyText
                )
                .textFieldStyle(.roundedBorder)

                if viewModel.isEnhancementsProviderKeySaved {
                    HStack {
                        Spacer()
                        Button("common.cancel".localized) {
                            editingAPIKeyProvider = nil
                            viewModel.enhancementsAPIKeyText = ""
                        }
                        .buttonStyle(.borderless)
                    }
                }
            } else if viewModel.isEnhancementsProviderKeySaved {
                HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(MeetingAssistantDesignSystem.Colors.success)
                    Text("settings.ai.keychain_secure".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("settings.enhancements.provider_models.edit_key".localized) {
                        editingAPIKeyProvider = provider
                    }
                    .buttonStyle(.borderless)

                    Button("settings.ai.remove_key".localized, role: .destructive) {
                        editingAPIKeyProvider = nil
                        viewModel.removeEnhancementsAPIKey()
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
    }

    private func footerActions(for provider: AIProvider) -> some View {
        HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
            if let url = provider.apiKeyURL {
                Button("settings.ai.get_api_key".localized) {
                    NSWorkspace.shared.open(url)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }

            Spacer()

            HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing6) {
                Circle()
                    .fill(viewModel.enhancementsConnectionStatus.color)
                    .frame(width: 7, height: 7)
                Text(viewModel.enhancementsConnectionStatus.text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button("settings.enhancements.test_and_save".localized) {
                viewModel.testEnhancementsAPIConnection()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .disabled(!canTestAndSave(for: provider))
        }
    }

    private func canTestAndSave(for provider: AIProvider) -> Bool {
        guard viewModel.activeEnhancementsProvider == provider else { return false }
        guard viewModel.enhancementsConnectionStatus != .testing else { return false }
        return viewModel.isEnhancementsProviderKeySaved || viewModel.hasPendingEnhancementsAPIKeyInput
    }

    private func handleExpansionToggle(for provider: AIProvider) {
        if expandedProvider == provider {
            expandedProvider = nil
            editingAPIKeyProvider = nil
            return
        }

        expandedProvider = provider
        editingAPIKeyProvider = nil
        viewModel.prepareEnhancementsProvider(provider)
    }

    private func shouldShowAPIKeyEditor(for provider: AIProvider) -> Bool {
        guard viewModel.activeEnhancementsProvider == provider else { return false }
        if !viewModel.isEnhancementsProviderKeySaved { return true }
        if viewModel.hasPendingEnhancementsAPIKeyInput { return true }
        return editingAPIKeyProvider == provider
    }

    private func providerStatusText(isReady: Bool, issue: EnhancementsInferenceReadinessIssue?) -> String {
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

    private var executionModelSelectorsSection: some View {
        MACard {
            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing10) {
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

    private func selectorRow(
        title: String,
        subtitle: String,
        summary: String,
        target: ModelSelectionTarget
    ) -> some View {
        VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing6) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
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

    private func selectionSummary(for selection: EnhancementsAISelection) -> String {
        let model = selection.selectedModel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !model.isEmpty else {
            return "settings.enhancements.provider_models.summary.no_model".localized(with: selection.provider.displayName)
        }
        return "settings.enhancements.provider_models.summary".localized(with: selection.provider.displayName, model)
    }

    private var filteredModelOptions: [EnhancementsProviderModelOption] {
        let query = modelSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return viewModel.enhancementsProviderModels }
        return viewModel.enhancementsProviderModels.filter { option in
            option.modelID.localizedCaseInsensitiveContains(query)
                || option.provider.displayName.localizedCaseInsensitiveContains(query)
        }
    }

    private func modelSelectionSheet(for target: ModelSelectionTarget) -> some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing12) {
                    Text("settings.enhancements.model_selector.title".localized)
                        .font(.headline)

                    Spacer(minLength: MeetingAssistantDesignSystem.Layout.spacing8)

                    modelSelectorSearchField
                        .frame(width: 320)
                }
                .padding(.horizontal, MeetingAssistantDesignSystem.Layout.spacing16)
                .padding(.top, MeetingAssistantDesignSystem.Layout.spacing12)
                .padding(.bottom, MeetingAssistantDesignSystem.Layout.spacing8)

                List(filteredModelOptions, id: \.id) { option in
                    Button {
                        postProcessingViewModel.settings.updateEnhancementsSelection(
                            provider: option.provider,
                            model: option.modelID,
                            for: target.mode
                        )
                        modelSelectionTarget = nil
                    } label: {
                        HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
                            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing4) {
                                Text(option.modelID)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                Text(option.provider.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if isSelectedOption(option, for: target) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(MeetingAssistantDesignSystem.Colors.success)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel".localized) {
                        modelSelectionTarget = nil
                    }
                }
            }
        }
        .frame(minWidth: 520, minHeight: 420)
    }

    private var modelSelectorSearchField: some View {
        HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(
                "settings.enhancements.model_selector.search_placeholder".localized,
                text: $modelSearchText
            )
            .textFieldStyle(.plain)
        }
        .padding(.horizontal, MeetingAssistantDesignSystem.Layout.spacing10)
        .padding(.vertical, MeetingAssistantDesignSystem.Layout.spacing8)
        .frame(height: MeetingAssistantDesignSystem.Layout.compactButtonHeight)
        .background(MeetingAssistantDesignSystem.Colors.subtleFill)
        .clipShape(RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.smallCornerRadius))
    }

    private func isSelectedOption(_ option: EnhancementsProviderModelOption, for target: ModelSelectionTarget) -> Bool {
        let selection: EnhancementsAISelection = switch target {
        case .meeting:
            postProcessingViewModel.settings.enhancementsAISelection
        case .dictation:
            postProcessingViewModel.settings.enhancementsDictationAISelection
        }

        return selection.provider == option.provider && selection.selectedModel == option.modelID
    }

    private func providerDescription(for provider: AIProvider) -> String {
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

    private func isRecommended(_ provider: AIProvider) -> Bool {
        provider == .openai
    }

    private func providerMetaTag(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, MeetingAssistantDesignSystem.Layout.spacing8)
            .padding(.vertical, MeetingAssistantDesignSystem.Layout.spacing4)
            .background(MeetingAssistantDesignSystem.Colors.subtleFill2)
            .clipShape(Capsule())
    }

    private func providerAvatar(for provider: AIProvider) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.smallCornerRadius)
                .fill(MeetingAssistantDesignSystem.Colors.subtleFill2)
                .frame(width: 40, height: 40)

            Image(systemName: provider.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(MeetingAssistantDesignSystem.Colors.accent)
        }
    }
}

private struct PreviewEnhancementsKeychainProvider: KeychainProvider {
    func store(_ value: String, for key: KeychainManager.Key) throws {}
    func retrieve(for key: KeychainManager.Key) throws -> String? {
        nil
    }

    func delete(for key: KeychainManager.Key) throws {}
    func exists(for key: KeychainManager.Key) -> Bool {
        false
    }

    func retrieveAPIKey(for provider: AIProvider) throws -> String? {
        nil
    }

    func existsAPIKey(for provider: AIProvider) -> Bool {
        provider == .openai
    }
}

private struct PreviewEnhancementsLLMService: LLMService {
    func validateURL(_ urlString: String) -> URL? {
        URL(string: "https://api.openai.com/v1")
    }

    func fetchAvailableModels(baseURL: URL, apiKey: String, provider: AIProvider) async throws -> [LLMModel] {
        [
            .init(id: "gpt-4o-mini", object: "model", created: nil, ownedBy: "openai"),
            .init(id: "gpt-4.1-mini", object: "model", created: nil, ownedBy: "openai"),
        ]
    }

    func testConnection(baseURL: URL, apiKey: String, provider: AIProvider) async throws -> Bool {
        true
    }
}

@MainActor
private struct EnhancementsProviderModelsPagePreview: View {
    @StateObject private var aiViewModel: AISettingsViewModel
    @StateObject private var postProcessingViewModel: PostProcessingSettingsViewModel

    init() {
        let settings = AppSettingsStore.shared
        settings.postProcessingEnabled = true
        settings.enhancementsAISelection = EnhancementsAISelection(provider: .openai, selectedModel: "gpt-4o-mini")
        let aiViewModel = AISettingsViewModel(
            settings: settings,
            keychain: PreviewEnhancementsKeychainProvider(),
            llmService: PreviewEnhancementsLLMService()
        )
        aiViewModel.enhancementsConnectionStatus = .unknown
        _aiViewModel = StateObject(wrappedValue: aiViewModel)
        _postProcessingViewModel = StateObject(wrappedValue: PostProcessingSettingsViewModel(settings: settings))
    }

    var body: some View {
        NavigationStack {
            EnhancementsProviderModelsPage(
                viewModel: aiViewModel,
                postProcessingViewModel: postProcessingViewModel,
                initialExpandedProvider: .openai
            )
        }
        .frame(width: 860, height: 640)
    }
}

#Preview("Enhancements Provider Models") {
    EnhancementsProviderModelsPagePreview()
}
