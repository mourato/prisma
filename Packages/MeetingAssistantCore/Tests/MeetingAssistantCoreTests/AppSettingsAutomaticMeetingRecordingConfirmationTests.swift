import XCTest
@testable import MeetingAssistantCore
@testable import MeetingAssistantCoreInfrastructure

@MainActor
final class AutoMeetingConfirmationSettingsTests: XCTestCase {
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

    func testConfirmationDelayDefaultsToThreeSecondsAfterReset() {
        settings.automaticMeetingRecordingConfirmationDelay = .seconds9

        settings.resetToDefaults()

        XCTAssertEqual(settings.automaticMeetingRecordingConfirmationDelay, .seconds3)
    }

    func testConfirmationDelayPersistsSupportedRawValues() {
        for delay in AppSettingsStore.AutomaticMeetingRecordingConfirmationDelay.allCases {
            settings.automaticMeetingRecordingConfirmationDelay = delay

            XCTAssertEqual(
                UserDefaults.standard.integer(forKey: "automaticMeetingRecordingConfirmationDelay"),
                delay.rawValue
            )
        }
    }

    func testConfirmationDelayRejectsUnsupportedPersistedValues() {
        UserDefaults.standard.set(12, forKey: "automaticMeetingRecordingConfirmationDelay")

        let loaded = AppSettingsStore.loadUIAndIndicatorSettings()

        XCTAssertEqual(loaded.automaticMeetingRecordingConfirmationDelay, .seconds3)
    }
}
