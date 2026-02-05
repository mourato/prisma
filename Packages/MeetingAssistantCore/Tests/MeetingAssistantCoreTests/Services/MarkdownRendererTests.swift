import XCTest
@testable import MeetingAssistantCore

final class MarkdownRendererTests: XCTestCase {

    func testRenderWithSegments() {
        let meeting = Meeting(
            app: .googleMeet,
            type: .standup,
            startTime: Date(timeIntervalSince1970: 1_698_372_000) // 2023-10-27 10:00:00 UTC
        )

        // Mock segments
        let segments = [
            Transcription.Segment(speaker: "Alice", text: "Hello team.", startTime: 0, endTime: 5),
            Transcription.Segment(speaker: "Bob", text: "Hi Alice.", startTime: 6, endTime: 10),
        ]

        let transcription = Transcription(
            meeting: meeting,
            segments: segments,
            text: "Hello team. Hi Alice.",
            rawText: "Hello team. Hi Alice.",
            processedContent: "Alice and Bob greeted each other."
        )

        let renderer = MarkdownRenderer()
        let output = renderer.render(meeting: meeting, transcription: transcription)

        // Assertions
        XCTAssertTrue(output.contains("# Meeting using Google Meet"))
        XCTAssertTrue(output.contains("- **Type**: Standup"))
        XCTAssertTrue(output.contains("## AI Summary"))
        XCTAssertTrue(output.contains("Alice and Bob greeted each other."))
        XCTAssertTrue(output.contains("**Alice** (00:00):"))
        XCTAssertTrue(output.contains("Hello team."))
        XCTAssertTrue(output.contains("**Bob** (00:06):"))
        XCTAssertTrue(output.contains("Hi Alice."))
    }

    func testRenderWithoutSegments() {
        let meeting = Meeting(app: .slack, type: .general)
        let transcription = Transcription(
            meeting: meeting,
            text: "Raw text only.",
            rawText: "Raw text only."
        )

        let renderer = MarkdownRenderer()
        let output = renderer.render(meeting: meeting, transcription: transcription)

        XCTAssertTrue(output.contains("Raw text only."))
        XCTAssertFalse(output.contains("**Speaker**"))
    }
}

final class ExportServiceTests: XCTestCase {

    func testSuggestedFilename() {
        let date = Date(timeIntervalSince1970: 1_698_372_000) // 2023-10-27
        let meeting = Meeting(app: .zoom, type: .designReview, startTime: date)

        let service = ExportService()
        let filename = service.suggestedFilename(for: meeting)

        XCTAssertTrue(filename.contains("DesignReview.md"))
        // Check for localized prefix (defaulting to English in tests usually or checking suffix)
        // We know the English key is "Meeting"
        XCTAssertTrue(filename.hasSuffix(".md"))
    }
}
