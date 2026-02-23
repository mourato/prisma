import XCTest
@testable import MeetingAssistantCore

@MainActor
final class AppSettingsStoreAISelectionTests: XCTestCase {
    private var settings: AppSettingsStore!

    override func setUp() async throws {
        settings = .shared
        settings.resetToDefaults()
    }

    override func tearDown() async throws {
        settings.resetToDefaults()
        settings = nil
    }

    func testResolvedEnhancementsConfigurationUsesProviderDefaults() {
        settings.enhancementsAISelection = EnhancementsAISelection(
            provider: .google,
            selectedModel: "gemini-2.0-flash"
        )

        let resolved = settings.resolvedEnhancementsAIConfiguration
        XCTAssertEqual(resolved.provider, .google)
        XCTAssertEqual(resolved.baseURL, AIProvider.google.defaultBaseURL)
        XCTAssertEqual(resolved.selectedModel, "gemini-2.0-flash")
    }

    func testResolvedEnhancementsConfigurationUsesAPIBaseURLForCustomProvider() {
        settings.updateAIConfiguration(provider: .custom, baseURL: "https://proxy.example.com/v1", selectedModel: "base")
        settings.enhancementsAISelection = EnhancementsAISelection(
            provider: .custom,
            selectedModel: "custom-model"
        )

        let resolved = settings.resolvedEnhancementsAIConfiguration
        XCTAssertEqual(resolved.provider, .custom)
        XCTAssertEqual(resolved.baseURL, "https://proxy.example.com/v1")
        XCTAssertEqual(resolved.selectedModel, "custom-model")
    }

    func testResetDefaultsEnablesMeetingQnA() {
        settings.meetingQnAEnabled = false
        settings.resetToDefaults()

        XCTAssertTrue(settings.meetingQnAEnabled)
    }

    func testUpdateEnhancementsProviderClearsSelectedModel() {
        settings.enhancementsAISelection = EnhancementsAISelection(
            provider: .openai,
            selectedModel: "gpt-4o-mini"
        )

        settings.updateEnhancementsProvider(.anthropic)

        XCTAssertEqual(settings.enhancementsAISelection.provider, .anthropic)
        XCTAssertEqual(settings.enhancementsAISelection.selectedModel, "")
    }

    func testEnhancementsInferenceReadinessIssue_MissingModel() {
        settings.enhancementsAISelection = EnhancementsAISelection(
            provider: .openai,
            selectedModel: "   "
        )

        let issue = settings.enhancementsInferenceReadinessIssue(apiKeyExists: { _ in true })

        XCTAssertEqual(issue, .missingModel)
    }

    func testEnhancementsInferenceReadinessIssue_ReturnsNilWhenConfigurationIsReady() {
        settings.enhancementsAISelection = EnhancementsAISelection(
            provider: .openai,
            selectedModel: "gpt-4o-mini"
        )

        let issue = settings.enhancementsInferenceReadinessIssue(apiKeyExists: { _ in true })

        XCTAssertNil(issue)
    }
}
