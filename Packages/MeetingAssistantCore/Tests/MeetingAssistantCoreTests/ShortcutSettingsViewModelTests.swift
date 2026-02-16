import XCTest
@testable import MeetingAssistantCore

@MainActor
final class ShortcutSettingsViewModelTests: XCTestCase {
    private var settings: AppSettingsStore!

    override func setUp() async throws {
        settings = .shared
        settings.resetToDefaults()
    }

    override func tearDown() async throws {
        settings.resetToDefaults()
        settings = nil
    }

    func testClearingDictationShortcutSetsPresetToNotSpecified() async {
        let viewModel = ShortcutSettingsViewModel()
        let shortcut = ShortcutDefinition(
            modifiers: [.rightCommand],
            primaryKey: nil,
            trigger: .doubleTap
        )

        viewModel.dictationShortcutDefinition = shortcut
        await Task.yield()
        XCTAssertEqual(settings.dictationSelectedPresetKey, .custom)

        viewModel.dictationShortcutDefinition = nil
        await Task.yield()

        XCTAssertNil(settings.dictationShortcutDefinition)
        XCTAssertNil(settings.dictationModifierShortcutGesture)
        XCTAssertEqual(settings.dictationSelectedPresetKey, .notSpecified)
        XCTAssertEqual(viewModel.dictationSelectedPresetKey, .notSpecified)
    }

    func testClearingMeetingShortcutSetsPresetToNotSpecified() async {
        let viewModel = ShortcutSettingsViewModel()
        let shortcut = ShortcutDefinition(
            modifiers: [.rightControl],
            primaryKey: nil,
            trigger: .doubleTap
        )

        viewModel.meetingShortcutDefinition = shortcut
        await Task.yield()
        XCTAssertEqual(settings.meetingSelectedPresetKey, .custom)

        viewModel.meetingShortcutDefinition = nil
        await Task.yield()

        XCTAssertNil(settings.meetingShortcutDefinition)
        XCTAssertNil(settings.meetingModifierShortcutGesture)
        XCTAssertEqual(settings.meetingSelectedPresetKey, .notSpecified)
        XCTAssertEqual(viewModel.meetingSelectedPresetKey, .notSpecified)
    }
}
