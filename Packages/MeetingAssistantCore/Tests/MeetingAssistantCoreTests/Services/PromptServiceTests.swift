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
        // Autodetect is implemented at a higher level (classification), but the PromptService strategy
        // for `.autodetect` should still default to General as a safe fallback.
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

    func testExtractSiteOrAppPriorityInstructions_WhenPresent_ReturnsCleanPromptAndExtractedBlock() {
        let prompt = """
        Base instructions.

        <SITE_OR_APP_PRIORITY_INSTRUCTIONS>
        Always write in lowercase.
        </SITE_OR_APP_PRIORITY_INSTRUCTIONS>
        """

        let extracted = AIPromptTemplates.extractSiteOrAppPriorityInstructions(from: prompt)

        XCTAssertEqual(extracted.cleanPrompt, "Base instructions.")
        XCTAssertEqual(extracted.priorityInstructions, "Always write in lowercase.")
    }

    func testSystemPrompt_WithPriorityInstructions_AppendsExplicitPrecedence() {
        let system = AIPromptTemplates.systemPrompt(
            basePrompt: "Base system prompt",
            priorityInstructions: "Always write in lowercase."
        )

        XCTAssertTrue(system.contains("Base system prompt"))
        XCTAssertTrue(system.contains("highest priority"))
        XCTAssertTrue(system.contains("Always write in lowercase."))
    }

    func testUserMessage_WithPriorityInstructions_DoesNotDuplicatePriorityBlock() {
        let userMessage = AIPromptTemplates.userMessage(
            transcription: "hello world",
            prompt: "Summarize",
            priorityInstructions: "Always write in lowercase."
        )

        XCTAssertTrue(userMessage.contains("<TRANSCRIPTION>"))
        XCTAssertTrue(userMessage.contains("<INSTRUCTIONS>"))
        XCTAssertFalse(userMessage.contains("<SITE_APP_PRIORITY>"))
        XCTAssertFalse(userMessage.contains("Always write in lowercase."))
    }

    func testUserMessage_BlockOrder_PlacesTranscriptionAfterContextMetadata() throws {
        let userMessage = AIPromptTemplates.userMessage(
            transcription: "hello world",
            prompt: "Summarize",
            priorityInstructions: "Always write in lowercase.",
            contextMetadata: "Active app: VSCode"
        )

        let instructionsRange = try XCTUnwrap(userMessage.range(of: "<INSTRUCTIONS>"))
        let contextRange = try XCTUnwrap(userMessage.range(of: "<CONTEXT_METADATA>"))
        let transcriptionRange = try XCTUnwrap(userMessage.range(of: "<TRANSCRIPTION>"))

        XCTAssertLessThan(instructionsRange.lowerBound, contextRange.lowerBound)
        XCTAssertLessThan(contextRange.lowerBound, transcriptionRange.lowerBound)
    }

    func testUserMessage_WhenTranscriptionAlreadyContainsContextMetadata_DoesNotInjectSecondContextBlock() throws {
        let userMessage = AIPromptTemplates.userMessage(
            transcription: """
            hello world

            <CONTEXT_METADATA>
            Active app: WhatsApp
            </CONTEXT_METADATA>
            """,
            prompt: "Summarize",
            priorityInstructions: nil,
            contextMetadata: "Active app: WhatsApp"
        )

        let contextTagCount = userMessage.components(separatedBy: "<CONTEXT_METADATA>").count - 1
        XCTAssertEqual(contextTagCount, 1)

        let transcriptionRange = try XCTUnwrap(userMessage.range(of: "<TRANSCRIPTION>"))
        let prefix = String(userMessage[..<transcriptionRange.lowerBound])
        XCTAssertFalse(prefix.contains("<CONTEXT_METADATA>"))
    }
}
