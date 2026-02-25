import XCTest
@testable import MeetingAssistantCore

@MainActor
final class AssistantShortcutSettingsViewModelTests: XCTestCase {
    private var settings: AppSettingsStore!

    override func setUp() async throws {
        settings = .shared
        settings.resetToDefaults()
        ShortcutCaptureHealthStore.reset()
    }

    override func tearDown() async throws {
        ShortcutCaptureHealthStore.reset()
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

    func testShortcutCaptureHealthPresentationUpdatesWhenAssistantFallbackIsActive() async {
        let viewModel = AssistantShortcutSettingsViewModel()
        XCTAssertNil(viewModel.shortcutCaptureHealthPresentation)

        ShortcutCaptureHealthStore.updateHealth(
            scope: .assistant,
            result: "degraded",
            reasonToken: "event_tap_inactive",
            requiresGlobalCapture: true,
            accessibilityTrusted: true,
            inputMonitoringTrusted: true,
            eventTapExpected: true,
            eventTapActive: false
        )
        await Task.yield()

        XCTAssertEqual(viewModel.shortcutCaptureHealthPresentation?.badgeKey, "settings.shortcuts.health.badge.fallback")
        XCTAssertEqual(viewModel.shortcutCaptureHealthPresentation?.isFallback, true)
    }

    func testAssistantShortcutConflictWithLayerLeaderShowsLayerConflictMessage() async {
        settings.assistantLayerShortcutKey = "R"
        let viewModel = AssistantShortcutSettingsViewModel()

        viewModel.assistantShortcutDefinition = ShortcutDefinition(
            modifiers: [.command],
            primaryKey: .letter("R", keyCode: 0x0f),
            trigger: .singleTap
        )
        await Task.yield()

        XCTAssertNil(settings.assistantShortcutDefinition)
        XCTAssertEqual(
            viewModel.assistantModifierConflictMessage,
            "settings.assistant.layer.duplicate_key".localized
        )
    }
}
