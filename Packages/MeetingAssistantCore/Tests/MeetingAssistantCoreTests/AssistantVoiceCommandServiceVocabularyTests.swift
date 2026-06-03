import XCTest
@testable import MeetingAssistantCore
@testable import MeetingAssistantCoreUI

@MainActor
final class AssistantVoiceCommandServiceVocabularyTests: XCTestCase {
    func testNormalizedAssistantTranscription_AppliesVocabularyRulesBeforeTrimming() {
        let service = AssistantVoiceCommandService()

        let result = service.normalizedAssistantTranscription(
            "  open ay eye summarize this for reycast  ",
            vocabularyReplacementRules: [
                VocabularyReplacementRule(find: "open ay eye", replace: "OpenAI"),
                VocabularyReplacementRule(find: "reycast, recast", replace: "Raycast"),
            ]
        )

        XCTAssertEqual(result, "OpenAI summarize this for Raycast")
    }

    func testNormalizedAssistantTranscription_ReturnsTrimmedOriginalWhenNoRuleMatches() {
        let service = AssistantVoiceCommandService()

        let result = service.normalizedAssistantTranscription(
            "  ask for status update  ",
            vocabularyReplacementRules: [
                VocabularyReplacementRule(find: "open ay eye", replace: "OpenAI"),
            ]
        )

        XCTAssertEqual(result, "ask for status update")
    }
}
