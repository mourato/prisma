import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

/// A unified card for configuring AI provider settings, including status indicators and verification.
public struct AIProviderIntegrationCard: View {
    @ObservedObject var viewModel: AISettingsViewModel
    private let runInitialTasks: Bool

    /// Binding that properly triggers persistence when selectedModel changes.
    /// Using direct struct mutation ($viewModel.settings.aiConfiguration.selectedModel)
    /// does NOT trigger @Published didSet because structs are value types.
    private var selectedModelBinding: Binding<String> {
        Binding(
            get: { viewModel.settings.aiConfiguration.selectedModel },
            set: { newValue in
                viewModel.settings.updateSelectedModel(newValue)
            }
        )
    }

    public init(
        viewModel: AISettingsViewModel,
        runInitialTasks: Bool = !PreviewRuntime.isRunning
    ) {
        self.viewModel = viewModel
        self.runInitialTasks = runInitialTasks
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.Layout.itemSpacing) {
            Text("settings.ai.api_config".localized)
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.primary)
                .padding(.leading, AppDesignSystem.Layout.spacing4)

            DSCard {
                VStack(spacing: 0) {
                    providerRow
                    Divider()
                    apiKeyRow
                    Divider()
                    modelRow
                    if viewModel.settings.aiConfiguration.provider == .custom {
                        Divider()
                        baseURLRow
                    }

                    if let detail = viewModel.connectionStatus.detail, !detail.isEmpty, viewModel.connectionStatus != .success {
                        connectionDetailRow(detail)
                    }

                    if let actionError = viewModel.actionError {
                        actionErrorRow(actionError)
                    }
                }

                footerActions
            }
        }
        .task {
            guard runInitialTasks else { return }
            viewModel.refreshProviderCredentialState()
        }
    }

    // MARK: - Rows

    private var providerRow: some View {
        HStack {
            Text("settings.ai.provider".localized)
                .foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: AppDesignSystem.Layout.spacing8) {
                if viewModel.connectionStatus == .success {
                    HStack(spacing: AppDesignSystem.Layout.spacing4) {
                        Circle()
                            .fill(AppDesignSystem.Colors.success)
                            .frame(width: 8, height: 8)
                        Text("settings.ai.connection.success".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Picker("", selection: $viewModel.settings.aiConfiguration.provider) {
                    ForEach(AIProvider.allCases, id: \.self) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .fixedSize()
                .onChange(of: viewModel.settings.aiConfiguration.provider) { _, newProvider in
                    if newProvider != .custom {
                        viewModel.settings.aiConfiguration.baseURL = newProvider.defaultBaseURL
                    }
                }
            }
        }
        .padding(.vertical, AppDesignSystem.Layout.spacing8)
    }

    private var modelRow: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.Layout.spacing4) {
            HStack {
                Text("settings.ai.model".localized)
                    .foregroundStyle(.secondary)
                Spacer()
                if viewModel.settings.aiConfiguration.provider == .custom {
                    TextField(
                        "",
                        text: $viewModel.settings.aiConfiguration.selectedModel
                    )
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: AppDesignSystem.Layout.maxCompactTextFieldWidth)
                } else {
                    if viewModel.canRefreshModels {
                        Button {
                            viewModel.refreshModelsManually()
                        } label: {
                            if viewModel.isLoadingModels {
                                ProgressView()
                                    .controlSize(.small)
                                    .scaleEffect(0.6)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .accessibilityLabel("settings.ai.model_refresh".localized)
                                    .fontWeight(.medium)
                            }
                        }
                        .controlSize(.regular)
                        .buttonStyle(.borderless)
                        .disabled(viewModel.isLoadingModels || viewModel.connectionStatus == .testing)
                    }

                    Picker("", selection: selectedModelBinding) {
                        if viewModel.isLoadingModels {
                            Text("settings.ai.loading".localized).tag("")
                        } else if viewModel.availableModels.isEmpty {
                            Text("settings.ai.no_models".localized).tag("")
                        } else {
                            Text("settings.ai.model_select".localized).tag("")
                            ForEach(viewModel.availableModels) { model in
                                Text(model.id).tag(model.id)
                            }
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .disabled(viewModel.isLoadingModels || viewModel.availableModels.isEmpty)
                }
            }

            if let refreshSummary = viewModel.modelsRefreshSummary {
                HStack(spacing: AppDesignSystem.Layout.spacing6) {
                    Image(systemName: viewModel.lastModelsRefreshSucceeded ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(
                            viewModel.lastModelsRefreshSucceeded
                                ? AppDesignSystem.Colors.success
                                : AppDesignSystem.Colors.warning
                        )
                    Text(refreshSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if viewModel.canRefreshModels, viewModel.availableModels.isEmpty, !viewModel.isLoadingModels {
                Text("settings.ai.model_hint".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, AppDesignSystem.Layout.spacing8)
    }

    private var baseURLRow: some View {
        HStack {
            Text("settings.ai.base_url".localized)
                .foregroundStyle(.secondary)
            Spacer()
            TextField(
                "https://api.example.com/v1",
                text: $viewModel.settings.aiConfiguration.baseURL
            )
            .textFieldStyle(.plain)
            .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, AppDesignSystem.Layout.spacing8)
    }

    private var apiKeyRow: some View {
        HStack {
            Text("settings.ai.api_key".localized)
                .foregroundStyle(.secondary)
            Spacer()

            if viewModel.isKeySaved {
                HStack(spacing: 8) {
                    Text("settings.ai.keychain_secure".localized)
                        .font(.caption)
                        .foregroundStyle(AppDesignSystem.Colors.success)

                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(AppDesignSystem.Colors.success)

                    Button {
                        viewModel.removeAPIKey()
                    } label: {
                        Text("settings.ai.remove_key".localized)
                    }
                    .buttonStyle(.bordered)
                    .tint(AppDesignSystem.Colors.error)
                    .controlSize(.regular)
                }
            } else {
                SecureField("settings.ai.api_key_placeholder".localized, text: $viewModel.apiKeyText)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: AppDesignSystem.Layout.maxCompactTextFieldWidth)
            }
        }
        .padding(.vertical, AppDesignSystem.Layout.spacing8)
    }

    private func connectionDetailRow(_ detail: String) -> some View {
        HStack(spacing: AppDesignSystem.Layout.spacing6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AppDesignSystem.Colors.warning)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.top, AppDesignSystem.Layout.spacing4)
    }

    private func actionErrorRow(_ error: String) -> some View {
        HStack(spacing: AppDesignSystem.Layout.spacing6) {
            Image(systemName: "exclamationmark.octagon.fill")
                .foregroundStyle(AppDesignSystem.Colors.error)
            Text(error)
                .font(.caption)
                .foregroundStyle(AppDesignSystem.Colors.error)
            Spacer()
        }
        .padding(.top, AppDesignSystem.Layout.spacing4)
    }

    private var footerActions: some View {
        HStack {
            if viewModel.showGetApiKeyButton, let url = viewModel.settings.aiConfiguration.provider.apiKeyURL {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    HStack(spacing: AppDesignSystem.Layout.spacing4) {
                        Image(systemName: "key.fill")
                        Text("settings.ai.get_api_key".localized)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, AppDesignSystem.Layout.spacing8)
                    .padding(.vertical, AppDesignSystem.Layout.spacing4)
                    .background(AppDesignSystem.Colors.selectionFill)
                    .foregroundStyle(AppDesignSystem.Colors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.Layout.chipCornerRadius))
                }
                .buttonStyle(.plain)
            }

            Spacer()

            if viewModel.showVerifyButton {
                Button {
                    viewModel.testAPIConnection()
                } label: {
                    if viewModel.connectionStatus == .testing {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.6)
                    } else {
                        Text("settings.ai.verify_and_save".localized)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled(!viewModel.hasPendingAPIKeyInput || viewModel.connectionStatus == .testing)
            }
        }
        .padding(.top, AppDesignSystem.Layout.spacing8)
    }
}

private struct PreviewKeychainProvider: KeychainProvider {
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
        false
    }
}

private struct PreviewLLMService: LLMService {
    func validateURL(_ urlString: String) -> URL? {
        URL(string: "https://api.openai.com/v1")
    }

    func fetchAvailableModels(baseURL: URL, apiKey: String, provider: AIProvider) async throws -> [LLMModel] {
        []
    }

    func testConnection(baseURL: URL, apiKey: String, provider: AIProvider) async throws -> Bool {
        true
    }
}

@MainActor
private struct AIProviderIntegrationCardPreview: View {
    @StateObject private var viewModel: AISettingsViewModel

    init() {
        let viewModel = AISettingsViewModel(
            settings: .shared,
            keychain: PreviewKeychainProvider(),
            llmService: PreviewLLMService()
        )
        viewModel.settings.aiConfiguration.provider = .openai
        viewModel.settings.aiConfiguration.baseURL = AIProvider.openai.defaultBaseURL
        viewModel.settings.updateSelectedModel("gpt-4o-mini")
        viewModel.apiKeyText = "sk-preview-key"
        viewModel.connectionStatus = .unknown
        viewModel.availableModels = []
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        AIProviderIntegrationCard(viewModel: viewModel, runInitialTasks: false)
            .padding()
            .frame(width: 760)
    }
}

#Preview("AI Provider Integration") {
    AIProviderIntegrationCardPreview()
}
