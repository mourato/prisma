import XCTest
@testable import MeetingAssistantCore

final class PromptServiceTests: XCTestCase {

    func testStrategyForStandup() {
        let strategy = PromptService.shared.strategy(for: .standup)
        XCTAssertTrue(strategy is StandupMeetingStrategy)
        XCTAssertEqual(strategy.promptObject().icon, "figure.stand")
        XCTAssertEqual(strategy.promptObject().title, "Standup Report")
    }

    func testStrategyForDesignReview() {
        let strategy = PromptService.shared.strategy(for: .designReview)
        XCTAssertTrue(strategy is DesignReviewStrategy)
        XCTAssertEqual(strategy.promptObject().icon, "paintbrush")
        XCTAssertEqual(strategy.promptObject().title, "Design Review")
    }

    func testStrategyForGeneral() {
        let strategy = PromptService.shared.strategy(for: .general)
        XCTAssertTrue(strategy is GeneralMeetingStrategy)
        XCTAssertEqual(strategy.promptObject().icon, "doc.text")
        XCTAssertEqual(strategy.promptObject().title, "General Summary")
    }

    func testStrategyForAutodetectDefaultsToGeneral() {
        // Currently mapping autodetect to General until Autodetect logic is implemented
        let strategy = PromptService.shared.strategy(for: .autodetect)
        XCTAssertTrue(strategy is GeneralMeetingStrategy)
    }

    func testStrategyGeneratesPromptWithoutTranscriptionPlaceholder() {
        // Ensuring we removed the interpolation based on our latest fix
        let strategy = PromptService.shared.strategy(for: .general)
        let promptText = strategy.userPrompt(for: "Valid Transcription")

        // It should NOT contain the transcription itself, as that is handled by AIPromptTemplates
        XCTAssertFalse(promptText.contains("Valid Transcription"))
        XCTAssertTrue(promptText.contains("Key Topics Discussed"))
    }
}
