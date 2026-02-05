import Foundation

/// Service responsible for rendering meeting data into Markdown format.
public struct MarkdownRenderer: Sendable {
    public init() {}

    /// Renders a meeting and its transcription into a Markdown string.
    /// - Parameters:
    ///   - meeting: The meeting entity.
    ///   - transcription: The associated transcription.
    /// - Returns: A formatted Markdown string.
    public func render(meeting: Meeting, transcription: Transcription) -> String {
        var markdown = ""

        // Header
        markdown += "# \(meetingTitle(for: meeting))\n\n"

        // Metadata
        let metadataHeader = NSLocalizedString("export.section.metadata", bundle: .safeModule, comment: "Metadata Section Header")
        markdown += "## \(metadataHeader)\n"

        let dateLabel = NSLocalizedString("export.label.date", bundle: .safeModule, comment: "Date Label")
        markdown += "- **\(dateLabel)**: \(formatDate(meeting.startTime))\n"

        let durationLabel = NSLocalizedString("export.label.duration", bundle: .safeModule, comment: "Duration Label")
        markdown += "- **\(durationLabel)**: \(meeting.formattedDuration)\n"

        let typeLabel = NSLocalizedString("export.label.type", bundle: .safeModule, comment: "Type Label")
        markdown += "- **\(typeLabel)**: \(meeting.type.displayName)\n"

        let appLabel = NSLocalizedString("export.label.app", bundle: .safeModule, comment: "App Label")
        markdown += "- **\(appLabel)**: \(meeting.app.displayName)\n\n"

        // AI Summary (if available)
        if let processedContent = transcription.processedContent, !processedContent.isEmpty {
            let summaryHeader = NSLocalizedString("export.section.ai_summary", bundle: .safeModule, comment: "AI Summary Section Header")
            markdown += "## \(summaryHeader)\n\n"
            markdown += processedContent + "\n\n"
        }

        // Transcription (Segments or Raw Text)
        let transcriptionHeader = NSLocalizedString("export.section.transcription", bundle: .safeModule, comment: "Transcription Section Header")
        markdown += "## \(transcriptionHeader)\n\n"

        if !transcription.segments.isEmpty {
            for segment in transcription.segments {
                let time = formatTime(segment.startTime)
                markdown += "**\(segment.speaker)** (\(time)):\n"
                markdown += "\(segment.text)\n\n"
            }
        } else {
            markdown += transcription.text
        }

        return markdown
    }

    // MARK: - Helpers

    private func meetingTitle(for meeting: Meeting) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        let formatString = NSLocalizedString("export.header.meeting_title", bundle: .safeModule, comment: "Meeting Title Format")
        return String(format: formatString, meeting.app.displayName, formatter.string(from: meeting.startTime))
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}
