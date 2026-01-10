# Real-Time Audio

> **Conditional Skill** - Triggered when working with audio code

## Overview

This skill addresses critical policies for real-time audio processing, where memory allocations and locks are especially sensitive.

## When to Use

Activate this skill when detecting:
- `AVAudioSourceNode`
- `AVAudioEngine` + `installTap`
- `ProcessTap`
- `AudioRecorder`
- `SystemAudioRecorder`
- `AudioBufferQueue`

## Key Concepts

### Zero Allocation Policy

**CRITICAL**: NEVER allocate memory inside audio callbacks.

```swift
// WRONG - Allocates memory in callback
func renderBlock(timestamp: AVAudioTime, frameCount: AVAudioFrameCount) -> UnsafePointer<Float> {
    let buffer = [Float](repeating: 0, count: Int(frameCount)) // ALLOCATES!
    return process(buffer)
}

// CORRECT - Use pre-allocated ring buffer
class AudioProcessor {
    private let ringBuffer: RingBuffer // Allocated once in init

    func renderBlock(timestamp: AVAudioTime, frameCount: AVAudioFrameCount) {
        guard let output = ringBuffer.readBuffer(count: Int(frameCount)) else { return }
        processSamples(output)
    }
}
```

### Pre-allocated Ring Buffer

```swift
final class RingBuffer {
    private let capacity: Int
    private let buffer: UnsafeMutablePointer<Float>
    private var writeIndex = 0
    private var readIndex = 0

    init(capacity: Int) {
        self.capacity = capacity
        self.buffer = UnsafeMutablePointer<Float>.allocate(capacity: capacity)
    }

    deinit {
        buffer.deallocate()
    }

    func write(_ data: UnsafePointer<Float>, count: Int) {
        let copies = min(count, capacity)
        memcpy(buffer.advanced(by: writeIndex), data, copies * MemoryLayout<Float>.size)
        writeIndex = (writeIndex + copies) % capacity
    }

    func readBuffer(count: Int) -> UnsafeMutableBufferPointer<Float>? {
        guard count <= capacity else { return nil }
        return UnsafeMutableBufferPointer(start: buffer.advanced(by: readIndex), count: count)
    }
}
```

### Bounds Checking

Always use `min()` to prevent buffer overflows:

```swift
// CORRECT
let copies = min(source.count, dest.count)
memcpy(destPtr, sourcePtr, copies * MemoryLayout<Element>.size)
```

### Lock Safety

**NEVER use** `NSLock` or `@MainActor` in real-time audio callbacks. Use `OSAllocatedUnfairLock`:

```swift
import os.lock

final class AtomicCounter {
    private let lock = OSAllocatedUnfairLock(initialState: 0)

    func increment() {
        lock.withLock { $0 += 1 }
    }

    var value: Int {
        lock.withLock { $0 }
    }
}
```

## Common Patterns

### Audio Buffer Queue

```swift
final class AudioBufferQueue {
    private let queue = DispatchQueue(label: "com.meeting.audio.buffer", qos: .userInitiated)
    private var buffers: [Data] = []

    // DON'T do this - allocates in callback
    func processAudio(_ data: UnsafePointer<Float>, frameCount: UInt32) {
        queue.async {
            let copy = Data(bytes: data, count: Int(frameCount) * MemoryLayout<Float>.size)
            self.buffers.append(copy)
        }
    }
}
```

## Common Pitfalls

1. **Strings in callbacks** - Even `"\(value)"` allocates memory
2. **Temporary arrays** - `[Float](repeating:)` allocates
3. **Error creation** - `throw MyError()` may allocate
4. **Complex getters** - Avoid computed properties in callbacks

## References

- [AudioBufferQueue.swift](Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Services/AudioBufferQueue.swift)
- [SystemAudioRecorder.swift](Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Services/SystemAudioRecorder.swift)
- [docs/ARCHITECTURE.md](../../../../docs/ARCHITECTURE.md)
