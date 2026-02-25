import XCTest
@testable import MeetingAssistantCore

@MainActor
final class AppSettingsAssistantIntegrationsTests: XCTestCase {
    private var settings: AppSettingsStore!

    override func setUp() async throws {
        settings = .shared
        settings.resetToDefaults()
    }

    override func tearDown() async throws {
        settings.resetToDefaults()
        settings = nil
    }

    func testDefaults_SeedsRaycastIntegrationAsSelected() {
        XCTAssertEqual(settings.assistantIntegrations.count, 1)

        let raycast = settings.assistantIntegrations.first
        XCTAssertEqual(raycast?.name, "Raycast")
        XCTAssertEqual(raycast?.deepLink, AssistantIntegrationConfig.defaultRaycastDeepLink)
        XCTAssertEqual(settings.assistantSelectedIntegrationId, raycast?.id)
        XCTAssertEqual(settings.assistantSelectedIntegration?.id, raycast?.id)
    }

    func testUpsertAssistantIntegration_UpdatesExistingIntegration() {
        guard var integration = settings.assistantSelectedIntegration else {
            XCTFail("Expected default selected integration")
            return
        }

        integration.isEnabled = true
        integration.deepLink = "raycast://ai-commands/custom-command"

        settings.upsertAssistantIntegration(integration)

        XCTAssertEqual(settings.assistantIntegrations.count, 1)
        XCTAssertEqual(settings.assistantSelectedIntegration?.isEnabled, true)
        XCTAssertEqual(settings.assistantSelectedIntegration?.deepLink, AssistantIntegrationConfig.defaultRaycastDeepLink)
    }

    func testUpsertAssistantIntegration_AppendsNewIntegration() {
        let custom = AssistantIntegrationConfig(
            name: "Custom Integration",
            kind: .deeplink,
            isEnabled: false,
            deepLink: "raycast://ai-commands/custom"
        )

        settings.upsertAssistantIntegration(custom)

        XCTAssertEqual(settings.assistantIntegrations.count, 2)
        XCTAssertTrue(settings.assistantIntegrations.contains(where: { $0.id == custom.id }))
    }

    func testRemoveAssistantIntegration_ReassignsSelectionWhenRemovingCurrent() {
        let custom = AssistantIntegrationConfig(
            name: "Custom Integration",
            kind: .deeplink,
            isEnabled: true,
            deepLink: "raycast://ai-commands/custom"
        )
        settings.upsertAssistantIntegration(custom)
        settings.assistantSelectedIntegrationId = custom.id

        settings.removeAssistantIntegration(id: custom.id)

        XCTAssertEqual(settings.assistantIntegrations.count, 1)
        XCTAssertEqual(settings.assistantSelectedIntegrationId, AssistantIntegrationConfig.raycastDefaultID)
    }

    func testIntegrationsEmpty_FallsBackToDefaultRaycast() {
        settings.assistantIntegrations = []

        XCTAssertEqual(settings.assistantIntegrations.count, 1)
        XCTAssertEqual(settings.assistantIntegrations.first?.id, AssistantIntegrationConfig.raycastDefaultID)
        XCTAssertEqual(settings.assistantSelectedIntegrationId, AssistantIntegrationConfig.raycastDefaultID)
    }

    func testIntegrationLeaderModeEnabled_DefaultsToFalse() {
        let integration = AssistantIntegrationConfig(
            name: "Test Integration",
            kind: .deeplink,
            isEnabled: true,
            deepLink: "raycast://test"
        )

        XCTAssertFalse(integration.leaderModeEnabled)
    }

    func testIntegrationLeaderModeEnabled_CanBeSetToTrue() {
        let integration = AssistantIntegrationConfig(
            name: "Test Integration",
            kind: .deeplink,
            isEnabled: true,
            deepLink: "raycast://test",
            leaderModeEnabled: true
        )

        XCTAssertTrue(integration.leaderModeEnabled)
    }

    func testIntegrationLeaderModeEnabled_CodableRoundTrip() throws {
        let original = AssistantIntegrationConfig(
            name: "Test Integration",
            kind: .deeplink,
            isEnabled: true,
            deepLink: "raycast://test",
            layerShortcutKey: "T",
            leaderModeEnabled: true
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AssistantIntegrationConfig.self, from: data)

        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.leaderModeEnabled, true)
        XCTAssertEqual(decoded.layerShortcutKey, "T")
    }

    func testIntegrationLeaderModeEnabled_DefaultRaycastHasLeaderModeDisabled() {
        let raycast = AssistantIntegrationConfig.defaultRaycast

        XCTAssertFalse(raycast.leaderModeEnabled)
    }

    func testUpsertIntegrationWithLeaderModeEnabled() {
        let integration = AssistantIntegrationConfig(
            name: "Test Integration",
            kind: .deeplink,
            isEnabled: true,
            deepLink: "raycast://test",
            layerShortcutKey: "T",
            leaderModeEnabled: true
        )

        settings.upsertAssistantIntegration(integration)

        let saved = settings.assistantIntegrations.first { $0.id == integration.id }
        XCTAssertNotNil(saved)
        XCTAssertTrue(saved?.leaderModeEnabled ?? false)
    }
}
