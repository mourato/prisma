import SwiftUI

/// List view displaying all transcriptions.
struct TranscriptionListView: View {
    @State private var transcriptions: [Transcription] = []
    @State private var selectedTranscription: Transcription?

    var body: some View {
        Group {
            if self.transcriptions.isEmpty {
                self.emptyState
            } else {
                self.transcriptionList
            }
        }
        .onAppear {
            self.loadTranscriptions()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)

            Text(NSLocalizedString("settings.transcriptions.empty_title", bundle: .safeModule, comment: ""))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var transcriptionList: some View {
        List(self.transcriptions, selection: self.$selectedTranscription) { transcription in
            TranscriptionRow(transcription: transcription)
                .tag(transcription)
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
