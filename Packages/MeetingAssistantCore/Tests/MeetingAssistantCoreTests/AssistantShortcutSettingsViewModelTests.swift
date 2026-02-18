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

    func testUseEnterToStopRecordingPersistsInSettings() async {
        let viewModel = AssistantShortcutSettingsViewModel()

        viewModel.useEnterToStopRecording = true
        await Task.yield()

        XCTAssertTrue(settings.assistantUseEnterToStopRecording)
    }
}
