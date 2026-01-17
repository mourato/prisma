---
name: audio-realtime
description: Use when working with audio recording, AVAudioEngine, AVAudioSourceNode, SystemAudioRecorder, AudioBufferQueue, AudioRecorder, AudioRecordingWorker, or real-time audio processing. Covers critical performance constraints AND system architecture patterns.
---

# Real-Time Audio

> **Conditional Skill** - Triggered when working with audio code

## Overview

This skill addresses critical policies for real-time audio processing AND architectural patterns for the audio subsystem, where memory allocations and locks are especially sensitive.

## When to Use

Activate this skill when detecting:
- `AVAudioSourceNode`
- `AVAudioEngine` + `installTap`
- `ProcessTap`
- `AudioRecorder`
- `SystemAudioRecorder`
- `AudioBufferQueue`
- `AudioRecordingWorker`

---

## Critical Constraints (Real-Time Audio)

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

### Sendable Closure Protocol

**CRITICAL**: Closures passed between threads (especially for callbacks) MUST be marked `@Sendable`.

```swift
// CORRECT
typealias AudioCallback = @Sendable (AVAudioPCMBuffer) -> Void

class SystemAudioRecorder {
    var onAudioBuffer: AudioCallback?
}
```

**Why**: Ensures compiler verification of thread safety and prevents capturing mutable non-thread-safe state.

---

## Audio Subsystem Architecture

The audio recording system is designed for **high performance and low latency**, capturing both Microphone and System Audio (ScreenCaptureKit).

### Component Responsibilities

#### 1. SystemAudioRecorder (Producer)
- **Role**: Captures system audio via `ScreenCaptureKit`.
- **Concurrency**: Operates on dedicated background queue (`userInitiated`).
- **Optimization**: Uses `nonisolated` callback property (`onAudioBuffer`) to push buffers directly to consumer without hopping to Main Actor.
- **Safety**: `CallbackStorage` protected by `OSAllocatedUnfairLock` for thread-safe callback updates.

```swift
final class SystemAudioRecorder {
    private let queue = DispatchQueue(label: "com.meeting.system-audio", qos: .userInitiated)
    private let callbackLock = OSAllocatedUnfairLock<AudioCallback?>(initialState: nil)
    
    var onAudioBuffer: AudioCallback? {
        get { callbackLock.withLock { $0 } }
        set { callbackLock.withLock { $0 = newValue } }
    }
}
```

#### 2. AudioBufferQueue (Bridge)
- **Role**: Thread-safe FIFO bridge between Push-based producer (SCK) and Pull-based consumer (AVAudioEngine).
- **Structure**: Fixed-size Circular Buffer (Ring Buffer).
- **Concurrency**: Uses `OSAllocatedUnfairLock` for extremely low overhead blocking (nanoseconds).
- **Allocation**: Pre-allocates storage to ensure **Zero Allocations** during steady-state recording loop.

#### 3. AudioRecorder (Consumer/Mixer)
- **Role**: Manages the `AVAudioEngine` graph.
- **Components**:
    - `AVAudioSourceNode`: Pulls data from `AudioBufferQueue`.
    - `AVAudioMixerNode`: Merges Mic and System audio.
- **Optimization**: Uses `memcpy` (via `UnsafeMutableBufferPointer`) for audio buffer copying instead of naive loops, reducing CPU usage during high-frequency render callback (Hot Path).

```swift
let sourceNode = AVAudioSourceNode { [weak queue] _, _, frameCount, audioBufferList in
    guard let queue = queue else { return noErr }
    
    let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
    guard let buffer = ablPointer.first else { return noErr }
    
    // Zero-copy pull from ring buffer
    let samples = queue.dequeue(count: Int(frameCount))
    let bytesToCopy = min(samples.count, Int(buffer.mDataByteSize)) * MemoryLayout<Float>.size
    memcpy(buffer.mData, samples.baseAddress, bytesToCopy)
    
    return noErr
}
```

#### 4. AudioRecordingWorker (Writer)
- **Role**: Handles file writing and metering.
- **Pattern**: **Worker Pattern** (Extracted from `AudioRecorder`).
- **Concurrency**: Implemented as Swift **Actor** for automatic thread safety and state isolation.
- **Optimization**: Processes buffers non-isolatedly when possible to minimize actor contention.

```swift
actor AudioRecordingWorker {
    private var fileURL: URL?
    private var audioFile: AVAudioFile?
    
    func write(buffer: AVAudioPCMBuffer) async throws {
        guard let audioFile = audioFile else { return }
        try audioFile.write(from: buffer)
    }
}
```

### Memory & Performance Policy

- **Cycle Prevention**: All coordinators and long-lived services must use `[weak self]` in closures.
- **Zero Allocation**: The audio hot path (Producer to Consumer) must favor pre-allocated buffers and avoid heap allocations during active recording.
- **Locking**: `NSLock` is forbidden in the real-time audio thread (`AudioSourceNode`). `OSAllocatedUnfairLock` is the only permitted synchronization primitive there.
- **Main Actor Isolation**: The audio hot path (callbacks) MUST NOT touch the Main Actor.

### Data Flow Diagram

```
┌──────────────────────┐
│ SystemAudioRecorder  │ (ScreenCaptureKit)
│    (Producer)        │
└──────────┬───────────┘
           │ Push (@Sendable callback)
           ▼
┌──────────────────────┐
│  AudioBufferQueue    │ (Ring Buffer, OSAllocatedUnfairLock)
│     (Bridge)         │
└──────────┬───────────┘
           │ Pull (AVAudioSourceNode)
           ▼
┌──────────────────────┐
│   AudioRecorder      │ (AVAudioEngine + Mixer)
│   (Consumer/Mixer)   │
└──────────┬───────────┘
           │ Write
           ▼
┌──────────────────────┐
│ AudioRecordingWorker │ (Actor, AVAudioFile)
│     (Writer)         │
└──────────────────────┘
```

---

## Common Patterns

### Efficient Copying

```swift
// Use memcpy via UnsafeMutableBufferPointer
let destBuffer = UnsafeMutableBufferPointer<Float>(start: destPtr, count: frameCount)
let sourceBuffer = UnsafeBufferPointer<Float>(start: sourcePtr, count: frameCount)

let copiesToWrite = min(sourceBuffer.count, destBuffer.count)
destBuffer.baseAddress?.update(from: sourceBuffer.baseAddress!, count: copiesToWrite)
```

---

## Common Pitfalls

1. **Strings in callbacks** - Even `"\(value)"` allocates memory
2. **Temporary arrays** - `[Float](repeating:)` allocates
3. **Error creation** - `throw MyError()` may allocate
4. **Complex getters** - Avoid computed properties in callbacks
5. **Forgot `@Sendable`** - Callbacks between threads must be `@Sendable`

---

## References

- [AudioBufferQueue.swift](Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Services/AudioBufferQueue.swift)
- [SystemAudioRecorder.swift](Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Services/SystemAudioRecorder.swift)
- [docs/ARCHITECTURE.md](../../../../docs/ARCHITECTURE.md)
