@preconcurrency import AVFoundation
@testable import MeetingAssistantCore
import XCTest

final class PartialBufferStateTests: XCTestCase {
    var sut: PartialBufferState!

    override func setUp() {
        super.setUp()
        self.sut = PartialBufferState()
    }

    override func tearDown() {
        self.sut = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialState_HasNoPartialBuffer() {
        XCTAssertFalse(self.sut.hasPartial)
        XCTAssertEqual(self.sut.framesRemaining, 0)
    }

    // MARK: - setBuffer

    func testSetBuffer_UpdatesState() throws {
        let buffer = try createTestBuffer(frameCount: 100)
        self.sut.setBuffer(buffer)

        XCTAssertTrue(self.sut.hasPartial)
        XCTAssertEqual(self.sut.framesRemaining, 100)
    }

    func testSetBuffer_WithOffset_UpdatesState() throws {
        let buffer = try createTestBuffer(frameCount: 100)
        self.sut.setBuffer(buffer, offset: 25)

        XCTAssertTrue(self.sut.hasPartial)
        XCTAssertEqual(self.sut.framesRemaining, 75)
    }

    func testSetBuffer_WithFullOffset_HasNoRemaining() throws {
        let buffer = try createTestBuffer(frameCount: 100)
        self.sut.setBuffer(buffer, offset: 100)

        // framesRemaining = 100 - 100 = 0
        XCTAssertEqual(self.sut.framesRemaining, 0)
    }

    // MARK: - clear

    func testClear_ResetsState() throws {
        let buffer = try createTestBuffer(frameCount: 100)
        self.sut.setBuffer(buffer)

        XCTAssertTrue(self.sut.hasPartial)

        self.sut.clear()

        XCTAssertFalse(self.sut.hasPartial)
        XCTAssertEqual(self.sut.framesRemaining, 0)
    }

    func testClear_WhenEmpty_RemainsEmpty() {
        XCTAssertFalse(self.sut.hasPartial)

        self.sut.clear()

        XCTAssertFalse(self.sut.hasPartial)
        XCTAssertEqual(self.sut.framesRemaining, 0)
    }

    // MARK: - Thread Safety (Basic)

    func testConcurrentAccess_DoesNotCrash() throws {
        let buffer = try createTestBuffer(frameCount: 1000)
        let iterations = 100
        let expectation = self.expectation(description: "Concurrent access")
        expectation.expectedFulfillmentCount = iterations * 2

        // Multiple concurrent reads and writes
        for _ in 0..<iterations {
            DispatchQueue.global().async {
                self.sut.setBuffer(buffer, offset: Int.random(in: 0..<100))
                expectation.fulfill()
            }

            DispatchQueue.global().async {
                _ = self.sut.framesRemaining
                _ = self.sut.hasPartial
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)
        // If we get here without crash, the test passes
    }

    // MARK: - Helpers

    private func createTestBuffer(frameCount: AVAudioFrameCount) throws -> AVAudioPCMBuffer {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48_000,
            channels: 2,
            interleaved: false
        ) else {
            throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create format"])
        }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw NSError(domain: "Test", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create buffer"])
        }

        buffer.frameLength = frameCount

        // Fill with test data
        if let channelData = buffer.floatChannelData {
            for ch in 0..<Int(format.channelCount) {
                for frame in 0..<Int(frameCount) {
                    channelData[ch][frame] = Float(frame) / Float(frameCount)
                }
            }
        }

        return buffer
    }
}
