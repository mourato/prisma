import XCTest
@testable import MeetingAssistantCore

@MainActor
final class AppSettingsVocabularyRulesTests: XCTestCase {
    private var settings: AppSettingsStore!

    override func setUp() async throws {
        settings = .shared
        settings.resetToDefaults()
    }

    override func tearDown() async throws {
        settings.resetToDefaults()
        settings = nil
    }

    func testVocabularyRules_AreNormalizedAndDeduplicatedByFind() {
        settings.vocabularyReplacementRules = [
            VocabularyReplacementRule(find: "  open ay eye  ", replace: " OpenAI "),
            VocabularyReplacementRule(find: "OPEN AY EYE", replace: "SHOULD_NOT_WIN"),
            VocabularyReplacementRule(find: "   ", replace: "ignored"),
            VocabularyReplacementRule(find: "g p t", replace: "GPT"),
        ]

        XCTAssertEqual(settings.vocabularyReplacementRules.count, 2)
        XCTAssertEqual(settings.vocabularyReplacementRules[0].find, "open ay eye")
        XCTAssertEqual(settings.vocabularyReplacementRules[0].replace, "OpenAI")
        XCTAssertEqual(settings.vocabularyReplacementRules[1].find, "g p t")
        XCTAssertEqual(settings.vocabularyReplacementRules[1].replace, "GPT")
    }

    func testResetToDefaults_ClearsVocabularyRules() {
        settings.vocabularyReplacementRules = [
            VocabularyReplacementRule(find: "open ay eye", replace: "OpenAI"),
        ]

        settings.resetToDefaults()

        XCTAssertTrue(settings.vocabularyReplacementRules.isEmpty)
    }
}
