import XCTest
@testable import MeetingAssistantCore
@testable import MeetingAssistantCoreInfrastructure
@testable import MeetingAssistantCoreUI

@MainActor
final class AssistantAIPhaseTests: XCTestCase {
    private let phase = AssistantAIPhase(
        postProcessingService: .shared,
        scriptRunner: AssistantBashScriptRunner()
    )

    // MARK: - assistantPromptInstructions

    func testPromptInstructions_IntegrationDispatch_NoBaseInstructions() {
        let result = phase.assistantPromptInstructions(
            baseInstructions: nil,
            voiceCommand: "summarize this",
            executionFlow: .integrationDispatch
        )
        XCTAssertTrue(result.contains("You are preparing text that will be sent to another AI assistant"))
        XCTAssertTrue(result.contains("User command:\nsummarize this"))
        XCTAssertFalse(result.contains("Additional user instructions"))
    }

    func testPromptInstructions_IntegrationDispatch_WithBaseInstructions() {
        let result = phase.assistantPromptInstructions(
            baseInstructions: "Be concise",
            voiceCommand: "summarize this",
            executionFlow: .integrationDispatch
        )
        XCTAssertTrue(result.contains("You are preparing text that will be sent to another AI assistant"))
        XCTAssertTrue(result.contains("Additional user instructions:\nBe concise"))
        XCTAssertTrue(result.contains("User command:\nsummarize this"))
    }

    func testPromptInstructions_AssistantMode_NoBaseInstructions() {
        let result = phase.assistantPromptInstructions(
            baseInstructions: nil,
            voiceCommand: "replace with hello",
            executionFlow: .assistantMode
        )
        XCTAssertEqual(result, "replace with hello")
    }

    func testPromptInstructions_AssistantMode_WithBaseInstructions() {
        let result = phase.assistantPromptInstructions(
            baseInstructions: "Translate to French",
            voiceCommand: "hello",
            executionFlow: .assistantMode
        )
        XCTAssertTrue(result.contains("Translate to French"))
        XCTAssertTrue(result.contains("Comando do usuário:\nhello"))
    }

    func testPromptInstructions_TrimsWhitespace() {
        let result = phase.assistantPromptInstructions(
            baseInstructions: nil,
            voiceCommand: "  hello  ",
            executionFlow: .assistantMode
        )
        XCTAssertEqual(result, "hello")
    }

    // MARK: - normalizedPromptInstructions

    func testNormalizedPromptInstructions_ReturnsInstructionsWhenPresent() {
        let integration = makeIntegrationConfig(promptInstructions: "Custom instructions")
        let result = phase.normalizedPromptInstructions(from: integration)
        XCTAssertEqual(result, "Custom instructions")
    }

    func testNormalizedPromptInstructions_ReturnsNilWhenNil() {
        let result = phase.normalizedPromptInstructions(from: nil)
        XCTAssertNil(result)
    }

    func testNormalizedPromptInstructions_ReturnsNilWhenEmpty() {
        let integration = makeIntegrationConfig(promptInstructions: "  ")
        let result = phase.normalizedPromptInstructions(from: integration)
        XCTAssertNil(result)
    }

    // MARK: - Helpers

    private func makeIntegrationConfig(promptInstructions: String?) -> AssistantIntegrationConfig {
        AssistantIntegrationConfig(
            id: UUID(),
            name: "test",
            kind: .deeplink,
            isEnabled: true,
            deepLink: "test://",
            promptInstructions: promptInstructions,
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
