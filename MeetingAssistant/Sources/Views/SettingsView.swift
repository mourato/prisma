import SwiftUI

/// Settings view for app configuration.
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
            
            serviceSettings
                .tabItem {
                    Label("Serviço", systemImage: "server.rack")
                }
        }
        .padding()
        .frame(width: 450, height: 300)
    }
    
    // MARK: - Tabs
    
    @ViewBuilder
    private var generalSettings: some View {
        Form {
            Section("Gravação") {
                Toggle("Iniciar gravação automaticamente", isOn: $autoStartRecording)
                
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

#Preview {
    SettingsView()
}
