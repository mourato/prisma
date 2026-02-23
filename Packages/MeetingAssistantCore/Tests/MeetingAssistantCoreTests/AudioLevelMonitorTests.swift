import XCTest
@testable import MeetingAssistantCoreAudio

@MainActor
final class AudioLevelMonitorTests: XCTestCase {
    func testIngestLevels_UsesFastAttackAndSlowerRelease() {
        let monitor = AudioLevelMonitor(samplingInterval: 0.03)

        monitor.ingestLevels(averageDB: -6, peakDB: -6)
        XCTAssertEqual(monitor.audioMeter.averagePower, 0.8, accuracy: 0.001)
        XCTAssertEqual(monitor.audioMeter.peakPower, 0.8, accuracy: 0.001)

        monitor.ingestLevels(averageDB: -60, peakDB: -60)
        XCTAssertEqual(monitor.audioMeter.averagePower, 0.56, accuracy: 0.001)
        XCTAssertEqual(monitor.audioMeter.peakPower, 0.56, accuracy: 0.001)
    }

    func testIngestLevels_ShowsSilenceWarningAfterConfiguredDuration() {
        let monitor = AudioLevelMonitor(samplingInterval: 1.0)

        for _ in 0..<3 {
            monitor.ingestLevels(averageDB: -80, peakDB: -80)
            XCTAssertFalse(monitor.isSilenceWarningVisible)
        }

        monitor.ingestLevels(averageDB: -80, peakDB: -80)
        XCTAssertTrue(monitor.isSilenceWarningVisible)
    }

    func testDismissSilenceWarning_ResetsTimerUntilSilenceDurationIsReachedAgain() {
        let monitor = AudioLevelMonitor(samplingInterval: 1.0)

        for _ in 0..<4 {
            monitor.ingestLevels(averageDB: -80, peakDB: -80)
        }
        XCTAssertTrue(monitor.isSilenceWarningVisible)

        monitor.dismissSilenceWarning()
        XCTAssertFalse(monitor.isSilenceWarningVisible)

        monitor.ingestLevels(averageDB: -80, peakDB: -80)
        XCTAssertFalse(monitor.isSilenceWarningVisible)
    }
}
