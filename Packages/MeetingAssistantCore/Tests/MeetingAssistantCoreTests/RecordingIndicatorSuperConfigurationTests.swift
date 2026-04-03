import XCTest
@testable import MeetingAssistantCore
@testable import MeetingAssistantCoreAudio

@MainActor
final class RecordingIndicatorSuperConfigurationTests: XCTestCase {
    private var settings: AppSettingsStore!

    override func setUp() async throws {
        settings = .shared
        settings.resetToDefaults()
    }

    override func tearDown() async throws {
        settings.resetToDefaults()
        settings = nil
    }

    func testRecordingIndicatorStyle_PersistsSuperRawValueInUserDefaults() {
        settings.recordingIndicatorStyle = .`super`

        XCTAssertEqual(
            UserDefaults.standard.string(forKey: "recordingIndicatorStyle"),
            RecordingIndicatorStyle.`super`.rawValue
        )
    }

    func testRecordingIndicatorStyle_ResetToDefaultsRestoresMini() {
        settings.recordingIndicatorStyle = .`super`

        settings.resetToDefaults()

        XCTAssertEqual(settings.recordingIndicatorStyle, .mini)
    }

    func testWaveformBarCount_ForSuper_IsFiftySix() {
        XCTAssertEqual(AudioRecorder.waveformBarCount(for: .`super`), 56)
    }
}
