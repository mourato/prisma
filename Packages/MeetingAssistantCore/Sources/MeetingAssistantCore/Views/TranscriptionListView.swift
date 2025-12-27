import SwiftUI

/// List view displaying all transcriptions.
struct TranscriptionListView: View {
    @State private var transcriptions: [Transcription] = []
    @State private var selectedTranscription: Transcription?

    var body: some View {
        Group {
            if self.transcriptions.isEmpty {
                ContentUnavailableView(
                    "settings.transcriptions.empty_title".localized,
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("settings.transcriptions.empty_desc".localized)
                )
            } else {
                self.transcriptionList
            }
        }
        .onAppear {
            self.loadTranscriptions()
        }
    }

    // The emptyState property is removed as its functionality is replaced by ContentUnavailableView directly in body.

    private var transcriptionList: some View {
        List(self.transcriptions, selection: self.$selectedTranscription) { transcription in
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
        self.transcriptions = []
    }
}

/// Row view for a single transcription item.
struct TranscriptionRow: View {
    let transcription: Transcription

    var body: some View {
        HStack {
            Image(systemName: self.transcription.meeting.appIcon)
                .foregroundStyle(self.transcription.meeting.appColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(self.transcription.meeting.appName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(self.transcription.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(self.transcription.formattedDuration)
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
