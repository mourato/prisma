import SwiftUI

/// Menu bar popover view displaying recording status and controls.
public struct MenuBarView: View {
    @StateObject private var viewModel = RecordingViewModel()
    @State private var showingTranscriptions = false
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 16) {
            headerSection
            
            // Always show permission status for visibility
            permissionStatusSection
            
            statusSection
            
            // Transcription service status indicator
            TranscriptionStatusView(viewModel: viewModel.transcriptionViewModel)
            
            controlButtons
            transcriptionsList
        }
        .padding()
        .frame(width: 300)
        .task {
            await viewModel.checkPermission()
        }
    }
    
    // MARK: - Permission Status Section
    
    private var permissionStatusSection: some View {
            PermissionStatusView(
                viewModel: viewModel.permissionViewModel
            )
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
            
            SettingsLink {
                Image(systemName: "gear")
            }
            .buttonStyle(.plain)
        }
    }
    
    private var statusSection: some View {
        VStack(spacing: 8) {
            HStack {
                Circle()
                    .fill(viewModel.isRecording ? .red : .gray)
                    .frame(width: 10, height: 10)
                
                Text(viewModel.statusText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Spacer()
            }
            
            if viewModel.isRecording, let meeting = viewModel.currentMeeting {
                MeetingCard(meeting: meeting)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
    
    private var controlButtons: some View {
        HStack(spacing: 12) {
            if viewModel.isRecording {
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
    
    // MARK: - Actions
    
    private func startRecording() {
        Task {
            await viewModel.startRecording()
        }
    }
    
    private func stopRecording() {
        Task {
            await viewModel.stopRecording()
        }
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
}
