import XCTest
@testable import MeetingAssistantCore

@MainActor
final class AssistantShortcutSettingsViewModelTests: XCTestCase {
    private var settings: AppSettingsStore!

    override func setUp() async throws {
        settings = .shared
        settings.resetToDefaults()
    }

    override func tearDown() async throws {
        settings.resetToDefaults()
        settings = nil
    }

    func testClearingAssistantShortcutSetsPresetToNotSpecified() async {
        let viewModel = AssistantShortcutSettingsViewModel()
        let shortcut = ShortcutDefinition(
            modifiers: [.rightCommand],
            primaryKey: nil,
            trigger: .doubleTap
        )

        viewModel.assistantShortcutDefinition = shortcut
        await Task.yield()
        XCTAssertEqual(settings.assistantSelectedPresetKey, .custom)

        viewModel.assistantShortcutDefinition = nil
        await Task.yield()

        XCTAssertNil(settings.assistantShortcutDefinition)
        XCTAssertNil(settings.assistantModifierShortcutGesture)
        XCTAssertEqual(settings.assistantSelectedPresetKey, .notSpecified)
        XCTAssertEqual(viewModel.selectedPresetKey, .notSpecified)
    }

    func testClearingIntegrationShortcutSetsPresetToNotSpecified() {
        let viewModel = AssistantShortcutSettingsViewModel()
        viewModel.addIntegration()

        guard let integrationID = viewModel.customIntegrations.last?.id else {
            XCTFail("Expected a custom integration after addIntegration")
            return
        }

        let shortcut = ShortcutDefinition(
            modifiers: [.rightOption],
            primaryKey: nil,
            trigger: .doubleTap
        )

        XCTAssertNil(viewModel.setIntegrationShortcutDefinition(shortcut, for: integrationID))
        XCTAssertEqual(viewModel.integration(for: integrationID)?.shortcutPresetKey, .custom)

        XCTAssertNil(viewModel.setIntegrationShortcutDefinition(nil, for: integrationID))
        XCTAssertNil(viewModel.integration(for: integrationID)?.shortcutDefinition)
        XCTAssertNil(viewModel.integration(for: integrationID)?.modifierShortcutGesture)
        XCTAssertEqual(viewModel.integration(for: integrationID)?.shortcutPresetKey, .notSpecified)
    }
}
