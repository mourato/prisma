import SwiftUI

/// Settings view for app configuration.
/// Organized into tabs: General, Shortcuts, AI Post-Processing, and Service.
struct SettingsView: View {
    @AppStorage("autoStartRecording") private var autoStartRecording = true
    @AppStorage("transcriptionServiceURL") private var serviceURL = "http://127.0.0.1:8765"
    @AppStorage("recordingsDirectory") private var recordingsPath = ""
    
    var body: some View {
        TabView {
            generalSettings
                .tabItem {
                    Label("Geral", systemImage: "gear")
                }
            
            shortcutSettings
                .tabItem {
                    Label("Atalhos", systemImage: "command")
                }
            
            aiSettings
                .tabItem {
                    Label("IA", systemImage: "brain")
                }
            
            serviceSettings
                .tabItem {
                    Label("Serviço", systemImage: "server.rack")
                }
        }
        .padding()
        .frame(width: 500, height: 400)
    }
    
    // MARK: - General Tab
    
    @ViewBuilder
    private var generalSettings: some View {
        Form {
            Section("Gravação") {
                Toggle("Iniciar gravação automaticamente ao detectar reunião", isOn: $autoStartRecording)
                
                HStack {
                    Text("Pasta de gravações:")
                    TextField("Caminho", text: $recordingsPath)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("Escolher...") {
                        selectRecordingsDirectory()
                    }
                }
            }
            
            Section("Apps Monitorados") {
                monitoredAppsList
            }
        }
    }
    
    // MARK: - Shortcuts Tab
    
    @ViewBuilder
    private var shortcutSettings: some View {
        ShortcutSettingsTab()
    }
    
    // MARK: - AI Settings Tab
    
    @ViewBuilder
    private var aiSettings: some View {
        AISettingsTab()
    }
    
    // MARK: - Service Tab
    
    @ViewBuilder
    private var serviceSettings: some View {
        Form {
            Section("Serviço de Transcrição") {
                HStack {
                    Text("URL do serviço:")
                    TextField("http://127.0.0.1:8765", text: $serviceURL)
                        .textFieldStyle(.roundedBorder)
                }
                
                HStack {
                    Button("Testar Conexão") {
                        testConnection()
                    }
                    
                    Spacer()
                    
                    Text("Status: Não conectado")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Section("Modelo") {
                Text("Parakeet TDT 0.6B v3")
                    .font(.headline)
                
                Text("Suporte: 25 idiomas europeus incluindo português")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private var monitoredAppsList: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(MeetingApp.allCases, id: \.self) { app in
                HStack {
                    Image(systemName: app.icon)
                        .foregroundStyle(app.color)
                    Text(app.displayName)
                }
            }
        }
        .font(.caption)
    }
    
    // MARK: - Actions
    
    private func selectRecordingsDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            recordingsPath = url.path
        }
    }
    
    private func testConnection() {
        // TODO: Implement connection test
    }
}

// MARK: - Shortcut Settings Tab

/// Tab for configuring global keyboard shortcuts.
struct ShortcutSettingsTab: View {
    @ObservedObject private var settings = AppSettingsStore.shared
    @ObservedObject private var shortcutManager = GlobalShortcutManager.shared
    
