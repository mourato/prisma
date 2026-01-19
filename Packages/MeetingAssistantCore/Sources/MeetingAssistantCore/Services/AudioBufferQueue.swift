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
        bufferStorage = Array(repeating: nil, count: capacity)
    }

    // MARK: - Public API

    /// Enqueues a buffer. STRICTLY NON-BLOCKING (spins/waits very briefly).
    /// If full, overwrites the oldest data (Drop Oldest strategy) to maintain real-time currency.
    public func enqueue(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        defer { self.lock.unlock() }

        if count >= capacity {
            // Buffer full: Drop oldest (tail) to make space
            // This ensures we always have fresh data and don't lag behind
            bufferStorage[tail] = nil // Release ref
            tail = (tail + 1) % capacity
            count -= 1
            droppedFrameCount += Int64(buffer.frameLength)
        }

        // Write to head
        bufferStorage[head] = buffer
        head = (head + 1) % capacity
        count += 1
    }

    /// Dequeues a buffer.
    /// - Returns: The next buffer, or nil if empty.
    public func dequeue() -> AVAudioPCMBuffer? {
        lock.lock()
        defer { self.lock.unlock() }

        guard !_isEmpty else {
            return nil
        }

        let buffer = bufferStorage[tail]

        bufferStorage[tail] = nil
        tail = (tail + 1) % capacity
        count -= 1

        return buffer
    }

    // MARK: - Private Helpers

    /// Internal isEmpty check - MUST only be called when lock is already held.
    /// Avoids deadlock since NSLock is non-reentrant.
    private var _isEmpty: Bool {
        isEmpty
    }

    /// Clears the queue.
    public func clear() {
        lock.lock()
        defer { self.lock.unlock() }

        for i in 0..<capacity {
            bufferStorage[i] = nil
        }
        head = 0
        tail = 0
        count = 0
        droppedFrameCount = 0
    }

    /// Returns debug statistics (thread-safe).
    public var stats: (count: Int, dropped: Int64) {
        lock.lock()
        defer { self.lock.unlock() }
        return (count, droppedFrameCount)
    }

    /// Returns whether the queue is empty.
    // swiftlint:disable empty_count
    public var isEmpty: Bool {
        lock.lock()
        defer { self.lock.unlock() }
        return count == 0
    }
    // swiftlint:enable empty_count
}
