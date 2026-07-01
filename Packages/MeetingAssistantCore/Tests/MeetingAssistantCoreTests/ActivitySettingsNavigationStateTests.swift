@testable import MeetingAssistantCoreUI
import XCTest

final class ActivitySettingsNavigationStateTests: XCTestCase {
    func testHistoryListControlsSearchVisibility() {
        var state = ActivitySettingsNavigationState(activeRoute: .history)
        XCTAssertTrue(state.isShowingHistoryList)

        state.transcriptionsNavigationHistory.push(.conversation(UUID()))

        XCTAssertFalse(state.isShowingHistoryList)
    }

    func testBackForwardDelegatesToActiveHistoryRoute() {
        let conversationID = UUID()
        var history = TranscriptionsNavigationHistory()
        history.push(.conversation(conversationID))
        var state = ActivitySettingsNavigationState(
            activeRoute: .history,
            transcriptionsNavigationHistory: history
        )

        XCTAssertTrue(state.canGoBack)

        state.goBack()

        XCTAssertEqual(state.transcriptionsNavigationHistory.currentRoute, .list)
        XCTAssertTrue(state.canGoForward)
    }

    func testBackForwardDelegatesToActiveDashboardRoute() {
        var metricsState = SettingsSubpageNavigationState<MetricsDashboardRoute>()
        metricsState.open(.performance)
        var state = ActivitySettingsNavigationState(
            activeRoute: .dashboard,
            metricsNavigationState: metricsState
        )

        XCTAssertTrue(state.canGoBack)

        state.goBack()

        XCTAssertNil(state.metricsNavigationState.currentRoute)
        XCTAssertTrue(state.canGoForward)
    }
}
