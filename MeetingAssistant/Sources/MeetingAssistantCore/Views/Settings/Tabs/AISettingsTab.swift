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
        .onAppear {
            self.viewModel.apiKeyText = (try? KeychainManager.retrieve(for: .aiAPIKey)) ?? ""
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var mainSection: some View {
        SettingsGroup("Geral", icon: "brain") {
            Toggle(
                "Habilitar processamento de transcrições com IA",
                isOn: self.$viewModel.settings.aiEnabled
            )

            Text(
                "Quando habilitado, as transcrições serão enviadas para um modelo de IA " +
                    "para correção, formatação e resumo."
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            Divider()
                .padding(.vertical, 4)

            Toggle("Identificar Oradores (Beta)", isOn: self.$viewModel.settings.isDiarizationEnabled)

            Text(
                "Identifica quem está falando na reunião. Aumenta significativamente o tempo de processamento."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var providerSection: some View {
        SettingsGroup("Provedor", icon: "server.rack") {
            Picker("Provedor de IA:", selection: self.$viewModel.settings.aiConfiguration.provider) {
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
        SettingsGroup("Configuração da API", icon: "key.fill") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("URL Base:")
                        .frame(width: 80, alignment: .leading)
                    TextField(
                        self.viewModel.settings.aiConfiguration.provider.defaultBaseURL,
                        text: self.$viewModel.settings.aiConfiguration.baseURL
                    )
                    .textFieldStyle(.roundedBorder)
                }

                HStack {
                    Text("Chave API:")
                        .frame(width: 80, alignment: .leading)
                    Group {
                        if self.viewModel.showAPIKey {
                            TextField("sk-...", text: self.$viewModel.apiKeyText)
                        } else {
                            SecureField("sk-...", text: self.$viewModel.apiKeyText)
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: self.viewModel.apiKeyText) { _, newValue in
                        self.viewModel.saveAPIKey(newValue)
                    }

                    Button {
                        self.viewModel.showAPIKey.toggle()
                    } label: {
                        Image(systemName: self.viewModel.showAPIKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                    .help(self.viewModel.showAPIKey ? "Ocultar chave" : "Mostrar chave")
                }

                HStack {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(.green)
                    Text("Chave armazenada com segurança no Keychain")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Divider()
                    .padding(.vertical, 4)

                HStack {
                    Text("Modelo:")
                        .frame(width: 80, alignment: .leading)
                    TextField(
                        "gpt-4o, claude-3-5-sonnet...", text: self.$viewModel.settings.aiConfiguration.selectedModel
                    )
                    .textFieldStyle(.roundedBorder)
                }

                Text("O modelo será selecionável automaticamente em uma versão futura.")
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
                        Text("Testar Conexão")
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
