@testable import MeetingAssistantCoreUI
import XCTest

final class ActivityHeatmapMonthMarkerTests: XCTestCase {
    func testResolveVisibleMonthMarkers_SkipsCollidingLabels() {
        let markers = [
            ActivityHeatmapMonthMarker(id: 0, label: "Mar", xOffset: 0),
            ActivityHeatmapMonthMarker(id: 1, label: "Apr", xOffset: 24),
            ActivityHeatmapMonthMarker(id: 2, label: "May", xOffset: 48),
            ActivityHeatmapMonthMarker(id: 3, label: "Jun", xOffset: 84),
        ]

        let visibleMarkers = ActivityHeatmap.resolveVisibleMonthMarkers(
            markers,
            estimatedLabelWidth: 24,
            minimumSpacing: 6
        )

        XCTAssertEqual(visibleMarkers.map(\.label), ["Mar", "May", "Jun"])
    }

    func testResolveVisibleMonthMarkers_KeepsFirstMarkerWhenRangeStartsMidMonth() {
        let markers = [
            ActivityHeatmapMonthMarker(id: 0, label: "Mar", xOffset: 0),
            ActivityHeatmapMonthMarker(id: 4, label: "Apr", xOffset: 60),
        ]

        let visibleMarkers = ActivityHeatmap.resolveVisibleMonthMarkers(markers)

        XCTAssertEqual(visibleMarkers.map(\.label), ["Mar", "Apr"])
    }
}
