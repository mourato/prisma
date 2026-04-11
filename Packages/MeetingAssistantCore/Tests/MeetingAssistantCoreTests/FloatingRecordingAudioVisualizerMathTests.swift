@testable import MeetingAssistantCoreUI
import CoreGraphics
import XCTest

final class AudioVisualizerMathTests: XCTestCase {
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

    func testTypeWhisperWaveformLevels_WhenAnimationInactive_ReturnsFlatZero() {
        let levels = AudioVisualizerMath.typeWhisperWaveformLevels(
            audioLevel: 0.72,
            barCount: 8,
            isAnimationActive: false
        )

        XCTAssertEqual(levels, Array(repeating: 0.0, count: 8))
    }

    func testTypeWhisperWaveformLevels_StaysWithinNormalizedBounds() {
        let levels = AudioVisualizerMath.typeWhisperWaveformLevels(
            audioLevel: 0.64,
            barCount: 8,
            isAnimationActive: true
        )

        XCTAssertEqual(levels.count, 8)
        XCTAssertTrue(levels.allSatisfy { $0 >= 0.0 && $0 <= 1.0 })
    }

    func testTypeWhisperWaveformLevels_DampensFirstBar() {
        let levels = AudioVisualizerMath.typeWhisperWaveformLevels(
            audioLevel: 0.75,
            barCount: 8,
            isAnimationActive: true
        )

        XCTAssertGreaterThanOrEqual(levels.count, 2)
        XCTAssertLessThan(levels[0], levels[1])
    }

    func testTypeWhisperWaveformLevels_RespondsImmediatelyToLevelDecrease() {
        let highLevels = AudioVisualizerMath.typeWhisperWaveformLevels(
            audioLevel: 0.90,
            barCount: 8,
            isAnimationActive: true
        )
        let lowLevels = AudioVisualizerMath.typeWhisperWaveformLevels(
            audioLevel: 0.20,
            barCount: 8,
            isAnimationActive: true
        )

        XCTAssertEqual(highLevels.count, lowLevels.count)
        XCTAssertGreaterThan(highLevels.reduce(0, +), lowLevels.reduce(0, +))
    }
}
