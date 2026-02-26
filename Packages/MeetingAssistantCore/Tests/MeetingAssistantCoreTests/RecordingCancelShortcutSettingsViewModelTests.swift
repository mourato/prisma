import XCTest
@testable import MeetingAssistantCore

@MainActor
final class RecordingCancelShortcutSettingsViewModelTests: XCTestCase {
    private var settings: AppSettingsStore!

    override func setUp() async throws {
        settings = .shared
        settings.resetToDefaults()
    }

    override func tearDown() async throws {
        settings.resetToDefaults()
        settings = nil
    }

    func testValidShortcutPersistsCancelRecordingShortcutDefinition() async {
        let viewModel = RecordingCancelShortcutSettingsViewModel()
        let shortcut = ShortcutDefinition(
            modifiers: [.command, .option],
            primaryKey: .letter("K", keyCode: 0x28),
            trigger: .singleTap
        )

        viewModel.cancelRecordingShortcutDefinition = shortcut
        await Task.yield()

        XCTAssertEqual(settings.cancelRecordingShortcutDefinition, shortcut)
        XCTAssertNil(viewModel.cancelRecordingShortcutConflictMessage)
    }

    func testClearingShortcutRemovesPersistedCancelShortcut() async {
        let viewModel = RecordingCancelShortcutSettingsViewModel()
        let shortcut = ShortcutDefinition(
            modifiers: [.command, .option],
            primaryKey: .letter("K", keyCode: 0x28),
            trigger: .singleTap
        )

        viewModel.cancelRecordingShortcutDefinition = shortcut
        await Task.yield()
        XCTAssertEqual(settings.cancelRecordingShortcutDefinition, shortcut)

        viewModel.cancelRecordingShortcutDefinition = nil
        await Task.yield()

        XCTAssertNil(settings.cancelRecordingShortcutDefinition)
        XCTAssertNil(viewModel.cancelRecordingShortcutConflictMessage)
    }

    func testFnShortcutIsRejectedForGlobalCancelHotkey() async {
        let viewModel = RecordingCancelShortcutSettingsViewModel()
        let shortcut = ShortcutDefinition(
            modifiers: [.fn, .command],
            primaryKey: .letter("K", keyCode: 0x28),
            trigger: .singleTap
        )

        viewModel.cancelRecordingShortcutDefinition = shortcut
        await Task.yield()

        XCTAssertNil(settings.cancelRecordingShortcutDefinition)
        XCTAssertNil(viewModel.cancelRecordingShortcutDefinition)
        XCTAssertEqual(
            viewModel.cancelRecordingShortcutConflictMessage,
            "settings.general.cancel_recording_shortcut_unsupported".localized
        )
    }

    func testConflictingShortcutIsRejected() async {
        let viewModel = RecordingCancelShortcutSettingsViewModel()
        let conflictingShortcut = ShortcutDefinition(
            modifiers: [.control],
            primaryKey: .letter("J", keyCode: 0x26),
            trigger: .singleTap
        )

        settings.dictationShortcutDefinition = conflictingShortcut
        settings.dictationModifierShortcutGesture = conflictingShortcut.asModifierShortcutGesture
        settings.dictationSelectedPresetKey = .custom

        viewModel.cancelRecordingShortcutDefinition = conflictingShortcut
        await Task.yield()

        XCTAssertNil(settings.cancelRecordingShortcutDefinition)
        XCTAssertNil(viewModel.cancelRecordingShortcutDefinition)
        XCTAssertNotNil(viewModel.cancelRecordingShortcutConflictMessage)
    }

    func testConfiguredShortcutBindingsIncludesCancelRecordingShortcut() async {
        let shortcut = ShortcutDefinition(
            modifiers: [.command, .shift],
            primaryKey: .letter("C", keyCode: 0x08),
            trigger: .singleTap
        )

        settings.cancelRecordingShortcutDefinition = shortcut

        XCTAssertTrue(
            settings.configuredShortcutBindings.contains(where: { binding in
                binding.actionID == .cancelActiveRecording && binding.shortcut == shortcut
            })
        )
    }
}
