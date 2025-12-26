import SwiftUI

// MARK: - General Settings Tab

/// Tab for general app settings like recording preferences and monitored apps.
public struct GeneralSettingsTab: View {
    @AppStorage("autoStartRecording") private var autoStartRecording = true
    @AppStorage("recordingsDirectory") private var recordingsPath = ""
    
    public init() {}
    
    public var body: some View {
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
    
    private func selectRecordingsDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            recordingsPath = url.path
        }
    }
}

#Preview {
    GeneralSettingsTab()
}
