import Foundation
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

struct TranscriptionPromptPopover: View {
    let transcription: Transcription

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("transcription.prompt.title".localized)
                .font(.headline)
                .padding(.bottom, 4)

            if let systemPrompt = transcription.postProcessingRequestSystemPrompt,
               !systemPrompt.isEmpty {
                promptSection(
                    title: "transcription.prompt.system".localized,
                    content: systemPrompt
                )
            }

            if let userPrompt = transcription.postProcessingRequestUserPrompt,
               !userPrompt.isEmpty {
                if transcription.postProcessingRequestSystemPrompt != nil {
                    Divider()
                }

                promptSection(
                    title: "transcription.prompt.user".localized,
                    content: userPrompt
                )
            }

            if transcription.postProcessingRequestSystemPrompt == nil
                && transcription.postProcessingRequestUserPrompt == nil {
                Text("transcription.prompt.not_available".localized)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 8)
                }
        }
        .padding()
        .frame(width: 400, height: 350)
    }

    private func promptSection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView {
                Text(content)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 120)
            .padding(8)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}

#Preview {
    TranscriptionPromptPopover(
        transcription: Transcription(
            meeting: Meeting(app: .zoom),
            text: "Preview text",
            rawText: "Raw text",
            postProcessingRequestSystemPrompt: "You are a helpful assistant specialized in processing transcriptions.",
            postProcessingRequestUserPrompt: """
            <TRANSCRIPTION>
            Hello everyone, today we will discuss the quarterly results.
            </TRANSCRIPTION>

            <INSTRUCTIONS>
            Process this transcription and create a summary.
            </INSTRUCTIONS>
            """,
            modelName: "Whisper-v3"
        )
    )
}
