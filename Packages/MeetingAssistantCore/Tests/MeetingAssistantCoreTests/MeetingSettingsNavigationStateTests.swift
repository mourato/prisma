@testable import MeetingAssistantCore
import XCTest

final class MeetingSettingsNavigationStateTests: XCTestCase {
    func testInitialState() {
        let state = MeetingSettingsNavigationState()

        XCTAssertEqual(state.currentRoute, .root)
        XCTAssertFalse(state.canGoBack)
        XCTAssertFalse(state.canGoForward)
    }

    func testBackMovesToRootAndPreservesForwardRoute() {
        var state = MeetingSettingsNavigationState(currentRoute: .monitoringTargets)

        _ = state.goBack()

        XCTAssertEqual(state.currentRoute, .root)
        XCTAssertFalse(state.canGoBack)
        XCTAssertTrue(state.canGoForward)
        XCTAssertEqual(state.forwardRoute, .monitoringTargets)
    }

    func testForwardRestoresMonitoringRouteAndClearsForwardRoute() {
        var state = MeetingSettingsNavigationState(
            currentRoute: .root,
            forwardRoute: .monitoringTargets
        )

        _ = state.goForward()

        XCTAssertEqual(state.currentRoute, .monitoringTargets)
        XCTAssertTrue(state.canGoBack)
        XCTAssertFalse(state.canGoForward)
        XCTAssertNil(state.forwardRoute)
    }
}
