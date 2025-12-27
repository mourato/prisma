import os.log
import SwiftUI

// MARK: - AI Settings Tab

/// Tab for configuring AI post-processing settings.
public struct AISettingsTab: View {
    @StateObject private var viewModel = AISettingsViewModel()

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: SettingsDesignSystem.Layout.sectionSpacing) {
                self.mainSection

                if self.viewModel.settings.aiEnabled {
                    self.providerSection
                    self.apiConfigurationSection
                    self.connectionTestSection
                }
            }
            .padding()
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var mainSection: some View {
        SettingsGroup(NSLocalizedString("settings.general.title", bundle: .safeModule, comment: ""), icon: "brain") {
            Toggle(
                NSLocalizedString("settings.ai.enabled", bundle: .safeModule, comment: ""),
                isOn: self.$viewModel.settings.aiEnabled
            )

            Text(NSLocalizedString("settings.ai.description", bundle: .safeModule, comment: ""))
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()
                .padding(.vertical, 4)

            Toggle(
                NSLocalizedString("settings.ai.diarization", bundle: .safeModule, comment: ""),
                isOn: self.$viewModel.settings.isDiarizationEnabled
            )

            Text(NSLocalizedString("settings.ai.diarization_desc", bundle: .safeModule, comment: ""))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var providerSection: some View {
        SettingsGroup(NSLocalizedString("settings.ai.provider", bundle: .safeModule, comment: ""), icon: "server.rack") {
            Picker(
                NSLocalizedString("settings.ai.provider_label", bundle: .safeModule, comment: ""),
                selection: self.$viewModel.settings.aiConfiguration.provider
            ) {
                ForEach(AIProvider.allCases, id: \.self) { provider in
                    HStack {
                        Image(systemName: provider.icon)
                        Text(provider.displayName)
                    }
                    .tag(provider)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: self.viewModel.settings.aiConfiguration.provider) { _, newProvider in
                if newProvider != .custom {
                    self.viewModel.settings.aiConfiguration.baseURL = newProvider.defaultBaseURL
                }
                self.viewModel.connectionStatus = .unknown
            }
        }
    }

    @ViewBuilder
    private var apiConfigurationSection: some View {
        SettingsGroup(NSLocalizedString("settings.ai.api_config", bundle: .safeModule, comment: ""), icon: "key.fill") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(NSLocalizedString("settings.ai.base_url", bundle: .safeModule, comment: ""))
                        .frame(width: 80, alignment: .leading)
                    TextField(
                        self.viewModel.settings.aiConfiguration.provider.defaultBaseURL,
                        text: self.$viewModel.settings.aiConfiguration.baseURL
                    )
                    .textFieldStyle(.roundedBorder)
                }

                HStack {
                    Text(NSLocalizedString("settings.ai.api_key", bundle: .safeModule, comment: ""))
                        .frame(width: 80, alignment: .leading)
                    Group {
                        if self.viewModel.showAPIKey {
                            TextField("sk-...", text: self.$viewModel.apiKeyText)
                        } else {
                            SecureField("sk-...", text: self.$viewModel.apiKeyText)
                        }
                    }
                    .textFieldStyle(.roundedBorder)

                    Button {
                        self.viewModel.showAPIKey.toggle()
                    } label: {
                        Image(systemName: self.viewModel.showAPIKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                    .help(
                        self.viewModel.showAPIKey
                            ? NSLocalizedString("settings.ai.hide_key", bundle: .safeModule, comment: "")
                            : NSLocalizedString("settings.ai.show_key", bundle: .safeModule, comment: "")
                    )
                }

                HStack {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(.green)
                    Text(NSLocalizedString("settings.ai.keychain_secure", bundle: .safeModule, comment: ""))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Divider()
                    .padding(.vertical, 4)

                self.modelSelectionSection
            }
        }
    }

    // MARK: - Model Selection

    @ViewBuilder
    private var modelSelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(NSLocalizedString("settings.ai.model", bundle: .safeModule, comment: ""))
                    .frame(width: 80, alignment: .leading)

                if self.viewModel.isLoadingModels {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if !self.viewModel.availableModels.isEmpty {
                    Picker("", selection: self.$viewModel.settings.aiConfiguration.selectedModel) {
                        Text(NSLocalizedString("settings.ai.model_select", bundle: .safeModule, comment: ""))
                            .tag("")
                        ForEach(self.viewModel.availableModels) { model in
                            Text(model.id).tag(model.id)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    TextField(
                        "gpt-4o, claude-3-5-sonnet...",
                        text: self.$viewModel.settings.aiConfiguration.selectedModel
                    )
                    .textFieldStyle(.roundedBorder)
                }

                Button {
                    Task { await self.viewModel.fetchAvailableModels() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(self.viewModel.isLoadingModels || !self.viewModel.settings.aiConfiguration.isValid)
                .help(NSLocalizedString("settings.ai.model_refresh", bundle: .safeModule, comment: ""))
            }

            if let error = self.viewModel.modelsFetchError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if !self.viewModel.availableModels.isEmpty {
                Text(
                    String(
                        format: NSLocalizedString("settings.ai.models_loaded", bundle: .safeModule, comment: ""),
                        self.viewModel.availableModels.count
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                Text(NSLocalizedString("settings.ai.model_hint", bundle: .safeModule, comment: ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var connectionTestSection: some View {
        SettingsCard {
            HStack {
                Button(action: {
                    self.viewModel.testAPIConnection()
                }) {
                    HStack {
                        if self.viewModel.connectionStatus == .testing {
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.7)
                        }
                        Text(NSLocalizedString("settings.ai.test_connection", bundle: .safeModule, comment: ""))
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    !self.viewModel.settings.aiConfiguration.isValid ||
                        self.viewModel.connectionStatus == .testing
                )

                Spacer()

                HStack(spacing: 8) {
                    Circle()
                        .fill(self.viewModel.connectionStatus.color)
                        .frame(width: 8, height: 8)
                        .symbolEffect(.pulse, isActive: self.viewModel.connectionStatus == .testing)

                    Text(self.viewModel.connectionStatus.text)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    AISettingsTab()
}

#Preview {
    AISettingsTab()
}
