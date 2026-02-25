import XCTest
@testable import MeetingAssistantCore

final class ShortcutCaptureHealthPresentationTests: XCTestCase {
    func testFromReturnsNilWhenResultIsHealthy() {
        let status = ShortcutCaptureHealthStatus(
            scope: .global,
            result: .healthy,
            reasonToken: "",
            requiresGlobalCapture: true,
            accessibilityTrusted: true,
            inputMonitoringTrusted: true,
            eventTapExpected: false,
            eventTapActive: false
        )

        XCTAssertNil(ShortcutCaptureHealthPresentation.from(status: status))
    }

    func testFromReturnsDegradedPresentationForGlobalInputMonitoringDenied() {
        let status = ShortcutCaptureHealthStatus(
            scope: .global,
            result: .degraded,
            reasonToken: "input_monitoring_denied",
            requiresGlobalCapture: true,
            accessibilityTrusted: true,
            inputMonitoringTrusted: false,
            eventTapExpected: false,
            eventTapActive: false
        )

        let presentation = ShortcutCaptureHealthPresentation.from(status: status)
        XCTAssertEqual(presentation?.badgeKey, "settings.shortcuts.health.badge.degraded")
        XCTAssertEqual(presentation?.messageKey, "settings.shortcuts.health.degraded.message.permissions_input_monitoring")
        XCTAssertEqual(presentation?.action, .openInputMonitoringSettings)
        XCTAssertEqual(presentation?.isFallback, false)
    }

    func testFromReturnsFallbackPresentationWhenAssistantEventTapIsInactive() {
        let status = ShortcutCaptureHealthStatus(
            scope: .assistant,
            result: .degraded,
            reasonToken: "event_tap_inactive",
            requiresGlobalCapture: true,
            accessibilityTrusted: true,
            inputMonitoringTrusted: true,
            eventTapExpected: true,
            eventTapActive: false
        )

        let presentation = ShortcutCaptureHealthPresentation.from(status: status)
        XCTAssertEqual(presentation?.badgeKey, "settings.shortcuts.health.badge.fallback")
        XCTAssertEqual(presentation?.titleKey, "settings.shortcuts.health.fallback.title")
        XCTAssertEqual(presentation?.messageKey, "settings.shortcuts.health.fallback.message.generic")
        XCTAssertEqual(presentation?.action, .openInputMonitoringSettings)
        XCTAssertEqual(presentation?.isFallback, true)
    }
}
