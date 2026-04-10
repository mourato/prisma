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
        lines.append("transcription.prompt.section.system_context".localized)
        lines.append("\("transcription.prompt.current_time".localized): \(Date().formatted())")
        lines.append("\("transcription.prompt.time_zone".localized): \(TimeZone.current.identifier)")
        lines.append("\("transcription.prompt.locale".localized): \(Locale.current.identifier)")
        lines.append(
            "\("transcription.prompt.computer_name".localized): \(Host.current().localizedName ?? "transcription.prompt.unknown".localized)"
        )
        lines.append("")

        // User Information
        lines.append("transcription.prompt.section.user_information".localized)
        lines.append("\("transcription.prompt.user_full_name".localized): \(NSFullUserName())")
        lines.append("")

        // Application Context
        lines.append("transcription.prompt.section.application_context".localized)
        lines.append("\("transcription.prompt.current_app".localized): \(transcription.meeting.app.rawValue)")
        lines.append(
            "\("transcription.prompt.captured_bundle_identifier".localized): \(transcription.meeting.appBundleIdentifier ?? "transcription.prompt.unset".localized)"
        )
        lines.append("")

        // System prompt sent to post-processing provider
        lines.append("transcription.prompt.section.system_prompt".localized)
        if let systemPrompt = transcription.postProcessingRequestSystemPrompt {
            lines.append(systemPrompt)
        } else {
            lines.append("transcription.prompt.not_available".localized)
        }

        // User Prompt
        lines.append("")
        lines.append("transcription.prompt.section.user_message".localized)
        if let userPrompt = transcription.postProcessingRequestUserPrompt {
            lines.append(userPrompt)

            lines.append("")
            lines.append("transcription.prompt.section.extracted_instructions".localized)
            lines.append(
                extractTaggedBlock(named: "INSTRUCTIONS", from: userPrompt)
                    ?? "transcription.prompt.not_available".localized
            )

            lines.append("")
            lines.append("transcription.prompt.section.extracted_site_app_priority".localized)
            lines.append(
                extractTaggedBlock(named: AIPromptTemplates.siteOrAppPriorityTag, from: userPrompt)
                    ?? "transcription.prompt.not_available".localized
            )
        } else {
            lines.append("transcription.prompt.not_available".localized)
        }

        // Raw transcription
        lines.append("")
        lines.append("transcription.prompt.section.raw_transcription".localized)
        lines.append(transcription.rawText)

        // Post-processing diagnostics
        let settings = AppSettingsStore.shared
        let hasProcessedContent = transcription.processedContent?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty == false
        let processingStatus = hasProcessedContent
            ? "transcription.prompt.value.applied".localized
            : "transcription.prompt.value.skipped".localized
        let globalStatus = settings.postProcessingEnabled
            ? "transcription.prompt.value.enabled".localized
            : "transcription.prompt.value.disabled".localized

        lines.append("")
        lines.append("transcription.prompt.section.post_processing_diagnostics".localized)
        lines.append("\("transcription.prompt.global_post_processing_enabled".localized): \(globalStatus)")
        lines.append(
            "\("transcription.prompt.dictation_selected_prompt_id".localized): \(settings.dictationSelectedPromptId?.uuidString ?? "transcription.prompt.unset".localized)"
        )
        lines.append(
            "\("transcription.prompt.meeting_selected_prompt_id".localized): \(settings.selectedPromptId?.uuidString ?? "transcription.prompt.unset".localized)"
        )
        lines.append(
            "\("transcription.prompt.used_prompt_id".localized): \(transcription.postProcessingPromptId?.uuidString ?? "transcription.prompt.unset".localized)"
        )
        lines.append(
            "\("transcription.prompt.used_prompt_title".localized): \(transcription.postProcessingPromptTitle ?? "transcription.prompt.unset".localized)"
        )
        lines.append("\("transcription.prompt.post_processing_applied".localized): \(processingStatus)")
        lines.append(
            "\("transcription.prompt.post_processing_model".localized): \(transcription.postProcessingModel ?? "transcription.prompt.unset".localized)"
        )
        lines.append(
            "\("transcription.prompt.post_processing_duration".localized): \(String(format: "%.2fs", transcription.postProcessingDuration))"
        )

        return lines.joined(separator: "\n")
    }

    private func extractTaggedBlock(named tag: String, from text: String) -> String? {
        let openTag = "<\(tag)>"
        let closeTag = "</\(tag)>"

        guard let startRange = text.range(of: openTag),
              let endRange = text.range(of: closeTag, range: startRange.upperBound..<text.endIndex),
              startRange.upperBound <= endRange.lowerBound
        else {
            return nil
        }

        let extracted = text[startRange.upperBound..<endRange.lowerBound]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return extracted.isEmpty ? nil : extracted
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
