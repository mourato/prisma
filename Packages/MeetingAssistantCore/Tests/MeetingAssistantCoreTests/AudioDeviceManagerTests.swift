import AVFoundation
@testable import MeetingAssistantCore
import XCTest

@MainActor
final class AudioDeviceManagerTests: XCTestCase {
    var sut: AudioDeviceManager!

    override func setUp() {
        super.setUp()
        sut = AudioDeviceManager()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func testInitialState() {
        // Just verify it can be initialized and doesn't crash
        XCTAssertNotNil(sut.availableInputDevices)
    }

    func testIsDeviceAvailable() {
        // This might be tricky in a test environment without real audio devices,
        // but we can at least check if it returns a boolean.
        let isAvailable = sut.isDeviceAvailable("some-random-id")
        XCTAssertFalse(isAvailable)
    }
}
