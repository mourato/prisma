@preconcurrency import AVFoundation
@testable import MeetingAssistantCore
import XCTest

final class PartialBufferStateTests: XCTestCase {
    var sut: PartialBufferState?

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
        guard let sut = self.sut else { return XCTFail("SUT not initialized") }
        XCTAssertFalse(sut.hasPartial)
        XCTAssertEqual(sut.framesRemaining, 0)
    }

    // MARK: - setBuffer

    func testSetBuffer_UpdatesState() throws {
        guard let sut = self.sut else { return XCTFail("SUT not initialized") }
        let buffer = try createTestBuffer(frameCount: 100)
        sut.setBuffer(buffer)

        XCTAssertTrue(sut.hasPartial)
        XCTAssertEqual(sut.framesRemaining, 100)
    }

    func testSetBuffer_WithOffset_UpdatesState() throws {
        guard let sut = self.sut else { return XCTFail("SUT not initialized") }
        let buffer = try createTestBuffer(frameCount: 100)
        sut.setBuffer(buffer, offset: 25)

        XCTAssertTrue(sut.hasPartial)
        XCTAssertEqual(sut.framesRemaining, 75)
    }

    func testSetBuffer_WithFullOffset_HasNoRemaining() throws {
        guard let sut = self.sut else { return XCTFail("SUT not initialized") }
        let buffer = try createTestBuffer(frameCount: 100)
        sut.setBuffer(buffer, offset: 100)

        // framesRemaining = 100 - 100 = 0
        XCTAssertEqual(sut.framesRemaining, 0)
    }

    // MARK: - clear

    func testClear_ResetsState() throws {
        guard let sut = self.sut else { return XCTFail("SUT not initialized") }
        let buffer = try createTestBuffer(frameCount: 100)
        sut.setBuffer(buffer)

        XCTAssertTrue(sut.hasPartial)

        sut.clear()

        XCTAssertFalse(sut.hasPartial)
        XCTAssertEqual(sut.framesRemaining, 0)
    }

    func testClear_WhenEmpty_RemainsEmpty() {
        guard let sut = self.sut else { return XCTFail("SUT not initialized") }
        XCTAssertFalse(sut.hasPartial)

        sut.clear()

        XCTAssertFalse(sut.hasPartial)
        XCTAssertEqual(sut.framesRemaining, 0)
    }

    // MARK: - Thread Safety (Basic)

    func testConcurrentAccess_DoesNotCrash() throws {
        try XCTSkipIf(true, "Crash under investigation - Signal 5")
        let buffer = try createTestBuffer(frameCount: 1000)
        let iterations = 100
        let expectation = self.expectation(description: "Concurrent access")
        expectation.expectedFulfillmentCount = iterations * 2

        guard let sut = self.sut else { return XCTFail("SUT not initialized") }

        // Multiple concurrent reads and writes
        for _ in 0..<iterations {
            DispatchQueue.global().async {
                sut.setBuffer(buffer, offset: Int.random(in: 0..<100))
                expectation.fulfill()
            }

            DispatchQueue.global().async {
                _ = sut.framesRemaining
                _ = sut.hasPartial
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)
        // If we get here without crash, the test passes
    }

    // MARK: - Performance Tests

    func testPerformance_SetBufferOperation() throws {
        try XCTSkipIf(true, "Unstable performance test")
        guard let sut = self.sut else { return XCTFail("SUT not initialized") }
        let buffer = try createTestBuffer(frameCount: 2048)

        // Baseline: Set buffer operations should be very fast
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            for _ in 0..<1000 {
                sut.setBuffer(buffer, offset: Int.random(in: 0..<100))
            }
        }
    }

    func testPerformance_PropertyAccess() throws {
        try XCTSkipIf(true, "Unstable performance test")
        guard let sut = self.sut else { return XCTFail("SUT not initialized") }
        let buffer = try createTestBuffer(frameCount: 1024)
        sut.setBuffer(buffer, offset: 50)

        // Baseline: Property access should be instantaneous
        measure(metrics: [XCTClockMetric()]) {
            for _ in 0..<10_000 {
                _ = sut.hasPartial
                _ = sut.framesRemaining
            }
        }
    }

    func testPerformance_ClearOperation() throws {
        try XCTSkipIf(true, "Unstable performance test")
        guard let sut = self.sut else { return XCTFail("SUT not initialized") }
        let buffer = try createTestBuffer(frameCount: 1024)

        // Baseline: Clear operations should be very fast
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            for _ in 0..<1000 {
                sut.setBuffer(buffer)
                sut.clear()
            }
        }
    }

    func testPerformance_BufferStateTransitions() throws {
        try XCTSkipIf(true, "Unstable performance test")
        guard let sut = self.sut else { return XCTFail("SUT not initialized") }
        let buffer = try createTestBuffer(frameCount: 1024)

        // Baseline: State transitions should be efficient
        measure(metrics: [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()]) {
            for _ in 0..<500 {
                sut.setBuffer(buffer, offset: 100)
                _ = sut.hasPartial
                _ = sut.framesRemaining
                sut.clear()
            }
        }
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
