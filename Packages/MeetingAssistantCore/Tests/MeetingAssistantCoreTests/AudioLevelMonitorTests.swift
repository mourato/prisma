import XCTest
@testable import MeetingAssistantCoreAudio

@MainActor
final class AudioLevelMonitorTests: XCTestCase {
    func testIngestLevels_UsesFastAttackAndFastRelease() {
        let monitor = AudioLevelMonitor(samplingInterval: 0.03)

        monitor.ingestLevels(averageDB: -6, peakDB: -6)
        XCTAssertEqual(monitor.audioMeter.averagePower, 0.8, accuracy: 0.001)
        XCTAssertEqual(monitor.audioMeter.peakPower, 0.8, accuracy: 0.001)

        monitor.ingestLevels(averageDB: -60, peakDB: -60)
        let expectedReleaseValue = 0.08
        XCTAssertEqual(monitor.audioMeter.averagePower, expectedReleaseValue, accuracy: 0.001)
        XCTAssertEqual(monitor.audioMeter.peakPower, expectedReleaseValue, accuracy: 0.001)
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

    func testIngestLevels_DoesNotShowSilenceWarningOutsideStartupWindow() {
        let monitor = AudioLevelMonitor(samplingInterval: 1.0)

        for _ in 0..<10 {
            monitor.ingestLevels(averageDB: -6, peakDB: -6)
        }

        for _ in 0..<8 {
            monitor.ingestLevels(averageDB: -80, peakDB: -80)
        }

        XCTAssertFalse(monitor.isSilenceWarningVisible)
    }

    func testDismissSilenceWarning_DoesNotRetriggerInSameSession() {
        let monitor = AudioLevelMonitor(samplingInterval: 1.0)

        for _ in 0..<4 {
            monitor.ingestLevels(averageDB: -80, peakDB: -80)
        }
        XCTAssertTrue(monitor.isSilenceWarningVisible)

        monitor.dismissSilenceWarning()
        XCTAssertFalse(monitor.isSilenceWarningVisible)

        for _ in 0..<8 {
            monitor.ingestLevels(averageDB: -80, peakDB: -80)
        }
        XCTAssertFalse(monitor.isSilenceWarningVisible)
    }

    func testStopMonitoring_ResetsSilenceWarningSessionState() {
        let monitor = AudioLevelMonitor(samplingInterval: 1.0)

        for _ in 0..<4 {
            monitor.ingestLevels(averageDB: -80, peakDB: -80)
        }
        XCTAssertTrue(monitor.isSilenceWarningVisible)

        monitor.dismissSilenceWarning()
        for _ in 0..<6 {
            monitor.ingestLevels(averageDB: -80, peakDB: -80)
        }
        XCTAssertFalse(monitor.isSilenceWarningVisible)

        monitor.stopMonitoring()

        for _ in 0..<4 {
            monitor.ingestLevels(averageDB: -80, peakDB: -80)
        }
        XCTAssertTrue(monitor.isSilenceWarningVisible)
    }
}
