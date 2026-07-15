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

    func testBackFromConversationReturnsToHistoryList() {
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
        XCTAssertEqual(state.activeRoute, .history)
        XCTAssertTrue(state.canGoBack)
    }

    func testHistoryBackFromListReturnsToRoot() {
        var state = ActivitySettingsNavigationState(activeRoute: .history)

        state.goBack()

        XCTAssertEqual(state.activeRoute, .root)
        XCTAssertFalse(state.canGoBack)
    }

    func testPendingPerformanceSheetFlag() {
        var state = ActivitySettingsNavigationState(pendingSheet: .performance)

        XCTAssertEqual(state.pendingSheet, .performance)
    }
}
