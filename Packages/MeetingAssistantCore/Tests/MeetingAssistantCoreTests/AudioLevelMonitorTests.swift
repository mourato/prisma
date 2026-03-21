import XCTest
@testable import MeetingAssistantCoreAudio

@MainActor
final class AudioLevelMonitorTests: XCTestCase {
    func testDefaultSamplingInterval_IsApproximatelySixtyHertz() {
        let monitor = AudioLevelMonitor()

        XCTAssertEqual(monitor.effectiveSamplingInterval, 0.017, accuracy: 0.0001)
    }

    func testIngestLevels_NormalizesDecibelsLinearly() {
        let monitor = AudioLevelMonitor(samplingInterval: 0.03)

        monitor.ingestLevels(averageDB: -60, peakDB: -60)
        XCTAssertEqual(monitor.audioMeter.averagePower, 0.0, accuracy: 0.001)
        XCTAssertEqual(monitor.audioMeter.peakPower, 0.0, accuracy: 0.001)

        monitor.ingestLevels(averageDB: -30, peakDB: -30)
        XCTAssertEqual(monitor.audioMeter.averagePower, 0.5, accuracy: 0.001)
        XCTAssertEqual(monitor.audioMeter.peakPower, 0.5, accuracy: 0.001)

        monitor.ingestLevels(averageDB: 0, peakDB: 0)
        XCTAssertEqual(monitor.audioMeter.averagePower, 1.0, accuracy: 0.001)
        XCTAssertEqual(monitor.audioMeter.peakPower, 1.0, accuracy: 0.001)
    }

    func testIngestLevels_ClampsValuesOutsideVisibleRange() {
        let monitor = AudioLevelMonitor(samplingInterval: 0.03)

        monitor.ingestLevels(averageDB: -90, peakDB: 12)

        XCTAssertEqual(monitor.audioMeter.averagePower, 0.0, accuracy: 0.001)
        XCTAssertEqual(monitor.audioMeter.peakPower, 1.0, accuracy: 0.001)
    }

    func testIngestLevels_NormalizesInstantBarLevelsFromCurrentSnapshot() {
        let monitor = AudioLevelMonitor(samplingInterval: 0.03)

        monitor.ingestLevels(
            averageDB: -30,
            peakDB: -30,
            barLevelsDB: [-60, -30, 0]
        )

        XCTAssertEqual(monitor.instantBarLevels.count, 3)
        XCTAssertEqual(monitor.instantBarLevels[0], 0.0, accuracy: 0.001)
        XCTAssertEqual(monitor.instantBarLevels[1], 0.5, accuracy: 0.001)
        XCTAssertEqual(monitor.instantBarLevels[2], 1.0, accuracy: 0.001)
        XCTAssertEqual(monitor.recentAverageLevels, monitor.instantBarLevels)
    }

    func testIngestLevels_InstantBarsDoNotAccumulateAcrossFrames() {
        let monitor = AudioLevelMonitor(samplingInterval: 0.03)

        monitor.ingestLevels(averageDB: -18, peakDB: -12, barLevelsDB: [-18, -12, -6])
        monitor.ingestLevels(averageDB: -24, peakDB: -20, barLevelsDB: [-24, -20])

        XCTAssertEqual(monitor.instantBarLevels.count, 2)
        XCTAssertEqual(monitor.recentAverageLevels.count, 2)
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

        monitor.ingestLevels(averageDB: -20, peakDB: -10, barLevelsDB: [-30, -12])
        XCTAssertFalse(monitor.instantBarLevels.isEmpty)

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
        XCTAssertTrue(monitor.instantBarLevels.isEmpty)

        for _ in 0..<4 {
            monitor.ingestLevels(averageDB: -80, peakDB: -80)
        }
        XCTAssertTrue(monitor.isSilenceWarningVisible)
    }
}
