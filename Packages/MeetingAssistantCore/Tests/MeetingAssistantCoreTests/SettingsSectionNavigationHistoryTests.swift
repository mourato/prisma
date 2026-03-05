@testable import MeetingAssistantCore
import XCTest

final class SettingsSectionNavigationHistoryTests: XCTestCase {
    func testInitialState() {
        let history = SettingsSectionNavigationHistory()

        XCTAssertEqual(history.currentSection, .metrics)
        XCTAssertFalse(history.canGoBack)
        XCTAssertFalse(history.canGoForward)
    }

    func testPushAndTraverseBackAndForward() {
        var history = SettingsSectionNavigationHistory()
        history.push(.general)
        history.push(.audio)

        XCTAssertEqual(history.currentSection, .audio)
        XCTAssertTrue(history.canGoBack)
        XCTAssertFalse(history.canGoForward)

        _ = history.goBack()
        XCTAssertEqual(history.currentSection, .general)
        XCTAssertTrue(history.canGoBack)
        XCTAssertTrue(history.canGoForward)

        _ = history.goBack()
        XCTAssertEqual(history.currentSection, .metrics)
        XCTAssertFalse(history.canGoBack)
        XCTAssertTrue(history.canGoForward)

        _ = history.goForward()
        XCTAssertEqual(history.currentSection, .general)
    }

    func testPushingAfterGoingBackTruncatesForwardHistory() {
        var history = SettingsSectionNavigationHistory()
        history.push(.general)
        history.push(.audio)

        _ = history.goBack()
        XCTAssertEqual(history.currentSection, .general)
        XCTAssertTrue(history.canGoForward)

        history.push(.permissions)
        XCTAssertEqual(history.currentSection, .permissions)
        XCTAssertTrue(history.canGoBack)
        XCTAssertFalse(history.canGoForward)
    }

    func testPushingCurrentSectionIsNoOp() {
        var history = SettingsSectionNavigationHistory()
        history.push(.metrics)

        XCTAssertEqual(history.currentSection, .metrics)
        XCTAssertFalse(history.canGoBack)
        XCTAssertFalse(history.canGoForward)
    }
}
