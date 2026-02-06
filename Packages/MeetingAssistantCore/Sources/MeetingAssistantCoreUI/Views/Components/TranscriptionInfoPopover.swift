import Foundation
import SwiftUI
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

/// Popover view displaying detailed metadata about a transcription.
struct TranscriptionInfoPopover: View {
    let transcription: Transcription

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("transcription.info.title".localized)
                .font(.headline)
                .padding(.bottom, 4)

            // Recording Section
            VStack(alignment: .leading, spacing: 8) {
                Text("transcription.info.recording".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                InfoRow(
                    icon: "mic.fill",
                    label: transcription.inputSource ?? "transcription.info.unknown_input".localized,
                    value: formatDuration(transcription.meeting.duration)
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("transcription.info.transcription".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                InfoRow(
                    icon: "waveform",
                    label: transcription.modelName,
                    value: formatDuration(transcription.transcriptionDuration)
                )
            }

            Divider()

            // Post-Processing Section (if available)
            if let processedModel = transcription.postProcessingModel {
                VStack(alignment: .leading, spacing: 8) {
                    Text("transcription.info.post_processing".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    InfoRow(icon: "sparkles", label: processedModel, value: formatDuration(transcription.postProcessingDuration))
                }
            } else {
                Text("transcription.info.no_post_processing".localized)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .frame(width: 300)
    }

    private func formatDuration(_ duration: Double) -> String {
        if duration <= 0 { return "-" }
        if duration < 60 {
            return String(format: "%.1fs", duration)
        }

        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = duration >= 3_600 ? [.hour, .minute, .second] : [.minute, .second]
        formatter.zeroFormattingBehavior = .pad

        return formatter.string(from: duration) ?? String(format: "%.0fs", duration)
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
