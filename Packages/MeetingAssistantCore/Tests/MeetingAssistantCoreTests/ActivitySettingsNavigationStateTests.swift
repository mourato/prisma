import MeetingAssistantCoreDomain
@testable import MeetingAssistantCoreUI
import XCTest

final class ActivitySettingsNavigationStateTests: XCTestCase {
    func testDefaultStateStartsAtRoot() {
        let state = ActivitySettingsNavigationState()

        XCTAssertEqual(state.activeRoute, .root)
        XCTAssertFalse(state.canGoBack)
        XCTAssertNil(state.pendingSheet)
    }

    func testHistoryListControlsSearchVisibility() {
        var state = ActivitySettingsNavigationState(activeRoute: .history)
        XCTAssertTrue(state.isShowingHistoryList)

        state.transcriptionsNavigationHistory.push(.conversation(UUID()))

        XCTAssertFalse(state.isShowingHistoryList)
    }

    func testApplyHistoryOpensHistoryList() {
        var state = ActivitySettingsNavigationState()

        state.apply(.history)

        XCTAssertEqual(state.activeRoute, .history)
        XCTAssertTrue(state.isShowingHistoryList)
    }

    func testBackForwardDelegatesToActiveHistoryRoute() {
        let conversationID = UUID()
        var history = TranscriptionsNavigationHistory()
        history.push(.conversation(conversationID))
        var state = ActivitySettingsNavigationState(
            activeRoute: .history,
            transcriptionsNavigationHistory: history,
        )

        XCTAssertTrue(state.canGoBack)

        state.goBack()

        XCTAssertEqual(state.transcriptionsNavigationHistory.currentRoute, .list)
        XCTAssertTrue(state.canGoForward)
    }

    func testHistoryBackFromListReturnsToRoot() {
        var state = ActivitySettingsNavigationState(activeRoute: .history)

        state.goBack()

        XCTAssertEqual(state.activeRoute, .root)
        XCTAssertTrue(state.canGoForward)
    }

    func testPendingPerformanceSheetFlag() {
        var state = ActivitySettingsNavigationState(pendingSheet: .performance)

        XCTAssertEqual(state.pendingSheet, .performance)
    }
}
