@testable import MeetingAssistantCore
import XCTest

@MainActor
final class GeneralSettingsAppearanceTests: XCTestCase {
    private var settings: AppSettingsStore!

    override func setUp() async throws {
        try AppSettingsTestIsolationLock.acquire()
        settings = .shared
        settings.resetToDefaults()
    }

    override func tearDown() async throws {
        settings.resetToDefaults()
        settings = nil
        AppSettingsTestIsolationLock.release()
    }

    func testAppearanceModeIsPersistedThroughViewModel() {
        let firstViewModel = GeneralSettingsViewModel(settingsStore: settings)
        firstViewModel.appearanceMode = .dark

        let reloadedViewModel = GeneralSettingsViewModel(settingsStore: settings)

        XCTAssertEqual(settings.appearanceMode, .dark)
        XCTAssertEqual(reloadedViewModel.appearanceMode, .dark)
    }
}
