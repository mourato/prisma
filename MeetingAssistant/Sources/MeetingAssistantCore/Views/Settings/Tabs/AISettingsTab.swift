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
        SettingsGroup(NSLocalizedString("settings.general.title", comment: ""), icon: "brain") {
            Toggle(
                NSLocalizedString("settings.ai.enabled", comment: ""),
                isOn: self.$viewModel.settings.aiEnabled
            )

            Text(NSLocalizedString("settings.ai.description", comment: ""))
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()
                .padding(.vertical, 4)

            Toggle(NSLocalizedString("settings.ai.diarization", comment: ""), isOn: self.$viewModel.settings.isDiarizationEnabled)

            Text(NSLocalizedString("settings.ai.diarization_desc", comment: ""))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var providerSection: some View {
        SettingsGroup(NSLocalizedString("settings.ai.provider", comment: ""), icon: "server.rack") {
            Picker(NSLocalizedString("settings.ai.provider_label", comment: ""), selection: self.$viewModel.settings.aiConfiguration.provider) {
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
        SettingsGroup(NSLocalizedString("settings.ai.api_config", comment: ""), icon: "key.fill") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(NSLocalizedString("settings.ai.base_url", comment: ""))
                        .frame(width: 80, alignment: .leading)
                    TextField(
                        self.viewModel.settings.aiConfiguration.provider.defaultBaseURL,
                        text: self.$viewModel.settings.aiConfiguration.baseURL
                    )
                    .textFieldStyle(.roundedBorder)
                }

                HStack {
                    Text(NSLocalizedString("settings.ai.api_key", comment: ""))
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
                    .help(self.viewModel.showAPIKey ? NSLocalizedString("settings.ai.hide_key", comment: "") : NSLocalizedString("settings.ai.show_key", comment: ""))
                }

                HStack {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(.green)
                    Text(NSLocalizedString("settings.ai.keychain_secure", comment: ""))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Divider()
                    .padding(.vertical, 4)

                HStack {
                    Text(NSLocalizedString("settings.ai.model", comment: ""))
                        .frame(width: 80, alignment: .leading)
                    TextField(
                        "gpt-4o, claude-3-5-sonnet...", text: self.$viewModel.settings.aiConfiguration.selectedModel
                    )
                    .textFieldStyle(.roundedBorder)
                }

                Text(NSLocalizedString("settings.ai.model_future", comment: ""))
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
                        Text(NSLocalizedString("settings.ai.test_connection", comment: ""))
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!self.viewModel.settings.aiConfiguration.isValid || self.viewModel.connectionStatus == .testing)

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
