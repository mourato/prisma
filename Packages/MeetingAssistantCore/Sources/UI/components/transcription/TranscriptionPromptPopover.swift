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
        let requestSystemPrompt = transcription.postProcessingRequestSystemPrompt?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let requestUserPrompt = transcription.postProcessingRequestUserPrompt?
            .trimmingCharacters(in: .whitespacesAndNewlines)

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
        if let systemPrompt = requestSystemPrompt, !systemPrompt.isEmpty {
            lines.append(systemPrompt)
        } else {
            lines.append("transcription.prompt.not_available".localized)
        }

        // User Prompt
        lines.append("")
        lines.append("transcription.prompt.section.user_message".localized)
        if let userPrompt = requestUserPrompt, !userPrompt.isEmpty {
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

        lines.append("")
        lines.append("transcription.prompt.section.output_language".localized)
        lines.append(
            resolvedOutputLanguage(from: requestUserPrompt) ?? "transcription.prompt.not_available".localized
        )

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

    private func resolvedOutputLanguage(from requestUserPrompt: String?) -> String? {
        if let requestUserPrompt,
           let outputLanguageBlock = extractTaggedBlock(named: "OUTPUT_LANGUAGE", from: requestUserPrompt)
        {
            return extractLanguageName(fromOutputLanguageInstruction: outputLanguageBlock) ?? outputLanguageBlock
        }

        return outputLanguageFromCurrentDictationRules()
    }

    private func outputLanguageFromCurrentDictationRules() -> String? {
        guard transcription.capturePurpose == .dictation,
              let bundleIdentifier = transcription.meeting.appBundleIdentifier
        else {
            return nil
        }

        let normalizedBundleIdentifier = WebTargetDetection.normalizeBundleIdentifier(bundleIdentifier)
        let prismaBundleIdentifier = WebTargetDetection.normalizeBundleIdentifier(AppIdentity.bundleIdentifier)
        guard normalizedBundleIdentifier != prismaBundleIdentifier else {
            return nil
        }

        let settings = AppSettingsStore.shared
        guard let rule = settings.dictationAppRules.first(where: {
            WebTargetDetection.normalizeBundleIdentifier($0.bundleIdentifier) == normalizedBundleIdentifier
        }) else {
            return nil
        }

        if rule.outputLanguage == .original {
            return "transcription.prompt.value.original_language".localized
        }

        return rule.outputLanguage.instructionDisplayName
    }

    private func extractLanguageName(fromOutputLanguageInstruction instruction: String) -> String? {
        let pattern = #"Translate the final output to\s+([^\.\n]+)"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let nsRange = NSRange(instruction.startIndex..<instruction.endIndex, in: instruction)
        guard let match = regex.firstMatch(in: instruction, options: [], range: nsRange),
              match.numberOfRanges > 1,
              let capturedRange = Range(match.range(at: 1), in: instruction)
        else {
            return nil
        }

        let languageName = instruction[capturedRange].trimmingCharacters(in: .whitespacesAndNewlines)
        return languageName.isEmpty ? nil : languageName
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
