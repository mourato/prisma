@preconcurrency import AVFoundation
import Foundation
import os.lock

/// Thread-safe tracker for partially consumed audio buffers.
/// Used by `AVAudioSourceNode` to preserve frames when a buffer is larger than
/// the requested `frameCount`, ensuring no audio data is lost between render cycles.
///
/// This class is `@unchecked Sendable` because it protects all mutable state
/// with `OSAllocatedUnfairLock`, which is safe for audio thread usage.
public final class PartialBufferState: @unchecked Sendable {
    // MARK: - State

    private let lock = OSAllocatedUnfairLock()

    private var buffer: AVAudioPCMBuffer?
    private var readOffset: Int = 0

    // MARK: - Lifecycle

    public init() {}

    // MARK: - Public API

    /// Number of frames remaining in the current partial buffer.
    public var framesRemaining: Int {
        self.lock.withLock {
            guard let buffer else { return 0 }
            return Int(buffer.frameLength) - self.readOffset
        }
    }

    /// Whether there is a partial buffer with unconsumed frames.
    public var hasPartial: Bool {
        self.framesRemaining > 0
    }

    /// Sets a new buffer to consume from.
    /// - Parameters:
    ///   - buffer: The audio buffer to consume from.
    ///   - offset: Starting offset (default 0).
    public func setBuffer(_ buffer: AVAudioPCMBuffer, offset: Int = 0) {
        self.lock.withLock {
            self.buffer = buffer
            self.readOffset = offset
        }
    }

    /// Consumes frames from the current partial buffer into the destination buffer list.
    /// - Parameters:
    ///   - maxFrames: Maximum number of frames to consume.
    ///   - destBuffers: Destination audio buffer list pointer.
    ///   - destOffset: Offset in the destination buffer to start writing.
    /// - Returns: Number of frames actually consumed.
    @discardableResult
    public func consume(
        maxFrames: Int,
        into destBuffers: UnsafeMutableAudioBufferListPointer,
        destOffset: Int
    ) -> Int {
        self.lock.withLock {
            guard let buffer, self.readOffset < Int(buffer.frameLength) else {
                return 0
            }

            let available = Int(buffer.frameLength) - self.readOffset
            let framesToCopy = min(maxFrames, available)

            guard framesToCopy > 0, let srcChannels = buffer.floatChannelData else {
                return 0
            }

            // Copy each channel
            for ch in 0..<min(destBuffers.count, Int(buffer.format.channelCount)) {
                guard let dest = destBuffers[ch].mData?.assumingMemoryBound(to: Float.self) else {
                    continue
                }
                let src = srcChannels[ch].advanced(by: self.readOffset)

                // Optimized memcpy via UnsafeBufferPointer
                let destPtr = UnsafeMutableBufferPointer(
                    start: dest.advanced(by: destOffset),
                    count: framesToCopy
                )
                let srcPtr = UnsafeBufferPointer(start: src, count: framesToCopy)
                _ = destPtr.initialize(from: srcPtr)
            }

            self.readOffset += framesToCopy

            // Clear buffer reference if fully consumed
            if self.readOffset >= Int(buffer.frameLength) {
                self.buffer = nil
                self.readOffset = 0
            }

            return framesToCopy
        }
    }

    /// Clears the partial buffer state.
    public func clear() {
        self.lock.withLock {
            self.buffer = nil
            self.readOffset = 0
        }
    }
}
