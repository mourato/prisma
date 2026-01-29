import SwiftUI

/// Popover view displaying detailed metadata about a transcription.
struct TranscriptionInfoPopover: View {
    let transcription: Transcription

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recording Details")
                .font(.headline)
                .padding(.bottom, 4)

            // Recording Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Recording")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                InfoRow(icon: "mic.fill", label: transcription.inputSource ?? "Unknown Input", value: formatDuration(transcription.transcriptionDuration))
                InfoRow(icon: "waveform", label: transcription.modelName, value: formatDuration(transcription.transcriptionDuration))
            }

            Divider()

            // Post-Processing Section (if available)
            if let processedModel = transcription.postProcessingModel {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Post-Processing")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    InfoRow(icon: "sparkles", label: processedModel, value: formatDuration(transcription.postProcessingDuration))
                }
            } else {
                Text("No post-processing applied")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .frame(width: 300)
    }

    private func formatDuration(_ duration: Double) -> String {
        if duration == 0 { return "-" }
        return String(format: "%.1fs", duration)
    }
}

private struct InfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.primary)
                .frame(width: 20)

            Text(label)
                .font(.subheadline)

            Spacer()

            Text(value)
                .font(.subheadline) // Monospaced for numbers?
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    TranscriptionInfoPopover(
        transcription: Transcription(
            meeting: Meeting(app: .zoom),
            text: "Preview text",
            rawText: "Raw text",
            modelName: "Whisper-v3",
            inputSource: "MacBook Pro Mic",
            transcriptionDuration: 35.5,
            postProcessingDuration: 2.1,
            postProcessingModel: "GPT-4"
        )
    )
}
