@preconcurrency import AVFoundation
@testable import MeetingAssistantCore
import XCTest

final class AudioBufferQueueTests: XCTestCase {
    var sut: AudioBufferQueue!

    override func setUp() {
        super.setUp()
        self.sut = AudioBufferQueue(capacity: 5)
    }

    override func tearDown() {
        self.sut = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialState_IsEmpty() {
        XCTAssertTrue(self.sut.isEmpty)
    }

    func testInitialState_StatsAreZero() {
        let stats = self.sut.stats

        XCTAssertEqual(stats.count, 0)
        XCTAssertEqual(stats.dropped, 0)
    }

    func testInitialState_WithCustomCapacity() {
        let customQueue = AudioBufferQueue(capacity: 10)

        XCTAssertTrue(customQueue.isEmpty)
        XCTAssertEqual(customQueue.stats.count, 0)
    }

    // MARK: - Enqueue

    func testEnqueue_IncreasesCount() throws {
        let buffer = try createTestBuffer(frameCount: 512)

        self.sut.enqueue(buffer)

        XCTAssertFalse(self.sut.isEmpty)
        XCTAssertEqual(self.sut.stats.count, 1)
    }

    func testEnqueue_MultipleBuffers_IncreasesCount() throws {
        let buffer1 = try createTestBuffer(frameCount: 512)
        let buffer2 = try createTestBuffer(frameCount: 512)
        let buffer3 = try createTestBuffer(frameCount: 512)

        self.sut.enqueue(buffer1)
        self.sut.enqueue(buffer2)
        self.sut.enqueue(buffer3)

        XCTAssertEqual(self.sut.stats.count, 3)
    }

    // MARK: - Dequeue

    func testDequeue_WhenEmpty_ReturnsNil() {
        let result = self.sut.dequeue()

        XCTAssertNil(result)
    }

    func testDequeue_ReturnsBuffer() throws {
        let buffer = try createTestBuffer(frameCount: 512)
        self.sut.enqueue(buffer)

        let result = self.sut.dequeue()

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.frameLength, buffer.frameLength)
    }

    func testDequeue_EmptyQueueAfterDequeuing() throws {
        let buffer = try createTestBuffer(frameCount: 512)
        self.sut.enqueue(buffer)

        _ = self.sut.dequeue()

        XCTAssertTrue(self.sut.isEmpty)
    }

    func testDequeue_MultipleBuffers_FIFOOrder() throws {
        let buffer1 = try createTestBuffer(frameCount: 256)
        let buffer2 = try createTestBuffer(frameCount: 512)
        let buffer3 = try createTestBuffer(frameCount: 1024)

        self.sut.enqueue(buffer1)
        self.sut.enqueue(buffer2)
        self.sut.enqueue(buffer3)

        let result1 = self.sut.dequeue()
        let result2 = self.sut.dequeue()
        let result3 = self.sut.dequeue()

        XCTAssertEqual(result1?.frameLength, 256)
        XCTAssertEqual(result2?.frameLength, 512)
        XCTAssertEqual(result3?.frameLength, 1024)
    }

    // MARK: - Buffer Overflow (Drop Oldest)

    func testEnqueue_WhenFull_DropsOldest() throws {
        let buffers = try (0..<6).map { try createTestBuffer(frameCount: AVAudioFrameCount($0 + 1) * 256) }

        for buffer in buffers {
            self.sut.enqueue(buffer)
        }

        XCTAssertEqual(self.sut.stats.count, 5)
    }

    func testEnqueue_WhenFull_DropsOldestAndIncrementsDroppedCounter() throws {
        let buffer = try createTestBuffer(frameCount: 512)

        // Fill the queue to capacity
        for _ in 0..<5 {
            self.sut.enqueue(buffer)
        }

        let statsBeforeOverflow = self.sut.stats

        // Add one more to trigger overflow
        self.sut.enqueue(buffer)

        let statsAfterOverflow = self.sut.stats

        XCTAssertEqual(statsAfterOverflow.count, 5)
        XCTAssertGreaterThan(statsAfterOverflow.dropped, statsBeforeOverflow.dropped)
    }

    // MARK: - Clear

    func testClear_ResetsQueue() throws {
        let buffer = try createTestBuffer(frameCount: 512)
        self.sut.enqueue(buffer)

        self.sut.clear()

        XCTAssertTrue(self.sut.isEmpty)
        XCTAssertEqual(self.sut.stats.count, 0)
        XCTAssertEqual(self.sut.stats.dropped, 0)
    }

    func testClear_WhenEmpty_RemainsEmpty() {
        self.sut.clear()

        XCTAssertTrue(self.sut.isEmpty)
        XCTAssertEqual(self.sut.stats.count, 0)
    }

    // MARK: - Thread Safety

    func testConcurrentEnqueueAndDequeue_DoesNotCrash() throws {
        let buffer = try createTestBuffer(frameCount: 1024)
        let iterations = 100
        let expectation = self.expectation(description: "Concurrent access")
        expectation.expectedFulfillmentCount = iterations * 2

        for _ in 0..<iterations {
            DispatchQueue.global().async {
                self.sut.enqueue(buffer)
                expectation.fulfill()
            }

            DispatchQueue.global().async {
                _ = self.sut.dequeue()
                _ = self.sut.isEmpty
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)
        // If we get here without crash, the test passes
    }

    func testConcurrentClearAndAccess_DoesNotCrash() throws {
        let buffer = try createTestBuffer(frameCount: 512)
        let iterations = 50
        let expectation = self.expectation(description: "Concurrent clear and access")
        expectation.expectedFulfillmentCount = iterations * 2

        // Pre-populate queue
        for _ in 0..<10 {
            self.sut.enqueue(buffer)
        }

        for _ in 0..<iterations {
            DispatchQueue.global().async {
                self.sut.clear()
                expectation.fulfill()
            }

            DispatchQueue.global().async {
                _ = self.sut.stats
                _ = self.sut.isEmpty
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Stats

    func testStats_ReflectsCorrectCount() throws {
        let buffer = try createTestBuffer(frameCount: 512)

        XCTAssertEqual(self.sut.stats.count, 0)

        self.sut.enqueue(buffer)
        XCTAssertEqual(self.sut.stats.count, 1)

        self.sut.enqueue(buffer)
        XCTAssertEqual(self.sut.stats.count, 2)

        _ = self.sut.dequeue()
        XCTAssertEqual(self.sut.stats.count, 1)
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
