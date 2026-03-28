@testable import MeetingAssistantCoreUI
import CoreGraphics
import XCTest

final class AudioVisualizerMathTests: XCTestCase {
    func testShapedLevel_BelowGateIsHidden() {
        XCTAssertEqual(AudioVisualizerMath.shapedLevel(0.0), 0.0, accuracy: 0.0001)
        XCTAssertEqual(AudioVisualizerMath.shapedLevel(0.2), 0.0, accuracy: 0.0001)
    }

    func testShapedLevel_AboveGateGrowsNonlinearly() {
        let soft = AudioVisualizerMath.shapedLevel(0.35)
        let firm = AudioVisualizerMath.shapedLevel(0.75)

        XCTAssertGreaterThan(firm, soft)
        XCTAssertLessThan(soft, 0.2)
    }

    func testInstantLevels_RespectsBarCountAndBounds() {
        let snapshot: [Double] = [0.0, 0.15, 0.4, 0.8, 0.3, 0.6, 0.95, 0.2, 0.5]
        let levels = AudioVisualizerMath.instantLevels(
            snapshotLevels: snapshot,
            fallbackLevel: 0.0,
            barCount: 6,
            isAnimationActive: true
        )

        XCTAssertEqual(levels.count, 6)
        XCTAssertTrue(levels.allSatisfy { $0 >= 0.0 && $0 <= 1.0 })
    }

    func testInstantLevels_WhenAnimationInactive_ReturnsFlatZero() {
        let levels = AudioVisualizerMath.instantLevels(
            snapshotLevels: [0.9, 0.9, 0.9],
            fallbackLevel: 0.9,
            barCount: 6,
            isAnimationActive: false
        )

        XCTAssertEqual(levels, Array(repeating: 0.0, count: 6))
    }

    func testInstantLevels_AppliesCenterBoost() {
        let levels = AudioVisualizerMath.instantLevels(
            snapshotLevels: Array(repeating: 0.75, count: 5),
            fallbackLevel: 0.75,
            barCount: 5,
            isAnimationActive: true
        )

        XCTAssertGreaterThan(levels[2], levels[0])
        XCTAssertGreaterThan(levels[2], levels[4])
    }

    func testBarHeight_StaysWithinMinAndMaxBounds() {
        let minHeight: CGFloat = 2
        let maxHeight: CGFloat = 24

        for level in stride(from: 0.0, through: 1.0, by: 0.05) {
            let height = AudioVisualizerMath.barHeight(
                level: level,
                minHeight: minHeight,
                maxHeight: maxHeight
            )
            XCTAssertGreaterThanOrEqual(height, minHeight)
            XCTAssertLessThanOrEqual(height, maxHeight)
        }
    }

    func testDisplayLevel_BoostsVisualHeightWithoutLeakingLowSignal() {
        XCTAssertEqual(AudioVisualizerMath.displayLevel(0.0), 0.0, accuracy: 0.0001)

        let quiet = AudioVisualizerMath.displayLevel(0.16)
        let medium = AudioVisualizerMath.displayLevel(0.55)

        XCTAssertLessThan(quiet, 0.17)
        XCTAssertGreaterThan(medium, 0.55)
    }
}
