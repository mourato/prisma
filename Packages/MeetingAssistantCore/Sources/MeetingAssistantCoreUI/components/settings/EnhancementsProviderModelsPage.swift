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
            DSCallout(
                kind: .info,
                title: "settings.enhancements.provider_models.context_title".localized,
                message: "settings.enhancements.provider_models.context_desc".localized
            )

            executionModelSelectorsSection

            VStack(spacing: 12) {
                ForEach(AIProvider.allCases, id: \.self) { provider in
                    providerCard(for: provider)
                }
            }
        }
        .onAppear {
            let initialProvider = expandedProvider ?? viewModel.activeEnhancementsProvider
            expandedProvider = initialProvider
            viewModel.prepareEnhancementsProvider(initialProvider)
            viewModel.refreshEnhancementsProviderModelsManually()
        }
        .sheet(item: $modelSelectionTarget) { target in
            EnhancementsModelSelectionSheet(
                options: viewModel.enhancementsProviderModels,
                isSelected: { option in
                    isSelectedOption(option, for: target)
                },
                onSelect: { option in
                    postProcessingViewModel.settings.updateEnhancementsSelection(
                        provider: option.provider,
                        model: option.modelID,
                        for: target.mode
                    )
                    modelSelectionTarget = nil
                },
                onCancel: {
                    modelSelectionTarget = nil
                }
            )
        }
    }

    private func providerCard(for provider: AIProvider) -> some View {
        let isExpanded = expandedProvider == provider
        let readinessIssue = viewModel.enhancementsReadinessIssue(for: provider)
        let isReady = readinessIssue == nil

        return DSCard {
            VStack(alignment: .leading, spacing: 10) {
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
        HStack(alignment: .top, spacing: 12) {
            providerAvatar(for: provider)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(provider.displayName)
                        .font(.headline)

                    if isRecommended(provider) {
                        DSBadge("settings.enhancements.badge.recommended".localized, kind: .success)
                    }
                }

                Text(providerDescription(for: provider))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    providerMetaTag("settings.enhancements.badge.requires_api_key".localized)
                }

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

            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }

    private func expandedProviderContent(for provider: AIProvider) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            apiKeySection(for: provider)

            if let actionError = viewModel.enhancementsActionError,
               !actionError.isEmpty
            {
                DSCallout(
                    kind: .warning,
                    title: "settings.enhancements.provider_models.error.title".localized,
                    message: actionError
                )
            }

            footerActions(for: provider)
        }
    }

    private func apiKeySection(for provider: AIProvider) -> some View {
        VStack(alignment: .leading, spacing: 6) {
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
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(AppDesignSystem.Colors.success)
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
        HStack(spacing: 8) {
            if let url = provider.apiKeyURL {
                Button("settings.ai.get_api_key".localized) {
                    NSWorkspace.shared.open(url)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }

            Spacer()

            HStack(spacing: 6) {
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

    private func selectorRow(
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

    private func selectionSummary(for selection: EnhancementsAISelection) -> String {
        let model = selection.selectedModel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !model.isEmpty else {
            return "settings.enhancements.provider_models.summary.no_model".localized(with: selection.provider.displayName)
        }
        return "settings.enhancements.provider_models.summary".localized(with: selection.provider.displayName, model)
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
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AppDesignSystem.Colors.subtleFill2)
            .clipShape(Capsule())
    }

    private func providerAvatar(for provider: AIProvider) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppDesignSystem.Layout.smallCornerRadius)
                .fill(provider.logoBackgroundColor)
                .frame(width: 40, height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: AppDesignSystem.Layout.smallCornerRadius)
                        .strokeBorder(AppDesignSystem.Colors.separator.opacity(0.18), lineWidth: 1)
                )

            if let logoImage = providerLogoImage(for: provider) {
                if let tint = provider.logoTintColor {
                    logoImage
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(tint)
                        .frame(width: 22, height: 22)
                } else {
                    logoImage
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                }
            } else {
                Image(systemName: provider.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppDesignSystem.Colors.accent)
            }
        }
    }

    private func providerLogoImage(for provider: AIProvider) -> Image? {
        guard let logoAssetName = provider.logoAssetName,
              let logoURL = Bundle.module.url(
                  forResource: logoAssetName,
                  withExtension: "png",
                  subdirectory: "ProviderLogos"
              ),
              let nsImage = NSImage(contentsOf: logoURL)
        else {
            return nil
        }

        return Image(nsImage: nsImage)
    }
}

private extension AIProvider {
    var logoAssetName: String? {
        switch self {
        case .openai:
            "openai"
        case .anthropic:
            "anthropic"
        case .groq:
            "groq"
        case .google:
            "google"
        case .custom:
            nil
        }
    }

    var logoBackgroundColor: Color {
        switch self {
        case .openai:
            Color(
                red: 0.0 / 255.0,
                green: 0.0 / 255.0,
                blue: 0.0 / 255.0
            )
        case .anthropic:
            Color(
                red: 242.0 / 255.0,
                green: 237.0 / 255.0,
                blue: 229.0 / 255.0
            )
        case .groq:
            Color(
                red: 232.0 / 255.0,
                green: 80.0 / 255.0,
                blue: 53.0 / 255.0
            )
        case .google:
            Color.white
        case .custom:
            AppDesignSystem.Colors.subtleFill2
        }
    }

    var logoTintColor: Color? {
        switch self {
        case .openai, .groq:
            .white
        case .anthropic, .google, .custom:
            nil
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
