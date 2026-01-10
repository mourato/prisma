@preconcurrency import AVFoundation
import Foundation
import os.lock

/// A thread-safe, fixed-size Circular Buffer (Ring Buffer) for `AVAudioPCMBuffer`.
/// Designed for high-performance audio bridging between `ScreenCaptureKit` (Push) and `AVAudioSourceNode` (Pull).
/// Uses `OSAllocatedUnfairLock` to minimize blocking overhead on the audio thread.
public final class AudioBufferQueue: @unchecked Sendable {
    // MARK: - State

    private let lock = OSAllocatedUnfairLock()

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
        self.lock.withLock {
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
    }

    /// Dequeues a buffer.
    /// - Returns: The next buffer, or nil if empty.
    public func dequeue() -> AVAudioPCMBuffer? {
        self.lock.withLock {
            // #region agent log
            let logPath = "/Users/usuario/Documents/Repos/my-meeting-assistant/.cursor/debug.log"
            func writeLog(_ data: [String: Any]) {
                if let json = try? JSONSerialization.data(withJSONObject: data),
                   let jsonStr = String(data: json, encoding: .utf8) {
                    if let handle = FileHandle(forWritingAtPath: logPath) {
                        handle.seekToEndOfFile()
                        if let data = (jsonStr + "\n").data(using: .utf8) {
                            handle.write(data)
                        }
                        try? handle.close()
                    } else {
                        try? (jsonStr + "\n").write(toFile: logPath, atomically: true, encoding: .utf8)
                    }
                }
            }
            // #endregion
            
            guard !self.isEmpty else {
                // #region agent log
                writeLog([
                    "sessionId": "debug-session",
                    "runId": "run1",
                    "hypothesisId": "D",
                    "location": "AudioBufferQueue.swift:59",
                    "message": "Queue empty",
                    "data": [
                        "count": self.count
                    ],
                    "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
                ])
                // #endregion
                return nil
            }

            let buffer = self.bufferStorage[self.tail]
            
            // #region agent log
            writeLog([
                "sessionId": "debug-session",
                "runId": "run1",
                "hypothesisId": "D",
                "location": "AudioBufferQueue.swift:61",
                "message": "Buffer dequeued",
                "data": [
                    "bufferIsNil": buffer == nil,
                    "frameLength": buffer?.frameLength ?? 0,
                    "formatChannelCount": buffer?.format.channelCount ?? 0,
                    "formatSampleRate": buffer?.format.sampleRate ?? 0,
                    "hasFloatChannelData": buffer?.floatChannelData != nil,
                    "tail": self.tail,
                    "count": self.count
                ],
                "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
            ])
            // #endregion
            
            // self.bufferStorage[self.tail] = nil // Avoid dealloc on audio thread
            self.tail = (self.tail + 1) % self.capacity
            self.count -= 1

            return buffer
        }
    }

    /// Clears the queue.
    public func clear() {
        self.lock.withLock {
            for i in 0..<self.capacity {
                self.bufferStorage[i] = nil
            }
            self.head = 0
            self.tail = 0
            self.count = 0
            self.droppedFrameCount = 0
        }
    }

    /// Returns debug statistics (thread-safe).
    public var stats: (count: Int, dropped: Int64) {
        self.lock.withLock {
            (self.count, self.droppedFrameCount)
        }
    }

    /// Returns whether the queue is empty.
    // swiftlint:disable empty_count
    public var isEmpty: Bool {
        self.lock.withLock {
            self.count == 0
        }
    }
    // swiftlint:enable empty_count
}
