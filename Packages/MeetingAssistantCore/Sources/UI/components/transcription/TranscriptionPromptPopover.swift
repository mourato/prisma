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

            let promptInput = constructPromptInput()
            let diagnosticsLines = postProcessingDiagnosticsLines()

            ScrollView {
                Text(promptInput)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity) // Increased area

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("transcription.prompt.section.post_processing_diagnostics".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(Array(diagnosticsLines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding()
        .frame(width: 500, height: 600) // Increased popover size
    }

    private func constructPromptInput() -> String {
        let requestSystemPrompt = transcription.postProcessingRequestSystemPrompt?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let requestUserPrompt = transcription.postProcessingRequestUserPrompt?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        var lines: [String] = []

        lines.append(contentsOf: systemContextLines())
        lines.append(contentsOf: userInformationLines())
        lines.append(contentsOf: applicationContextLines())
        lines.append(contentsOf: systemPromptLines(requestSystemPrompt))
        lines.append(contentsOf: userPromptLines(requestUserPrompt))
        lines.append(contentsOf: outputLanguageLines(requestUserPrompt))
        lines.append(contentsOf: rawTranscriptionLines())

        return lines.joined(separator: "\n")
    }

    private func systemContextLines() -> [String] {
        [
            "transcription.prompt.section.system_context".localized,
            "\("transcription.prompt.current_time".localized): \(Date().formatted())",
            "\("transcription.prompt.time_zone".localized): \(TimeZone.current.identifier)",
            "\("transcription.prompt.locale".localized): \(Locale.current.identifier)",
            "\("transcription.prompt.computer_name".localized): \(Host.current().localizedName ?? "transcription.prompt.unknown".localized)",
            "",
        ]
    }

    private func userInformationLines() -> [String] {
        [
            "transcription.prompt.section.user_information".localized,
            "\("transcription.prompt.user_full_name".localized): \(NSFullUserName())",
            "",
        ]
    }

    private func applicationContextLines() -> [String] {
        [
            "transcription.prompt.section.application_context".localized,
            "\("transcription.prompt.current_app".localized): \(transcription.meeting.app.rawValue)",
            "\("transcription.prompt.captured_bundle_identifier".localized): \(transcription.meeting.appBundleIdentifier ?? "transcription.prompt.unset".localized)",
            "",
        ]
    }

    private func systemPromptLines(_ requestSystemPrompt: String?) -> [String] {
        var lines = ["transcription.prompt.section.system_prompt".localized]
        if let systemPrompt = requestSystemPrompt, !systemPrompt.isEmpty {
            lines.append(systemPrompt)
        } else {
            lines.append("transcription.prompt.not_available".localized)
        }
        return lines
    }

    private func userPromptLines(_ requestUserPrompt: String?) -> [String] {
        var lines = ["", "transcription.prompt.section.user_message".localized]

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
            lines.append("")
            lines.append("transcription.prompt.section.context_sent".localized)
            lines.append(
                resolvedContextSent(from: requestUserPrompt) ?? "transcription.prompt.not_available".localized
            )
            lines.append("")
            lines.append("transcription.prompt.section.extracted_transcription".localized)
            lines.append(
                extractTaggedBlock(named: "TRANSCRIPTION", from: userPrompt)
                    ?? "transcription.prompt.not_available".localized
            )
            return lines
        }

        lines.append("transcription.prompt.not_available".localized)
        lines.append("")
        lines.append("transcription.prompt.section.context_sent".localized)
        lines.append(
            resolvedContextSent(from: requestUserPrompt) ?? "transcription.prompt.not_available".localized
        )
        lines.append("")
        lines.append("transcription.prompt.section.extracted_transcription".localized)
        lines.append("transcription.prompt.not_available".localized)
        return lines
    }

    private func outputLanguageLines(_ requestUserPrompt: String?) -> [String] {
        [
            "",
            "transcription.prompt.section.output_language".localized,
            resolvedOutputLanguage(from: requestUserPrompt) ?? "transcription.prompt.not_available".localized,
        ]
    }

    private func rawTranscriptionLines() -> [String] {
        [
            "",
            "transcription.prompt.section.raw_transcription".localized,
            transcription.rawText,
        ]
    }

    private func postProcessingDiagnosticsLines() -> [String] {
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

        return [
            "\("transcription.prompt.global_post_processing_enabled".localized): \(globalStatus)",
            "\("transcription.prompt.dictation_selected_prompt_id".localized): \(settings.dictationSelectedPromptId?.uuidString ?? "transcription.prompt.unset".localized)",
            "\("transcription.prompt.meeting_selected_prompt_id".localized): \(settings.selectedPromptId?.uuidString ?? "transcription.prompt.unset".localized)",
            "\("transcription.prompt.used_prompt_id".localized): \(transcription.postProcessingPromptId?.uuidString ?? "transcription.prompt.unset".localized)",
            "\("transcription.prompt.used_prompt_title".localized): \(transcription.postProcessingPromptTitle ?? "transcription.prompt.unset".localized)",
            "\("transcription.prompt.post_processing_applied".localized): \(processingStatus)",
            "\("transcription.prompt.post_processing_model".localized): \(transcription.postProcessingModel ?? "transcription.prompt.unset".localized)",
            "\("transcription.prompt.post_processing_duration".localized): \(String(format: "%.2fs", transcription.postProcessingDuration))",
        ]
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

    private func resolvedContextSent(from requestUserPrompt: String?) -> String? {
        if let requestUserPrompt,
           let contextMetadataBlock = extractTaggedBlock(named: "CONTEXT_METADATA", from: requestUserPrompt)
        {
            return contextMetadataBlock
        }

        return fallbackContextSentFromItems()
    }

    private func fallbackContextSentFromItems() -> String? {
        let sourceRank: [TranscriptionContextItem.Source: Int] = [
            .activeApp: 0,
            .windowTitle: 1,
            .accessibilityText: 2,
            .clipboard: 3,
            .windowOCR: 4,
            .activeTabURL: 5,
            .calendarEvent: 6,
            .focusedText: 7,
            .meetingNotes: 8,
        ]

        let orderedLines = transcription.contextItems
            .enumerated()
            .sorted { lhs, rhs in
                let lhsRank = sourceRank[lhs.element.source] ?? Int.max
                let rhsRank = sourceRank[rhs.element.source] ?? Int.max
                if lhsRank == rhsRank {
                    return lhs.offset < rhs.offset
                }
                return lhsRank < rhsRank
            }
            .map(\.element)
            .compactMap { item -> String? in
                let trimmed = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                return "- \(contextSourceLabel(for: item.source)): \(trimmed)"
            }

        guard !orderedLines.isEmpty else { return nil }
        return orderedLines.joined(separator: "\n")
    }

    private func contextSourceLabel(for source: TranscriptionContextItem.Source) -> String {
        switch source {
        case .activeApp:
            return "Active app"
        case .activeTabURL:
            return "Active tab URL"
        case .windowTitle:
            return "Active window title"
        case .accessibilityText:
            return "Focused UI text (Accessibility)"
        case .clipboard:
            return "Clipboard text"
        case .windowOCR:
            return "Active window visible text (OCR)"
        case .focusedText:
            return "Focused text"
        case .calendarEvent:
            return "Calendar event"
        case .meetingNotes:
            return "Meeting notes"
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
