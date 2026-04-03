@testable import MeetingAssistantCoreUI
import CoreGraphics
import XCTest

final class AudioVisualizerMathTests: XCTestCase {
    func testPresentedLevels_WhenAnimationInactive_ReturnsFlatZero() {
        let levels = AudioVisualizerMath.presentedLevels(
            [0.9, 0.6, 0.3],
            barCount: 6,
            isAnimationActive: false
        )

        XCTAssertEqual(levels, Array(repeating: 0.0, count: 6))
    }

    func testPresentedLevels_ResamplesToRequestedBarCount() {
        let levels = AudioVisualizerMath.presentedLevels(
            [0.0, 0.2, 0.5, 0.9],
            barCount: 8,
            isAnimationActive: true
        )

        XCTAssertEqual(levels.count, 8)
        XCTAssertTrue(levels.allSatisfy { $0 >= 0.0 && $0 <= 1.0 })
        XCTAssertGreaterThan(levels[6], levels[1])
    }

    func testPresentedLevels_UsesZeroWhenSourceIsEmpty() {
        let levels = AudioVisualizerMath.presentedLevels(
            [],
            barCount: 5,
            isAnimationActive: true
        )

        XCTAssertEqual(levels, Array(repeating: 0.0, count: 5))
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

    func testDisplayLevel_BoostsVisualHeightWithoutRevivingSilence() {
        XCTAssertEqual(AudioVisualizerMath.displayLevel(0.0), 0.0, accuracy: 0.0001)

        let quiet = AudioVisualizerMath.displayLevel(0.16)
        let medium = AudioVisualizerMath.displayLevel(0.55)

        XCTAssertLessThan(quiet, 0.17)
        XCTAssertGreaterThan(medium, 0.55)
    }
}
