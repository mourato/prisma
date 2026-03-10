import AppKit
@testable import MeetingAssistantCoreUI
import XCTest

final class MeetingNotesMarkdownFormatterTests: XCTestCase {
    func testAttributedStringForEditing_RoundTripsHeadingListAndLink() {
        let formatter = MeetingNotesMarkdownFormatter()
        let markdown = """
        # Project Update

        - First item
        - Second item

        [OpenAI](https://openai.com)
        """

        let attributed = formatter.attributedStringForEditing(from: markdown)
        let roundTripped = formatter.markdownForPersistence(from: attributed)
        let fullRange = NSRange(location: 0, length: attributed.length)
        var hasLink = false
        attributed.enumerateAttribute(.link, in: fullRange, options: []) { value, _, stop in
            if value != nil {
                hasLink = true
                stop.pointee = true
            }
        }

        XCTAssertTrue(hasLink)
        XCTAssertTrue(roundTripped.contains("Project Update"))
        XCTAssertTrue(roundTripped.contains("First item"))
        XCTAssertTrue(roundTripped.contains("OpenAI"))
    }

    func testAttributedStringForEditing_FallsBackToPlainTextWhenParserFails() {
        enum ParserError: Error {
            case forcedFailure
        }

        let formatter = MeetingNotesMarkdownFormatter(
            parser: { _, _ in
                throw ParserError.forcedFailure
            }
        )
        let markdown = "# Keep this as plain text"

        let attributed = formatter.attributedStringForEditing(from: markdown)

        XCTAssertEqual(attributed.string, markdown)
    }
}
