import XCTest
@testable import MeetingAssistantCore

@MainActor
final class AppSettingsRecordingIndicatorAnimationSpeedTests: XCTestCase {
    private var settings: AppSettingsStore!

    override func setUp() async throws {
        settings = .shared
        settings.resetToDefaults()
    }

    override func tearDown() async throws {
        settings.resetToDefaults()
        settings = nil
    }

    func testRecordingIndicatorAnimationSpeed_DefaultIsNormalAfterReset() {
        settings.recordingIndicatorAnimationSpeed = .fast

        settings.resetToDefaults()

        XCTAssertEqual(settings.recordingIndicatorAnimationSpeed, .normal)
    }

    func testRecordingIndicatorAnimationSpeed_PersistsRawValueInUserDefaults() {
        settings.recordingIndicatorAnimationSpeed = .slow
        XCTAssertEqual(
            UserDefaults.standard.string(forKey: "recordingIndicatorAnimationSpeed"),
            RecordingIndicatorAnimationSpeed.slow.rawValue
        )

        settings.recordingIndicatorAnimationSpeed = .fast
        XCTAssertEqual(
            UserDefaults.standard.string(forKey: "recordingIndicatorAnimationSpeed"),
            RecordingIndicatorAnimationSpeed.fast.rawValue
        )
    }

    func testRecordingIndicatorAnimationSpeed_ResetToDefaultsRestoresNormal() {
        settings.recordingIndicatorAnimationSpeed = .slow

        settings.resetToDefaults()

        XCTAssertEqual(settings.recordingIndicatorAnimationSpeed, .normal)
    }
}
