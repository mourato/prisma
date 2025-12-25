import SwiftUI

/// Menu bar popover view displaying recording status and controls.
struct MenuBarView: View {
    @EnvironmentObject var recordingManager: RecordingManager
    @State private var showingTranscriptions = false
    
    var body: some View {
        VStack(spacing: 16) {
            headerSection
            
            if !recordingManager.hasScreenCapturePermission {
                permissionWarningSection
            }
            
            statusSection
            controlButtons
            transcriptionsList
        }
        .padding()
        .frame(width: 300)
        .task {
            await recordingManager.checkPermission()
        }
    }
    
    // MARK: - Permission Warning
    
    private var permissionWarningSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                Text("Permissão Necessária")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            Text("O app precisa de permissão de Gravação de Tela para capturar áudio das reuniões.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: openPermissionSettings) {
                Label("Abrir Configurações", systemImage: "gear")
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        HStack {
            Image(systemName: "waveform.circle.fill")
                .font(.title)
                .foregroundStyle(.blue)
            
            Text("Meeting Assistant")
                .font(.headline)
            
            Spacer()
            
            Button(action: openSettings) {
                Image(systemName: "gear")
            }
            .buttonStyle(.plain)
        }
    }
    
    private var statusSection: some View {
        VStack(spacing: 8) {
            HStack {
                Circle()
                    .fill(recordingManager.isRecording ? .red : .gray)
                    .frame(width: 10, height: 10)
                
                Text(statusText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Spacer()
            }
            
            if recordingManager.isRecording, let meeting = recordingManager.currentMeeting {
                MeetingCard(meeting: meeting)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
    
    private var controlButtons: some View {
        HStack(spacing: 12) {
            if recordingManager.isRecording {
                Button(action: stopRecording) {
                    Label("Parar Gravação", systemImage: "stop.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            } else {
                Button(action: startRecording) {
                    Label("Iniciar Gravação", systemImage: "record.circle")
                }
                .buttonStyle(.borderedProminent)
            }
            
            Button(action: { showingTranscriptions.toggle() }) {
                Label("Transcrições", systemImage: "doc.text")
            }
            .buttonStyle(.bordered)
        }
    }
    
    private var transcriptionsList: some View {
        Group {
            if showingTranscriptions {
                TranscriptionListView()
                    .frame(height: 200)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var statusText: String {
        if recordingManager.isRecording {
            return "Gravando..."
        } else if recordingManager.isTranscribing {
            return "Transcrevendo..."
        } else {
            return "Aguardando reunião"
        }
    }
    
    // MARK: - Actions
    
    private func startRecording() {
        Task {
            await recordingManager.startRecording()
        }
    }
    
    private func stopRecording() {
        Task {
            await recordingManager.stopRecording()
        }
    }
    
    private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
    
    private func openPermissionSettings() {
        recordingManager.openPermissionSettings()
    }
}

/// Card showing current meeting info.
struct MeetingCard: View {
    let meeting: Meeting
    
    var body: some View {
        HStack {
            Image(systemName: meeting.appIcon)
                .font(.title2)
                .foregroundStyle(meeting.appColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(meeting.appName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(meeting.formattedDuration)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(8)
        .background(.background, in: RoundedRectangle(cornerRadius: 6))
    }
}

#Preview {
    MenuBarView()
        .environmentObject(RecordingManager.shared)
}
