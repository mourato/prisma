import SwiftUI

/// List view displaying all transcriptions.
struct TranscriptionListView: View {
    @State private var transcriptions: [Transcription] = []
    @State private var selectedTranscription: Transcription?

    var body: some View {
        Group {
            if transcriptions.isEmpty {
                ContentUnavailableView(
                    "settings.transcriptions.empty_title".localized,
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("settings.transcriptions.empty_desc".localized)
                )
            } else {
                transcriptionList
            }
        }
        .onAppear {
            loadTranscriptions()
        }
    }

    // The emptyState property is removed as its functionality is replaced by ContentUnavailableView directly in body.

    private var transcriptionList: some View {
        List(transcriptions, selection: $selectedTranscription) { transcription in
            TranscriptionRow(transcription: transcription)
                .tag(transcription)
                .contextMenu {
                    Button("common.delete".localized, role: .destructive) {
                        // TODO: Implement delete
                    }
                }
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
