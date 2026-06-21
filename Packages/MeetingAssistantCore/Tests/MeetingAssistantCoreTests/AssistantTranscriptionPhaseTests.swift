import XCTest
@testable import MeetingAssistantCore
@testable import MeetingAssistantCoreInfrastructure
@testable import MeetingAssistantCoreUI

@MainActor
final class AssistantTranscriptionPhaseTests: XCTestCase {
    private let phase = AssistantTranscriptionPhase(transcriptionClient: .shared)

    // MARK: - normalizedAssistantTranscription

    func testNormalizedAssistantTranscription_AppliesVocabularyRulesBeforeTrimming() {
        let result = phase.normalizedAssistantTranscription(
            "  open ay eye summarize this for reycast  ",
            vocabularyReplacementRules: [
                VocabularyReplacementRule(find: "open ay eye", replace: "OpenAI"),
                VocabularyReplacementRule(find: "reycast, recast", replace: "Raycast"),
            ]
        )
        XCTAssertEqual(result, "OpenAI summarize this for Raycast")
    }

    func testNormalizedAssistantTranscription_ReturnsTrimmedOriginalWhenNoRuleMatches() {
        let result = phase.normalizedAssistantTranscription(
            "  ask for status update  ",
            vocabularyReplacementRules: [
                VocabularyReplacementRule(find: "open ay eye", replace: "OpenAI"),
            ]
        )
        XCTAssertEqual(result, "ask for status update")
    }

    func testNormalizedAssistantTranscription_HandlesEmptyInput() {
        let result = phase.normalizedAssistantTranscription(
            "  ",
            vocabularyReplacementRules: []
        )
        XCTAssertEqual(result, "")
    }

    // MARK: - resolveSelectedIntegration

    func testResolveSelectedIntegration_ReturnsIntegrationWhenDispatchEnabled() {
        let integration = makeIntegrationConfig(name: "test")
        let result = phase.resolveSelectedIntegration(
            executionFlow: .integrationDispatch,
            isAssistantIntegrationsEnabled: true,
            assistantSelectedIntegration: integration
        )
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "test")
    }

    func testResolveSelectedIntegration_ReturnsNilWhenNotDispatchFlow() {
        let integration = makeIntegrationConfig(name: "test")
        let result = phase.resolveSelectedIntegration(
            executionFlow: .assistantMode,
            isAssistantIntegrationsEnabled: true,
            assistantSelectedIntegration: integration
        )
        XCTAssertNil(result)
    }

    func testResolveSelectedIntegration_ReturnsNilWhenIntegrationsDisabled() {
        let integration = makeIntegrationConfig(name: "test")
        let result = phase.resolveSelectedIntegration(
            executionFlow: .integrationDispatch,
            isAssistantIntegrationsEnabled: false,
            assistantSelectedIntegration: integration
        )
        XCTAssertNil(result)
    }

    func testResolveSelectedIntegration_ReturnsNilWhenNoIntegration() {
        let result = phase.resolveSelectedIntegration(
            executionFlow: .integrationDispatch,
            isAssistantIntegrationsEnabled: true,
            assistantSelectedIntegration: nil
        )
        XCTAssertNil(result)
    }

    // MARK: - Helpers

    private func makeIntegrationConfig(name: String) -> AssistantIntegrationConfig {
        AssistantIntegrationConfig(
            id: UUID(),
            name: name,
            kind: .deeplink,
            isEnabled: true,
            deepLink: "test://",
            promptInstructions: nil,
            selectedPreset: nil,
            shortcutDefinition: nil,
            shortcutPresetKey: .notSpecified,
            shortcutActivationMode: .holdOrToggle,
            modifierShortcutGesture: nil,
            advancedScript: nil,
            showsPromptSelectorInOverlay: false,
            showsLanguageSelectorInOverlay: false
        )
    }
}
