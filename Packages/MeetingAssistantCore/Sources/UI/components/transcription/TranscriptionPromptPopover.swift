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
            Text("Request Prompt")
                .font(.headline)
                .padding(.bottom, 4)

            // Combine everything into one single input view
            let fullPrompt = constructFullPrompt()

            ScrollView {
                Text(fullPrompt)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity) // Increased area
        }
        .padding()
        .frame(width: 500, height: 600) // Increased popover size
    }

    private func constructFullPrompt() -> String {
        var lines: [String] = []
        
        // System Context
        lines.append("SYSTEM CONTEXT:")
        lines.append("Current time: \(Date().formatted())") // Placeholder for actual time if stored, otherwise use current
        lines.append("Time zone: \(TimeZone.current.identifier)")
        lines.append("Locale: \(Locale.current.identifier)")
        lines.append("Computer name: \(Host.current().localizedName ?? "Unknown")")
        lines.append("")

        // User Information
        lines.append("USER INFORMATION:")
        lines.append("User's full name: \(NSFullUserName())")
        lines.append("")

        // Application Context
        lines.append("APPLICATION CONTEXT:")
        lines.append("User is currently using: \(transcription.meeting.app.rawValue)") // Assuming app info is available via meeting
        lines.append("")

        // User Prompt
        if let userPrompt = transcription.postProcessingRequestUserPrompt {
            lines.append("USER MESSAGE:")
            lines.append(userPrompt)
        }

        return lines.joined(separator: "\n")
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
