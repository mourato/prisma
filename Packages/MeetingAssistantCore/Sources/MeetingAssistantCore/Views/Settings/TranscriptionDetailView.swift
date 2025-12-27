import SwiftUI

/// Detail view for a selected transcription.
public struct TranscriptionDetailView: View {
    let transcription: Transcription

    public init(transcription: Transcription) {
        self.transcription = transcription
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                self.headerSection
                Divider()
                self.transcriptSection
                if self.transcription.isPostProcessed {
                    Divider()
                    self.originalTranscriptSection
                }
            }
            .padding()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(self.transcription.formattedDate)
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Menu {
                    Button("common.delete".localized, role: .destructive) {
                        // TODO: Implement delete
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
                .menuStyle(.borderlessButton)
            }

            HStack(spacing: 8) {
                self.statusBadge(text: "transcription.completed".localized, color: .green, icon: "checkmark.circle.fill")
                self.statusBadge(text: self.transcription.meeting.appName, color: .blue, icon: "mic.fill")
                if self.transcription.isPostProcessed {
                    self.statusBadge(
                        text: self.transcription.postProcessingPromptTitle ?? "transcription.processed".localized,
                        color: .orange,
                        icon: "sparkles"
                    )
                }
            }

            Text("transcription.recorded_on".localized(with: self.transcription.formattedDate))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func statusBadge(text: String, color: Color, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15), in: Capsule())
        .foregroundStyle(color)
    }

    // MARK: - Transcript Section

    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("transcription.title".localized)
                    .font(.headline)

                Spacer()

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(self.transcription.text, forType: .string)
                } label: {
                    Label("common.copy".localized, systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
            }

            Text(self.transcription.text)
                .font(.body)
                .textSelection(.enabled)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.background, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Original Transcript Section

    private var originalTranscriptSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("transcription.original_title".localized)
                    .font(.headline)

                Spacer()

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(self.transcription.rawText, forType: .string)
                } label: {
                    Label("common.copy".localized, systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
            }

            Text(self.transcription.rawText)
                .font(.body)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}
