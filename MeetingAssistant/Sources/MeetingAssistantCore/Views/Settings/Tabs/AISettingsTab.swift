import os.log
import SwiftUI

// MARK: - AI Settings Tab

/// Tab for configuring AI post-processing settings.
public struct AISettingsTab: View {
    @ObservedObject private var settings = AppSettingsStore.shared
    @State private var showAPIKey = false
    @State private var apiKeyText = ""
    @State private var connectionStatus: ConnectionStatus = .unknown

    private let logger = Logger(subsystem: "MeetingAssistant", category: "AISettings")

    public init() {}

    public var body: some View {
        Form {
            Section("Pós-Processamento com IA") {
                Toggle("Habilitar processamento de transcrições com IA", isOn: self.$settings.aiEnabled)

                Text(
                    "Quando habilitado, as transcrições serão enviadas para um modelo de IA para correção, formatação e resumo."
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Toggle("Identificar Oradores (Beta)", isOn: self.$settings.isDiarizationEnabled)

                Text(
                    "Identifica quem está falando na reunião. Aumenta significativamente o tempo de processamento."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if self.settings.aiEnabled {
                self.providerSection
                self.apiConfigurationSection
                self.connectionTestSection
            }
        }
        .padding()
        .onAppear {
            self.apiKeyText = (try? KeychainManager.retrieve(for: .aiAPIKey)) ?? ""
        }
    }

    // MARK: - Provider Section

    @ViewBuilder
    private var providerSection: some View {
        Section("Provedor") {
            Picker("Provedor de IA:", selection: self.$settings.aiConfiguration.provider) {
                ForEach(AIProvider.allCases, id: \.self) { provider in
                    HStack {
                        Image(systemName: provider.icon)
                        Text(provider.displayName)
                    }
                    .tag(provider)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: self.settings.aiConfiguration.provider) { _, newProvider in
                if newProvider != .custom {
                    self.settings.aiConfiguration.baseURL = newProvider.defaultBaseURL
                }
                self.connectionStatus = .unknown
            }
        }
    }

    // MARK: - API Configuration Section

    @ViewBuilder
    private var apiConfigurationSection: some View {
        Section("Configuração da API") {
            HStack {
                Text("URL Base:")
                TextField(
                    self.settings.aiConfiguration.provider.defaultBaseURL,
                    text: self.$settings.aiConfiguration.baseURL
                )
                .textFieldStyle(.roundedBorder)
            }

            HStack {
                Text("Chave API:")
                Group {
                    if self.showAPIKey {
                        TextField("sk-...", text: self.$apiKeyText)
                    } else {
                        SecureField("sk-...", text: self.$apiKeyText)
                    }
                }
                .textFieldStyle(.roundedBorder)
                .onChange(of: self.apiKeyText) { _, newValue in
                    self.saveAPIKeyToKeychain(newValue)
                }

                Button {
                    self.showAPIKey.toggle()
                } label: {
                    Image(systemName: self.showAPIKey ? "eye.slash" : "eye")
                }
                .buttonStyle(.borderless)
                .help(self.showAPIKey ? "Ocultar chave" : "Mostrar chave")
            }

            HStack {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(.green)
                Text("Chave armazenada com segurança no Keychain")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Modelo:")
                TextField(
                    "gpt-4o, claude-3-5-sonnet...", text: self.$settings.aiConfiguration.selectedModel
                )
                .textFieldStyle(.roundedBorder)
            }

            Text("O modelo será selecionável automaticamente em uma versão futura.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Connection Test Section

    @ViewBuilder
    private var connectionTestSection: some View {
        Section {
            HStack {
                Button("Testar Conexão") {
                    self.testAPIConnection()
                }
                .disabled(!self.settings.aiConfiguration.isValid || self.connectionStatus == .testing)

                Spacer()

                HStack(spacing: 4) {
                    if self.connectionStatus == .testing {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Circle()
                        .fill(self.connectionStatus.color)
                        .frame(width: 8, height: 8)
                    Text(self.connectionStatus.text)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Private Methods

    /// Saves API key to Keychain with proper error handling.
    private func saveAPIKeyToKeychain(_ value: String) {
        do {
            if !value.isEmpty {
                try KeychainManager.store(value, for: .aiAPIKey)
            } else {
                try KeychainManager.delete(for: .aiAPIKey)
            }
        } catch {
            self.logger.error("Failed to save API key to Keychain: \(error.localizedDescription)")
            // NOTE: In a future iteration, show user feedback via an alert
        }
    }

    func testAPIConnection() {
        self.connectionStatus = .testing

        let urlString = self.settings.aiConfiguration.baseURL

        // Validate URL format and scheme
        guard let url = URL(string: urlString),
              let scheme = url.scheme,
              ["http", "https"].contains(scheme.lowercased())
        else {
            self.connectionStatus = .failure("URL inválida")
            return
        }

        Task {
            do {
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.timeoutInterval = 5

                if let key = try? KeychainManager.retrieve(for: .aiAPIKey), !key.isEmpty {
                    request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
                }

                let (_, response) = try await URLSession.shared.data(for: request)

                await MainActor.run {
                    if let httpResponse = response as? HTTPURLResponse {
                        // Only 2xx codes indicate true success
                        if (200...299).contains(httpResponse.statusCode) {
                            self.connectionStatus = .success
                        } else {
                            self.connectionStatus = .failure("HTTP \(httpResponse.statusCode)")
                        }
                    } else {
                        self.connectionStatus = .failure("Resposta inválida")
                    }
                }
            } catch {
                await MainActor.run {
                    self.connectionStatus = .failure(error.localizedDescription)
                }
            }
        }
    }
}

#Preview {
    AISettingsTab()
}
