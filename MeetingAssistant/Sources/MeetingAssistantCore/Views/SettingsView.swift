import SwiftUI
import os.log

// MARK: - Layout Constants

private enum LayoutConstants {
    static let windowWidth: CGFloat = 700
    static let windowHeight: CGFloat = 500
    static let sidebarMinWidth: CGFloat = 180
    static let sidebarIdealWidth: CGFloat = 200
    static let sidebarMaxWidth: CGFloat = 220
}

// MARK: - Connection Status

/// Unified connection status for service health checks.
enum ConnectionStatus: Equatable {
    case unknown
    case testing
    case success
    case failure(String?)
    
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
        case .failure(let message): return message ?? "Falha"
        }
    }
    
    static func == (lhs: ConnectionStatus, rhs: ConnectionStatus) -> Bool {
        switch (lhs, rhs) {
        case (.unknown, .unknown), (.testing, .testing), (.success, .success):
            return true
        case (.failure, .failure):
            return true
        default:
            return false
        }
    }
}

// MARK: - Settings Section Enum

enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case shortcuts
    case ai
    case service
    case permissions
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .general: return "Geral"
        case .shortcuts: return "Atalhos"
        case .ai: return "IA"
        case .service: return "Serviço"
        case .permissions: return "Permissões"
        }
    }
    
    var icon: String {
        switch self {
        case .general: return "gear"
        case .shortcuts: return "command"
        case .ai: return "brain"
        case .service: return "server.rack"
        case .permissions: return "lock.shield"
        }
    }
}

// MARK: - Settings View

/// Settings view for app configuration.
/// Uses sidebar navigation pattern similar to macOS System Settings.
public struct SettingsView: View {
    @AppStorage("autoStartRecording") private var autoStartRecording = true
    @AppStorage("recordingsDirectory") private var recordingsPath = ""
    
    @State private var selectedSection: SettingsSection = .general
    @State private var transcriptionStatus: ConnectionStatus = .unknown
    
    public init() {}
    
    public var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailView
        }
        .frame(width: LayoutConstants.windowWidth, height: LayoutConstants.windowHeight)
    }
    
    // MARK: - Sidebar
    
    private var sidebar: some View {
        List(selection: $selectedSection) {
            ForEach(SettingsSection.allCases) { section in
                Label(section.title, systemImage: section.icon)
                    .tag(section)
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(
            min: LayoutConstants.sidebarMinWidth,
            ideal: LayoutConstants.sidebarIdealWidth,
            max: LayoutConstants.sidebarMaxWidth
        )
    }
    
    // MARK: - Detail View
    
    @ViewBuilder
    private var detailView: some View {
        switch selectedSection {
        case .general:
            generalSettings
        case .shortcuts:
            ShortcutSettingsTab()
        case .ai:
            AISettingsTab()
        case .service:
            serviceSettings
        case .permissions:
            permissionsSettings
        }
    }
    
    // MARK: - General Settings
    
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
        .padding()
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
    
    // MARK: - Service Settings
    
    @ViewBuilder
    private var serviceSettings: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: "cpu")
                            .font(.title2)
                            .foregroundStyle(.blue)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Processamento Local")
                            .font(.headline)
                        Text("Apple Neural Engine (ANE)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    statusBadge
                }
                .padding(.vertical, 4)
            } header: {
                Label("Modelo Local", systemImage: "waveform")
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Modelo:")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Parakeet TDT 0.6B v3")
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Idiomas:")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("25 europeus (incl. PT)")
                            .fontWeight(.medium)
                    }
                }
                .font(.subheadline)
                
                HStack {
                    Button(action: testConnection) {
                        Label("Verificar Status", systemImage: "arrow.clockwise")
                    }
                    .disabled(transcriptionStatus == .testing)
                    
                    Spacer()
                    
                    if transcriptionStatus == .testing {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
            } header: {
                Label("Modelo de Transcrição", systemImage: "text.bubble")
            }
        }
        .padding()
    }
    
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(transcriptionStatus.color)
                .frame(width: 8, height: 8)
            Text(transcriptionStatus.text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(transcriptionStatus.color.opacity(0.1))
        )
    }
    
    // MARK: - Permissions Settings
    
    @ViewBuilder
    private var permissionsSettings: some View {
        Form {
            Section {
                Text("O Meeting Assistant precisa de acesso ao microfone e à gravação de tela para capturar o áudio das suas reuniões.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } header: {
                Label("Sobre Permissões", systemImage: "info.circle")
            }
            
            Section {
                PermissionStatusView(
                    permissionManager: RecordingManager.shared.permissionStatus,
                    onRequestMicrophone: {
                        Task { await RecordingManager.shared.requestPermission() }
                    },
                    onRequestScreenRecording: {
                        Task { await RecordingManager.shared.requestPermission() }
                    },
                    onOpenMicrophoneSettings: {
                        RecordingManager.shared.openMicrophoneSettings()
                    },
                    onOpenScreenRecordingSettings: {
                        RecordingManager.shared.openPermissionSettings()
                    }
                )
            } header: {
                Label("Status das Permissões", systemImage: "checkmark.shield")
            }
        }
        .padding()
        .task {
            await RecordingManager.shared.checkPermission()
        }
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
        transcriptionStatus = .testing
        
        Task {
            do {
                let isHealthy = try await TranscriptionClient.shared.healthCheck()
                await MainActor.run {
                    transcriptionStatus = isHealthy ? .success : .failure(nil)
                }
            } catch {
                await MainActor.run {
                    transcriptionStatus = .failure(error.localizedDescription)
                }
            }
        }
    }
}



