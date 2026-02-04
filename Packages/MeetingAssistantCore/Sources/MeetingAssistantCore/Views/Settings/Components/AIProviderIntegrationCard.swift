import SwiftUI

/// A unified card for configuring AI provider settings, including status indicators and verification.
public struct AIProviderIntegrationCard: View {
    @ObservedObject var viewModel: AISettingsViewModel

    public init(viewModel: AISettingsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: SettingsDesignSystem.Layout.itemSpacing) {
            Text(NSLocalizedString("settings.ai.api_config", bundle: .safeModule, comment: ""))
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
            Text(NSLocalizedString("settings.ai.provider", bundle: .safeModule, comment: ""))
                .foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 8) {
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
                    viewModel.connectionStatus = .unknown
                }

                if viewModel.connectionStatus == .success {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                        Text(NSLocalizedString("settings.ai.connection.success", bundle: .safeModule, comment: ""))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var modelRow: some View {
        HStack {
            Text(NSLocalizedString("settings.ai.model", bundle: .safeModule, comment: ""))
                .foregroundStyle(.secondary)
            Spacer()
            if viewModel.isLoadingModels {
                ProgressView()
                    .controlSize(.small)
            } else if !viewModel.availableModels.isEmpty {
                Picker("", selection: $viewModel.settings.aiConfiguration.selectedModel) {
                    Text(NSLocalizedString("settings.ai.model_select", bundle: .safeModule, comment: ""))
                        .tag("")
                    ForEach(viewModel.availableModels) { model in
                        Text(model.id).tag(model.id)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .fixedSize()
            } else {
                TextField(
                    NSLocalizedString("settings.ai.model_placeholder", bundle: .safeModule, comment: ""),
                    text: $viewModel.settings.aiConfiguration.selectedModel
                )
                .textFieldStyle(.plain)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 200)
            }
        }
        .padding(.vertical, 8)
    }

    private var baseURLRow: some View {
        HStack {
            Text(NSLocalizedString("settings.ai.base_url", bundle: .safeModule, comment: ""))
                .foregroundStyle(.secondary)
            Spacer()
            TextField(
                "https://api.example.com/v1",
                text: $viewModel.settings.aiConfiguration.baseURL
            )
            .textFieldStyle(.plain)
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: 300)
        }
        .padding(.vertical, 8)
    }

    private var apiKeyRow: some View {
        HStack {
            Text(NSLocalizedString("settings.ai.api_key", bundle: .safeModule, comment: ""))
                .foregroundStyle(.secondary)
            Spacer()
            
            let keyExists = viewModel.isKeySaved
            
            if keyExists && viewModel.connectionStatus == .success {
                HStack(spacing: 8) {
                    Text(NSLocalizedString("settings.ai.keychain_secure", bundle: .safeModule, comment: ""))
                        .font(.caption)
                        .foregroundStyle(.green)
                    
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.green)

                    Button {
                        viewModel.removeAPIKey()
                    } label: {
                        Text(NSLocalizedString("settings.ai.remove_key", bundle: .safeModule, comment: ""))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            } else if keyExists && viewModel.connectionStatus == .unknown {
                HStack(spacing: 8) {
                    SecureField(NSLocalizedString("settings.ai.api_key_placeholder", bundle: .safeModule, comment: ""), text: $viewModel.apiKeyText)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 200)
                    
                    Button {
                        viewModel.removeAPIKey()
                    } label: {
                        Text(NSLocalizedString("settings.ai.remove_key", bundle: .safeModule, comment: ""))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            } else {
                SecureField(NSLocalizedString("settings.ai.api_key_placeholder", bundle: .safeModule, comment: ""), text: $viewModel.apiKeyText)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 250)
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
        let provider = viewModel.settings.aiConfiguration.provider
        let keyExists = viewModel.isKeySaved
        let isVerified = viewModel.connectionStatus == .success
        
        return HStack {
            if let url = provider.apiKeyURL, !isVerified {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "key.fill")
                        Text(NSLocalizedString("settings.ai.get_api_key", bundle: .safeModule, comment: ""))
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

            if !isVerified || !keyExists {
                Button {
                    viewModel.testAPIConnection()
                } label: {
                    if viewModel.connectionStatus == .testing {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.6)
                    } else {
                        Text(NSLocalizedString("settings.ai.verify_and_save", bundle: .safeModule, comment: ""))
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
