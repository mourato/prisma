import SwiftUI

/// A unified card for configuring AI provider settings, including status indicators and verification.
public struct AIProviderIntegrationCard: View {
    @ObservedObject var viewModel: AISettingsViewModel

    public init(viewModel: AISettingsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: SettingsDesignSystem.Layout.itemSpacing) {
            Text("settings.ai.api_config".localized)
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.primary)
                .padding(.leading, 4)

            SettingsCard {
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
    }

    // MARK: - Rows

    private var providerRow: some View {
        HStack {
            Text("settings.ai.provider".localized)
                .foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 8) {
                if viewModel.connectionStatus == .success {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.green)
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
        .padding(.vertical, 8)
    }

    private var modelRow: some View {
        HStack {
            Text("settings.ai.model".localized)
                .foregroundStyle(.secondary)
            Spacer()
            if viewModel.isLoadingModels {
                ProgressView()
                    .controlSize(.small)
            } else if !viewModel.availableModels.isEmpty {
                Picker("", selection: $viewModel.settings.aiConfiguration.selectedModel) {
                    Text("settings.ai.model_select".localized)
                        .tag("")
                    ForEach(viewModel.availableModels) { model in
                        Text(model.id).tag(model.id)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: SettingsDesignSystem.Layout.maxPickerWidth)
            } else {
                TextField(
                    "",
                    text: $viewModel.settings.aiConfiguration.selectedModel
                )
                .textFieldStyle(.plain)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: SettingsDesignSystem.Layout.maxCompactTextFieldWidth)
            }
        }
        .padding(.vertical, 8)
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
            .frame(maxWidth: SettingsDesignSystem.Layout.maxTextFieldWidth)
        }
        .padding(.vertical, 8)
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
                        .foregroundStyle(.green)

                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.green)

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
                    .frame(maxWidth: SettingsDesignSystem.Layout.maxCompactTextFieldWidth)
            }
        }
        .padding(.vertical, 8)
    }

    private func connectionDetailRow(_ detail: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.top, 4)
    }

    private func actionErrorRow(_ error: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.octagon.fill")
                .foregroundStyle(.red)
            Text(error)
                .font(.caption)
                .foregroundStyle(.red)
            Spacer()
        }
        .padding(.top, 4)
    }

    private var footerActions: some View {
        HStack {
            if viewModel.showGetApiKeyButton, let url = viewModel.settings.aiConfiguration.provider.apiKeyURL {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "key.fill")
                        Text("settings.ai.get_api_key".localized)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(SettingsDesignSystem.Colors.accent.opacity(0.1))
                    .foregroundStyle(SettingsDesignSystem.Colors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
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
        .padding(.top, 8)
    }
}
