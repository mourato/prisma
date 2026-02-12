import AppKit
@testable import MeetingAssistantCore
import XCTest

@MainActor
final class AssistantOverlayLifecycleTests: XCTestCase {
    func testFloatingIndicatorRapidShowHideDoesNotCrash() async throws {
        guard NSScreen.main != nil else {
            throw XCTSkip("No main screen available in current test environment")
        }

        let controller = FloatingRecordingIndicatorController()

        for _ in 0..<20 {
            controller.show(mode: .recording)
            controller.hide()
            controller.show(mode: .processing)
            try await Task.sleep(nanoseconds: 5_000_000)
        }

        controller.hide()
        try await Task.sleep(nanoseconds: 250_000_000)

        XCTAssertFalse(controller.isVisible)
    }

    func testAssistantBorderRapidShowHideDoesNotCrash() async throws {
        guard NSScreen.main != nil else {
            throw XCTSkip("No main screen available in current test environment")
        }

        let controller = AssistantScreenBorderController()

        for _ in 0..<20 {
            controller.show()
            controller.hide()
            controller.show()
            try await Task.sleep(nanoseconds: 5_000_000)
        }

        controller.hide()
        try await Task.sleep(nanoseconds: 250_000_000)

        XCTAssertFalse(controller.isVisible)
    }
}
