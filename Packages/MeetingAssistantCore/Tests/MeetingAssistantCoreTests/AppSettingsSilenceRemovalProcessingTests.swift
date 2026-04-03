import XCTest
@testable import MeetingAssistantCore

@MainActor
final class AppSettingsSilenceRemovalProcessingTests: XCTestCase {
    private var settings: AppSettingsStore!

    override func setUp() async throws {
        settings = .shared
        settings.resetToDefaults()
    }

    override func tearDown() async throws {
        settings.resetToDefaults()
        settings = nil
    }

    func testRemoveSilenceBeforeProcessing_DefaultsToDisabledAfterReset() {
        settings.removeSilenceBeforeProcessing = true

        settings.resetToDefaults()

        XCTAssertFalse(settings.removeSilenceBeforeProcessing)
    }

    func testRemoveSilenceBeforeProcessing_PersistsInUserDefaults() {
        settings.removeSilenceBeforeProcessing = true
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "removeSilenceBeforeProcessing"))

        settings.removeSilenceBeforeProcessing = false
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "removeSilenceBeforeProcessing"))
    }
}
