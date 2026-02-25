import XCTest
@testable import MeetingAssistantCore

@MainActor
final class IntegrationSettingsViewModelTests: XCTestCase {
    private var settings: AppSettingsStore!

    override func setUp() async throws {
        settings = .shared
        settings.resetToDefaults()
    }

    override func tearDown() async throws {
        settings.resetToDefaults()
        settings = nil
    }

    func testClearingIntegrationShortcutSetsPresetToNotSpecified() {
        let viewModel = IntegrationSettingsViewModel()
        viewModel.addIntegration()

        guard let integrationID = viewModel.customIntegrations.last?.id else {
            XCTFail("Expected a custom integration after addIntegration")
            return
        }

        let shortcut = ShortcutDefinition(
            modifiers: [.option, .command],
            primaryKey: .letter("T", keyCode: 0x11),
            trigger: .singleTap
        )

        XCTAssertNil(viewModel.setIntegrationShortcutDefinition(shortcut, for: integrationID))
        XCTAssertEqual(viewModel.integration(for: integrationID)?.shortcutPresetKey, .custom)

        XCTAssertNil(viewModel.setIntegrationShortcutDefinition(nil, for: integrationID))
        XCTAssertNil(viewModel.integration(for: integrationID)?.shortcutDefinition)
        XCTAssertNil(viewModel.integration(for: integrationID)?.modifierShortcutGesture)
        XCTAssertEqual(viewModel.integration(for: integrationID)?.shortcutPresetKey, .notSpecified)
    }

    func testIntegrationShortcutConflictWithAssistantReturnsModifierConflictMessage() {
        settings.assistantShortcutDefinition = ShortcutDefinition(
            modifiers: [.command],
            primaryKey: .letter("K", keyCode: 0x28),
            trigger: .singleTap
        )

        let viewModel = IntegrationSettingsViewModel()
        viewModel.addIntegration()

        guard let integrationID = viewModel.customIntegrations.last?.id else {
            XCTFail("Expected a custom integration after addIntegration")
            return
        }

        viewModel.setIntegrationEnabled(true, for: integrationID)

        let message = viewModel.setIntegrationShortcutDefinition(
            ShortcutDefinition(
                modifiers: [.leftCommand],
                primaryKey: .letter("K", keyCode: 0x28),
                trigger: .singleTap
            ),
            for: integrationID
        )

        XCTAssertEqual(
            message,
            "settings.shortcuts.modifier.conflict".localized(with: "settings.assistant.toggle_command".localized)
        )
        XCTAssertNil(viewModel.integration(for: integrationID)?.shortcutDefinition)
    }

    func testIntegrationShortcutDefinitionWithoutPrimaryKeyReturnsValidationMessage() {
        let viewModel = IntegrationSettingsViewModel()
        viewModel.addIntegration()

        guard let integrationID = viewModel.customIntegrations.last?.id else {
            XCTFail("Expected a custom integration after addIntegration")
            return
        }

        viewModel.setIntegrationEnabled(true, for: integrationID)

        let message = viewModel.setIntegrationShortcutDefinition(
            ShortcutDefinition(
                modifiers: [.rightControl],
                primaryKey: nil,
                trigger: .doubleTap
            ),
            for: integrationID
        )

        XCTAssertEqual(message, "settings.shortcuts.modifier.primary_key_required".localized)
        XCTAssertNil(viewModel.integration(for: integrationID)?.shortcutDefinition)
    }
}
