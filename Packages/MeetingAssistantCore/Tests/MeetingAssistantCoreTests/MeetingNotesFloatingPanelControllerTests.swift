@testable import MeetingAssistantCoreUI
import AppKit
import XCTest

@MainActor
final class MeetingNotesFloatingPanelControllerTests: XCTestCase {
    func testClampedPanelFrame_LimitsHeightToNinetyPercentOfVisibleFrame() {
        let visibleFrame = NSRect(x: 0, y: 50, width: 1440, height: 1000)
        let maxHeight = floor(visibleFrame.height * MeetingNotesFloatingPanelController.maximumScreenHeightRatio)
        let frame = NSRect(x: 120, y: 100, width: 420, height: 980)

        let clamped = MeetingNotesFloatingPanelController.clampedPanelFrame(
            frame,
            within: visibleFrame,
            maxHeight: maxHeight
        )

        XCTAssertEqual(clamped.height, maxHeight, accuracy: 0.001)
        XCTAssertEqual(clamped.origin.y, 100, accuracy: 0.001)
    }

    func testClampedPanelFrame_RepositionsWhenClampedHeightWouldOverflowTopEdge() {
        let visibleFrame = NSRect(x: 0, y: 50, width: 1440, height: 1000)
        let maxHeight = floor(visibleFrame.height * MeetingNotesFloatingPanelController.maximumScreenHeightRatio)
        let frame = NSRect(x: 120, y: 300, width: 420, height: 980)

        let clamped = MeetingNotesFloatingPanelController.clampedPanelFrame(
            frame,
            within: visibleFrame,
            maxHeight: maxHeight
        )

        XCTAssertEqual(clamped.height, maxHeight, accuracy: 0.001)
        XCTAssertEqual(clamped.origin.y, visibleFrame.maxY - maxHeight, accuracy: 0.001)
    }
}