    var body: some View {
        Form {
            Section("Atalho Global para Gravação") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Pressione este atalho em qualquer lugar do sistema para iniciar ou parar a gravação.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        shortcutDisplay
                        
                        Spacer()
                        
                        recordButton
                    }
                    
                    if shortcutManager.isRegistered {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Atalho registrado e ativo")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            Section("Instruções") {
                VStack(alignment: .leading, spacing: 8) {
                    instructionRow(
                        icon: "1.circle.fill",
                        text: "Clique em \"Gravar Atalho\" para definir um novo atalho"
                    )
                    instructionRow(
                        icon: "2.circle.fill",
                        text: "Pressione a combinação de teclas desejada"
                    )
                    instructionRow(
                        icon: "3.circle.fill",
                        text: "O atalho deve incluir pelo menos uma tecla modificadora (⌘, ⌥, ⌃, ⇧)"
                    )
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            
            Section {
                Button("Restaurar Padrão (⌘⇧R)") {
                    settings.keyboardShortcut = .default
                }
                .buttonStyle(.link)
            }
        }
    }
    
    @ViewBuilder
    private var shortcutDisplay: some View {
        HStack {
            if shortcutManager.isRecordingShortcut {
                Text("Pressione as teclas...")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.orange, lineWidth: 2)
                    )
            } else {
                Text(settings.keyboardShortcut.displayString)
                    .font(.system(.title2, design: .monospaced))
                    .fontWeight(.medium)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                    )
            }
        }
    }
    
    @ViewBuilder
    private var recordButton: some View {
        if shortcutManager.isRecordingShortcut {
            Button("Cancelar") {
                shortcutManager.stopRecordingShortcut()
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        } else {
            Button("Gravar Atalho") {
                shortcutManager.onShortcutCaptured = { newShortcut in
                    settings.keyboardShortcut = newShortcut
                }
                shortcutManager.startRecordingShortcut()
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    @ViewBuilder
    private func instructionRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
            Text(text)
        }
    }
}

// MARK: - AI Settings Tab

/// Tab for configuring AI post-processing settings.
struct AISettingsTab: View {
    @ObservedObject private var settings = AppSettingsStore.shared
    @State private var showAPIKey = false
    @State private var connectionStatus: ConnectionStatus = .unknown
    
    enum ConnectionStatus {
        case unknown, testing, success, failure
        
        var color: Color {
            switch self {
            case .unknown: return .secondary
            case .testing: return .orange
            case .success: return .green
            case .failure: return .red
            }
        }
        
        var text: String {
            switch self {
            case .unknown: return "Não testado"
            case .testing: return "Testando..."
            case .success: return "Conectado"
            case .failure: return "Falha na conexão"
            }
        }
    }
    
    var body: some View {
        Form {
            Section("Pós-Processamento com IA") {
                Toggle("Habilitar processamento de transcrições com IA", isOn: $settings.aiEnabled)
                
                Text("Quando habilitado, as transcrições serão enviadas para um modelo de IA para correção, formatação e resumo.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if settings.aiEnabled {
                Section("Provedor") {
                    Picker("Provedor de IA:", selection: $settings.aiConfiguration.provider) {
                        ForEach(AIProvider.allCases, id: \.self) { provider in
                            HStack {
                                Image(systemName: provider.icon)
                                Text(provider.displayName)
                            }
                            .tag(provider)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: settings.aiConfiguration.provider) { newProvider in
                        // Update base URL when provider changes
                        if newProvider != .custom {
                            settings.aiConfiguration.baseURL = newProvider.defaultBaseURL
                        }
                        connectionStatus = .unknown
                    }
                }
                
                Section("Configuração da API") {
                    HStack {
                        Text("URL Base:")
                        TextField(
                            settings.aiConfiguration.provider.defaultBaseURL,
                            text: $settings.aiConfiguration.baseURL
                        )
                        .textFieldStyle(.roundedBorder)
                        .disabled(settings.aiConfiguration.provider != .custom)
                    }
                    
                    HStack {
                        Text("Chave API:")
                        Group {
                            if showAPIKey {
                                TextField("sk-...", text: $settings.aiConfiguration.apiKey)
                            } else {
                                SecureField("sk-...", text: $settings.aiConfiguration.apiKey)
                            }
                        }
                        .textFieldStyle(.roundedBorder)
                        
                        Button {
                            showAPIKey.toggle()
                        } label: {
                            Image(systemName: showAPIKey ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.borderless)
                        .help(showAPIKey ? "Ocultar chave" : "Mostrar chave")
                    }
                    
                    HStack {
                        Text("Modelo:")
                        TextField("gpt-4o, claude-3-5-sonnet...", text: $settings.aiConfiguration.selectedModel)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    Text("O modelo será selecionável automaticamente em uma versão futura.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Section {
                    HStack {
                        Button("Testar Conexão") {
                            testAPIConnection()
                        }
                        .disabled(!settings.aiConfiguration.isValid || connectionStatus == .testing)
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            if connectionStatus == .testing {
                                ProgressView()
                                    .scaleEffect(0.6)
                            }
                            Circle()
                                .fill(connectionStatus.color)
                                .frame(width: 8, height: 8)
                            Text(connectionStatus.text)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
    
    private func testAPIConnection() {
        connectionStatus = .testing
        
        // TODO: Implement actual API connection test
        Task {
            // Simulate network delay
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            
            // For now, just check if we have valid configuration
            await MainActor.run {
                connectionStatus = settings.aiConfiguration.isValid ? .success : .failure
            }
        }
    }
}

#Preview {
    SettingsView()
}
