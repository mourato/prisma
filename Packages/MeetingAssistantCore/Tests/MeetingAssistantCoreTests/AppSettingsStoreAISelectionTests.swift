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

    func testResolvedEnhancementsConfiguration_NormalizesLegacyGoogleModelID() {
        settings.enhancementsAISelection = EnhancementsAISelection(
            provider: .google,
            selectedModel: "models/gemini-2.0-flash-001"
        )

        let resolved = settings.resolvedEnhancementsAIConfiguration
        XCTAssertEqual(resolved.provider, .google)
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

    func testBackfillEnhancementsSelectionModels_FillsMeetingSelectionFromLegacyConfiguration() {
        settings.updateAIConfiguration(
            provider: .openai,
            baseURL: AIProvider.openai.defaultBaseURL,
            selectedModel: "gpt-4o-mini"
        )
        settings.enhancementsAISelection = EnhancementsAISelection(provider: .openai, selectedModel: " ")
        settings.enhancementsProviderSelectedModels = [:]

        settings.backfillEnhancementsSelectionModelsIfNeeded()

        XCTAssertEqual(settings.enhancementsAISelection.selectedModel, "gpt-4o-mini")
        XCTAssertEqual(settings.enhancementsProviderSelectedModels[AIProvider.openai.rawValue], "gpt-4o-mini")
    }

    func testBackfillEnhancementsSelectionModels_FillsDictationSelectionFromProviderStoredModel() {
        settings.enhancementsDictationAISelection = EnhancementsAISelection(provider: .anthropic, selectedModel: "")
        settings.enhancementsProviderSelectedModels = [AIProvider.anthropic.rawValue: "claude-3-7-sonnet"]

        settings.backfillEnhancementsSelectionModelsIfNeeded()

        XCTAssertEqual(settings.enhancementsDictationAISelection.selectedModel, "claude-3-7-sonnet")
    }

    func testBackfillEnhancementsSelectionModels_AssistantUsesBackfilledDictationSelection() {
        settings.enhancementsDictationAISelection = EnhancementsAISelection(provider: .openai, selectedModel: "")
        settings.enhancementsProviderSelectedModels = [AIProvider.openai.rawValue: "gpt-4.1-mini"]

        settings.backfillEnhancementsSelectionModelsIfNeeded()

        let assistantConfiguration = settings.resolvedEnhancementsAIConfiguration(for: .assistant)
        XCTAssertEqual(assistantConfiguration.provider, .openai)
        XCTAssertEqual(assistantConfiguration.selectedModel, "gpt-4.1-mini")
    }

    func testBackfillEnhancementsSelectionModels_DoesNotOverrideExistingSelection() {
        settings.enhancementsAISelection = EnhancementsAISelection(
            provider: .openai,
            selectedModel: "gpt-4.1-mini"
        )
        settings.enhancementsProviderSelectedModels = [AIProvider.openai.rawValue: "gpt-4o-mini"]

        settings.backfillEnhancementsSelectionModelsIfNeeded()

        XCTAssertEqual(settings.enhancementsAISelection.selectedModel, "gpt-4.1-mini")
        XCTAssertEqual(settings.enhancementsProviderSelectedModels[AIProvider.openai.rawValue], "gpt-4.1-mini")
    }

    func testBackfillEnhancementsSelectionModels_DoesNotFillWhenNoValidLegacySourceExists() {
        settings.updateAIConfiguration(
            provider: .openai,
            baseURL: AIProvider.openai.defaultBaseURL,
            selectedModel: "   "
        )
        settings.enhancementsAISelection = EnhancementsAISelection(provider: .google, selectedModel: " ")
        settings.enhancementsProviderSelectedModels = [:]

        settings.backfillEnhancementsSelectionModelsIfNeeded()

        XCTAssertEqual(settings.enhancementsAISelection.selectedModel, "")
        XCTAssertNil(settings.enhancementsProviderSelectedModels[AIProvider.google.rawValue])
    }

    func testBackfillEnhancementsSelectionModels_NormalizesLegacyGoogleModelID() {
        settings.updateAIConfiguration(
            provider: .google,
            baseURL: AIProvider.google.defaultBaseURL,
            selectedModel: "models/gemini-2.0-flash-001"
        )
        settings.enhancementsAISelection = EnhancementsAISelection(provider: .google, selectedModel: "")
        settings.enhancementsProviderSelectedModels = [:]

        settings.backfillEnhancementsSelectionModelsIfNeeded()

        XCTAssertEqual(settings.enhancementsAISelection.selectedModel, "gemini-2.0-flash")
        XCTAssertEqual(settings.enhancementsProviderSelectedModels[AIProvider.google.rawValue], "gemini-2.0-flash")
    }

    func testUpdateEnhancementsProviderSelectedModel_NormalizesGoogleModelID() {
        settings.updateEnhancementsProviderSelectedModel("models/gemini-2.0-flash-001", for: .google)

        XCTAssertEqual(settings.enhancementsSelectedModel(for: .google), "gemini-2.0-flash")
        XCTAssertEqual(settings.enhancementsProviderSelectedModels[AIProvider.google.rawValue], "gemini-2.0-flash")
    }
}
