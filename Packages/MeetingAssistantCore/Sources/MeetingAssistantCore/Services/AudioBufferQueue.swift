@preconcurrency import AVFoundation
import Foundation

/// A thread-safe, fixed-size Circular Buffer (Ring Buffer) for `AVAudioPCMBuffer`.
/// Designed for high-performance audio bridging between `ScreenCaptureKit` (Push) and `AVAudioSourceNode` (Pull).
/// Uses `NSLock` for thread safety.
public final class AudioBufferQueue: @unchecked Sendable {
    // MARK: - State

    private let lock = NSLock()

    // Fixed buffer storage
    private var bufferStorage: [AVAudioPCMBuffer?]
    private let capacity: Int

    // Ring indices
    private var head: Int = 0 // Write index
    private var tail: Int = 0 // Read index
    private var count: Int = 0 // Current items

    private var droppedFrameCount: Int64 = 0

    // MARK: - Lifecycle

    /// Initializes a ring buffer with a specific capacity (number of chunks).
    /// - Parameter capacity: Maximum number of buffers to hold. Default is 50 (~5-10s depending on buffer size).
    public init(capacity: Int = 50) {
        self.capacity = capacity
        self.bufferStorage = Array(repeating: nil, count: capacity)
    }

    // MARK: - Public API

    /// Enqueues a buffer. STRICTLY NON-BLOCKING (spins/waits very briefly).
    /// If full, overwrites the oldest data (Drop Oldest strategy) to maintain real-time currency.
    public func enqueue(_ buffer: AVAudioPCMBuffer) {
        self.lock.lock()
        defer { self.lock.unlock() }

        if self.count >= self.capacity {
            // Buffer full: Drop oldest (tail) to make space
            // This ensures we always have fresh data and don't lag behind
            self.bufferStorage[self.tail] = nil // Release ref
            self.tail = (self.tail + 1) % self.capacity
            self.count -= 1
            self.droppedFrameCount += Int64(buffer.frameLength)
        }

        // Write to head
        self.bufferStorage[self.head] = buffer
        self.head = (self.head + 1) % self.capacity
        self.count += 1
    }

    /// Dequeues a buffer.
    /// - Returns: The next buffer, or nil if empty.
    public func dequeue() -> AVAudioPCMBuffer? {
        self.lock.lock()
        defer { self.lock.unlock() }

        guard !self.isEmpty else {
            return nil
        }

        let buffer = self.bufferStorage[self.tail]

        self.bufferStorage[self.tail] = nil
        self.tail = (self.tail + 1) % self.capacity
        self.count -= 1

        return buffer
    }

    /// Clears the queue.
    public func clear() {
        self.lock.lock()
        defer { self.lock.unlock() }

        for i in 0..<self.capacity {
            self.bufferStorage[i] = nil
        }
        self.head = 0
        self.tail = 0
        self.count = 0
        self.droppedFrameCount = 0
    }

    /// Returns debug statistics (thread-safe).
    public var stats: (count: Int, dropped: Int64) {
        self.lock.lock()
        defer { self.lock.unlock() }
        return (self.count, self.droppedFrameCount)
    }

    /// Returns whether the queue is empty.
    // swiftlint:disable empty_count
    public var isEmpty: Bool {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.count == 0
    }
    // swiftlint:enable empty_count
}
