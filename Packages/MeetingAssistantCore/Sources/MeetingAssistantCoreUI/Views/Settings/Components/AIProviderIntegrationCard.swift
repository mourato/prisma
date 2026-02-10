import SwiftUI
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

/// A unified card for configuring AI provider settings, including status indicators and verification.
public struct AIProviderIntegrationCard: View {
    @ObservedObject var viewModel: AISettingsViewModel

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

    public init(viewModel: AISettingsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.itemSpacing) {
            Text("settings.ai.api_config".localized)
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.primary)
                .padding(.leading, MeetingAssistantDesignSystem.Layout.spacing4)

            MACard {
                VStack(spacing: 0) {
                    providerRow
                    Divider()
                    modelRow
                    Divider()
                    apiKeyRow
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
            viewModel.refreshProviderCredentialState()
        }
    }

    // MARK: - Rows

    private var providerRow: some View {
        HStack {
            Text("settings.ai.provider".localized)
                .foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
                if viewModel.connectionStatus == .success {
                    HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing4) {
                        Circle()
                            .fill(MeetingAssistantDesignSystem.Colors.success)
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
        .padding(.vertical, MeetingAssistantDesignSystem.Layout.spacing8)
    }

    private var modelRow: some View {
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
                .frame(maxWidth: MeetingAssistantDesignSystem.Layout.maxCompactTextFieldWidth)
            } else {
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
                .frame(maxWidth: MeetingAssistantDesignSystem.Layout.maxPickerWidth)
                .disabled(viewModel.isLoadingModels || viewModel.availableModels.isEmpty)
            }
        }
        .padding(.vertical, MeetingAssistantDesignSystem.Layout.spacing8)
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
            .frame(maxWidth: MeetingAssistantDesignSystem.Layout.maxTextFieldWidth)
        }
        .padding(.vertical, MeetingAssistantDesignSystem.Layout.spacing8)
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
                        .foregroundStyle(MeetingAssistantDesignSystem.Colors.success)

                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(MeetingAssistantDesignSystem.Colors.success)

                    Button {
                        viewModel.removeAPIKey()
                    } label: {
                        Text("settings.ai.remove_key".localized)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            } else {
                SecureField("settings.ai.api_key_placeholder".localized, text: $viewModel.apiKeyText)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: MeetingAssistantDesignSystem.Layout.maxCompactTextFieldWidth)
            }
        }
        .padding(.vertical, MeetingAssistantDesignSystem.Layout.spacing8)
    }

    private func connectionDetailRow(_ detail: String) -> some View {
        HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(MeetingAssistantDesignSystem.Colors.warning)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.top, MeetingAssistantDesignSystem.Layout.spacing4)
    }

    private func actionErrorRow(_ error: String) -> some View {
        HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing6) {
            Image(systemName: "exclamationmark.octagon.fill")
                .foregroundStyle(MeetingAssistantDesignSystem.Colors.error)
            Text(error)
                .font(.caption)
                .foregroundStyle(MeetingAssistantDesignSystem.Colors.error)
            Spacer()
        }
        .padding(.top, MeetingAssistantDesignSystem.Layout.spacing4)
    }

    private var footerActions: some View {
        HStack {
            if viewModel.showGetApiKeyButton, let url = viewModel.settings.aiConfiguration.provider.apiKeyURL {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing4) {
                        Image(systemName: "key.fill")
                        Text("settings.ai.get_api_key".localized)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, MeetingAssistantDesignSystem.Layout.spacing8)
                    .padding(.vertical, MeetingAssistantDesignSystem.Layout.spacing4)
                    .background(MeetingAssistantDesignSystem.Colors.selectionFill)
                    .foregroundStyle(MeetingAssistantDesignSystem.Colors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.chipCornerRadius))
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
                .controlSize(.small)
                .disabled(viewModel.apiKeyText.isEmpty || viewModel.connectionStatus == .testing)
            }
        }
        .padding(.top, MeetingAssistantDesignSystem.Layout.spacing8)
    }
}
