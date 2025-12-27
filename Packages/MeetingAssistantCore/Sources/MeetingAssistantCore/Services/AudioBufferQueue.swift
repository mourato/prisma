import AVFoundation
import Foundation

/// A thread-safe FIFO queue for `AVAudioPCMBuffer`.
/// Used to bridge the push-based `SCStream` system audio to the pull-based `AVAudioSourceNode`.
public final class AudioBufferQueue: @unchecked Sendable {
    private let lock = NSLock()
    private var buffers: [AVAudioPCMBuffer] = []

    // Limits total frames to avoid unbounded memory growth
    private let maxFrameCount: AVAudioFrameCount
    private var currentFrameCount: AVAudioFrameCount = 0

    public init(maxFrames: AVAudioFrameCount = 48_000 * 5) { // ~5 seconds buffer @ 48kHz
        self.maxFrameCount = maxFrames
    }

    public func enqueue(_ buffer: AVAudioPCMBuffer) {
        self.lock.lock()
        defer { lock.unlock() }

        // Drop oldest if full
        while self.currentFrameCount + buffer.frameLength > self.maxFrameCount, !self.buffers.isEmpty {
            let dropped = self.buffers.removeFirst()
            self.currentFrameCount -= dropped.frameLength
        }

        self.buffers.append(buffer)
        self.currentFrameCount += buffer.frameLength
    }

    public func dequeue() -> AVAudioPCMBuffer? {
        self.lock.lock()
        defer { lock.unlock() }

        guard !self.buffers.isEmpty else { return nil }

        let buffer = self.buffers.removeFirst()
        self.currentFrameCount -= buffer.frameLength
        return buffer
    }

    public func clear() {
        self.lock.lock()
        defer { lock.unlock() }

        self.buffers.removeAll()
        self.currentFrameCount = 0
    }
}
