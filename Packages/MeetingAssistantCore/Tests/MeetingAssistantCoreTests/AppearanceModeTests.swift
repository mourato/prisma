import AppKit
@testable import MeetingAssistantCore
import XCTest

final class AppearanceModeTests: XCTestCase {
    func testAppearanceModeMapsToAppKitAppearanceNames() {
        XCTAssertEqual(AppearanceMode.light.nsAppearanceName, .aqua)
        XCTAssertNil(AppearanceMode.system.nsAppearanceName)
        XCTAssertEqual(AppearanceMode.dark.nsAppearanceName, .darkAqua)
    }
}
