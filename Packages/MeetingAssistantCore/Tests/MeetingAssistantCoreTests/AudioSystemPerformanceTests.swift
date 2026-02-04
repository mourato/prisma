@preconcurrency import AVFoundation
@testable import MeetingAssistantCore
import XCTest

/// Performance tests for the audio system.
/// Isolated in a separate file to allow independent execution.
///
/// ⚠️ IMPORTANT: These tests must be run via Xcode, NOT swift test.
/// The SPM test runner hangs when running these tests.
///
/// To run in Xcode:
/// 1. Open the project in Xcode
/// 2. Select the test target
/// 3. Run tests with Cmd+U or navigate to AudioSystemPerformanceTests
///
/// To enable in CI (if SPM issues are resolved), set:
/// RUN_PERFORMANCE_TESTS=1
final class AudioSystemPerformanceTests: XCTestCase {
    var bufferQueue: AudioBufferQueue!

    override func setUp() {
        super.setUp()
        bufferQueue = AudioBufferQueue(capacity: 50)
    }

    override func tearDown() {
        bufferQueue?.clear()
        bufferQueue = nil
        super.tearDown()
    }

    // MARK: - Performance Tests

    /// Tests enqueue/dequeue performance with 1000 operations
    func testPerformance_BufferQueueEnqueueDequeue() throws {
        try skipIfCIEnvironment()
        let buffer = try createTestBuffer(frameCount: 2048)

        measure {
            for _ in 0..<1000 {
                self.bufferQueue.enqueue(buffer)
                _ = self.bufferQueue.dequeue()
            }
        }
    }

    /// Tests high throughput with 100 buffers
    func testPerformance_BufferQueueHighThroughput() throws {
        try skipIfCIEnvironment()
        let buffers = try (0..<100).map { _ in try self.createTestBuffer(frameCount: 1_024) }

        measure {
            for buffer in buffers {
                self.bufferQueue.enqueue(buffer)
            }

            while !self.bufferQueue.isEmpty {
                _ = self.bufferQueue.dequeue()
            }
        }
    }

    /// Tests overflow handling with 200 buffers on a capacity-10 queue
    func testPerformance_BufferQueueOverflowHandling() throws {
        try skipIfCIEnvironment()
        let smallQueue = AudioBufferQueue(capacity: 10)
        let buffer = try createTestBuffer(frameCount: 1_024)

        measure {
            for _ in 0..<200 {
                smallQueue.enqueue(buffer)
            }
        }

        XCTAssertEqual(smallQueue.stats.count, 10, "Should maintain capacity")
        XCTAssertGreaterThan(smallQueue.stats.dropped, 0, "Should have dropped buffers")
    }

    /// Tests concurrent enqueue/dequeue operations
    func testPerformance_ConcurrentOperations() throws {
        try skipIfCIEnvironment()
        let buffer = try createTestBuffer(frameCount: 512)
        let iterations = 100
        let queue = bufferQueue! // Capture local reference

        measure {
            let group = DispatchGroup()

            for _ in 0..<iterations {
                group.enter()
                DispatchQueue.global().async {
                    queue.enqueue(buffer)
                    group.leave()
                }

                group.enter()
                DispatchQueue.global().async {
                    _ = queue.dequeue()
                    group.leave()
                }
            }

            group.wait()
        }
    }

    /// Tests stats access performance
    func testPerformance_StatsAccess() throws {
        try skipIfCIEnvironment()
        let buffer = try createTestBuffer(frameCount: 512)

        for _ in 0..<25 {
            bufferQueue.enqueue(buffer)
        }

        measure {
            for _ in 0..<10000 {
                _ = self.bufferQueue.stats
                _ = self.bufferQueue.isEmpty
            }
        }
    }

    /// Tests clear operation performance
    func testPerformance_ClearOperation() throws {
        try skipIfCIEnvironment()
        let buffer = try createTestBuffer(frameCount: 512)

        measure {
            for _ in 0..<100 {
                for _ in 0..<50 {
                    self.bufferQueue.enqueue(buffer)
                }
                self.bufferQueue.clear()
            }
        }
    }

    /// Tests buffer creation performance (baseline)
    func testPerformance_BufferCreation() throws {
        try skipIfCIEnvironment()

        measure {
            for _ in 0..<100 {
                _ = try? self.createTestBuffer(frameCount: 1_024)
            }
        }
    }

    // MARK: - Skip Helper

    private func skipIfCIEnvironment() throws {
        // Skip by default unless explicitly enabled
        // SPM test runner hangs - run via Xcode instead
        let isEnabled = ProcessInfo.processInfo.environment["RUN_PERFORMANCE_TESTS"] != nil
        try XCTSkipUnless(isEnabled, "Performance tests disabled. Run via Xcode or set RUN_PERFORMANCE_TESTS=1")
    }

    // MARK: - Buffer Helpers

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

        if let channelData = buffer.floatChannelData {
            for ch in 0..<Int(format.channelCount) {
                for frame in 0..<Int(frameCount) {
                    channelData[ch][frame] = sin(Float(frame) * 0.01)
                }
            }
        }

        return buffer
    }
}