// MARK: - Shortcut Settings Tab

/// Section for configuring global keyboard shortcuts.
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
        .padding()
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

/// Section for configuring AI post-processing settings.
struct AISettingsTab: View {
    @ObservedObject private var settings = AppSettingsStore.shared
    @State private var showAPIKey = false
    @State private var apiKeyText = ""
    @State private var connectionStatus: ConnectionStatus = .unknown
    
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
                    .onChange(of: settings.aiConfiguration.provider) { _, newProvider in
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
                    }
                    
                    HStack {
                        Text("Chave API:")
                        Group {
                            if showAPIKey {
                                TextField("sk-...", text: $apiKeyText)
                            } else {
                                SecureField("sk-...", text: $apiKeyText)
                            }
                        }
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: apiKeyText) { _, newValue in
                            saveAPIKeyToKeychain(newValue)
                        }
                        
                        Button {
                            showAPIKey.toggle()
                        } label: {
                            Image(systemName: showAPIKey ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.borderless)
                        .help(showAPIKey ? "Ocultar chave" : "Mostrar chave")
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
        .padding()
        .onAppear {
            apiKeyText = (try? KeychainManager.retrieve(for: .aiAPIKey)) ?? ""
        }
    }
    
    private let logger = Logger(subsystem: "MeetingAssistant", category: "AISettings")
    
    /// Saves API key to Keychain with proper error handling.
    private func saveAPIKeyToKeychain(_ value: String) {
        do {
            if !value.isEmpty {
                try KeychainManager.store(value, for: .aiAPIKey)
            } else {
                try KeychainManager.delete(for: .aiAPIKey)
            }
        } catch {
            logger.error("Failed to save API key to Keychain: \(error.localizedDescription)")
            // NOTE: In a future iteration, show user feedback via an alert
        }
    }
    
    private func testAPIConnection() {
        connectionStatus = .testing
        
        let urlString = settings.aiConfiguration.baseURL
        
        // Validate URL format and scheme
        guard let url = URL(string: urlString),
              let scheme = url.scheme,
              ["http", "https"].contains(scheme.lowercased()) else {
            connectionStatus = .failure("URL inválida")
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
                            connectionStatus = .success
                        } else {
                            connectionStatus = .failure("HTTP \(httpResponse.statusCode)")
                        }
                    } else {
                        connectionStatus = .failure("Resposta inválida")
                    }
                }
            } catch {
                await MainActor.run {
                    connectionStatus = .failure(error.localizedDescription)
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
