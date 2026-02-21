import XCTest
@testable import MeetingAssistantCore

@MainActor
final class VocabularySettingsViewModelTests: XCTestCase {
    private var settings: AppSettingsStore!

    override func setUp() async throws {
        settings = .shared
        settings.resetToDefaults()
    }

    override func tearDown() async throws {
        settings.resetToDefaults()
        settings = nil
    }

    func testSaveRule_WithEmptyFind_SetsValidationError() {
        let viewModel = VocabularySettingsViewModel(settings: settings)

        let didSave = viewModel.saveRule(find: "   ", replace: "OpenAI")

        XCTAssertFalse(didSave)
        XCTAssertEqual(viewModel.editorValidationError, .emptyFind)
        XCTAssertTrue(settings.vocabularyReplacementRules.isEmpty)
    }

    func testSaveRule_WithDuplicateFind_SetsValidationError() {
        settings.vocabularyReplacementRules = [
            VocabularyReplacementRule(find: "open ay eye", replace: "OpenAI"),
        ]
        let viewModel = VocabularySettingsViewModel(settings: settings)

        let didSave = viewModel.saveRule(find: "OPEN AY EYE", replace: "New Value")

        XCTAssertFalse(didSave)
        XCTAssertEqual(viewModel.editorValidationError, .duplicatedFind)
        XCTAssertEqual(settings.vocabularyReplacementRules.count, 1)
        XCTAssertEqual(settings.vocabularyReplacementRules.first?.replace, "OpenAI")
    }

    func testSaveRule_WhenEditingExistingRule_UpdatesRuleInPlace() {
        let existing = VocabularyReplacementRule(find: "open ay eye", replace: "OpenAI")
        settings.vocabularyReplacementRules = [existing]
        let viewModel = VocabularySettingsViewModel(settings: settings)
        viewModel.startEditingRule(existing)

        let didSave = viewModel.saveRule(find: "open ay eye", replace: "OpenAI Inc.")

        XCTAssertTrue(didSave)
        XCTAssertNil(viewModel.editorValidationError)
        XCTAssertEqual(settings.vocabularyReplacementRules.count, 1)
        XCTAssertEqual(settings.vocabularyReplacementRules.first?.id, existing.id)
        XCTAssertEqual(settings.vocabularyReplacementRules.first?.replace, "OpenAI Inc.")
    }
}
