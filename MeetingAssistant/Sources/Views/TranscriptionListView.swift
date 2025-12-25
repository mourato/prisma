import SwiftUI

/// List view displaying all transcriptions.
struct TranscriptionListView: View {
    @State private var transcriptions: [Transcription] = []
    @State private var selectedTranscription: Transcription?
    
    var body: some View {
        Group {
            if transcriptions.isEmpty {
                emptyState
            } else {
                transcriptionList
            }
        }
        .onAppear {
            loadTranscriptions()
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            
            Text("Nenhuma transcrição")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var transcriptionList: some View {
        List(transcriptions, selection: $selectedTranscription) { transcription in
            TranscriptionRow(transcription: transcription)
                .tag(transcription)
        }
        .listStyle(.plain)
    }
    
    private func loadTranscriptions() {
        // TODO: Load from storage
        transcriptions = []
    }
}

/// Row view for a single transcription item.
struct TranscriptionRow: View {
    let transcription: Transcription
    
    var body: some View {
        HStack {
            Image(systemName: transcription.meeting.appIcon)
                .foregroundStyle(transcription.meeting.appColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(transcription.meeting.appName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(transcription.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text(transcription.formattedDuration)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    TranscriptionListView()
        .frame(height: 200)
}
