---
name: audio-realtime
description: This skill should be used when the user asks to "fix audio glitches", "optimize low-latency audio", "debug underruns", or "update real-time audio callbacks".
---

# Real-Time Audio Processing

## Overview

Rules and best practices for managing audio engines and buffers in a real-time, multi-threaded context.

## Core Principles

### 1. Thread Safety & Deadlock Prevention
**CRITICAL**: Audio properties and buffer queues are often accessed across multiple threads.
- **Computed Properties**: Computed properties that acquire locks (e.g., `isEmpty`) can cause deadlocks. Prefer simple, lock-safe implementations.
- **Lock Management**: Use `OSAllocatedUnfairLock` correctly. Never nest locks or acquire multiple locks simultaneously unless a strict hierarchy is maintained.
- **Strict Isolation**: Use `@MainActor` for UI-bound states while keeping the audio hot path decoupled.

### 2. High-Priority Constraints
The audio render thread is high-priority and time-constrained.
- **Avoid Blocking**: Never perform I/O, networking, or heavy allocation on the render thread.
- **Lock-Free Patterns**: Use lock-free ring buffers (atomic increment/decrement) where possible to avoid priority inversion.

## Key Components

### AudioBufferQueue
- Maintain thread-safe access for appending and consuming samples.
- Ensure `isEmpty` and `count` are safe to call during the recording lifecycle.

### AudioRecorder & Engine
- Manage life-cycle transitions (Start, Stop, Pause) transitionally.
- Handle engine failures gracefully without hanging the UI or the background thread.

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

## Testing Audio Components

### Mock Audio Engine Pattern

When testing audio components, always validate allocations and bounds before unsafe operations:

```swift
// ✅ Correct - safe pointer handling in tests
class MockAudioEngine {
    func testRenderCallback() {
        let frameCount: AVAudioFrameCount = 512
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        
        // 1. Allocate the buffer BEFORE the callback
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            XCTFail("Failed to allocate buffer")
            return
        }
        buffer.frameLength = frameCount
        
        // 2. Validate pointers before using them
        let ablPtr = UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList)
        guard let channelData = ablPtr.first else {
            XCTFail("No channel data")
            return
        }
        
        // 3. Always bounds-check
        let safeCount = min(Int(frameCount), Int(channelData.mDataByteSize) / MemoryLayout<Float>.size)
        
        // 4. Process only safeCount frames
        let floatPtr = channelData.mData?.assumingMemoryBound(to: Float.self)
        // Safe to use floatPtr[0..<safeCount]
    }
}
```

### Common Test Crashes

**Signal 11 (SIGSEGV)**:
- **Cause**: Invalid pointer access or an unallocated buffer
- **Fix**: Always allocate `AVAudioPCMBuffer` BEFORE passing it to callbacks
- **Validation**: Use `XCTAssertNotNil` to validate allocations before unsafe casts

**Example of a real fix (Issue #26)**:
```swift
// ❌ Before - crash in testSourceNodeRenderCallback
let ablPtr = UnsafeMutableAudioBufferListPointer(audioBufferList)
let buffer = ablPtr.first!  // Force-unwrap without validation

// ✅ After - safe with validation
guard let ablPtr = UnsafeMutableAudioBufferListPointer(audioBufferList).first else {
    XCTFail("Expected audio buffer")
    return noErr
}
let safeFrameCount = min(requestedFrames, ablPtr.mDataByteSize / MemoryLayout<Float>.size)
```

### Skipping Unstable Tests

For tests with non-deterministic behavior (e.g., performance, extreme concurrency):

```swift
func testHighConcurrencyScenario() throws {
    #if ENABLE_UNSTABLE_TESTS
    // Test implementation
    #else
    throw XCTSkip("Unstable test - enable with ENABLE_UNSTABLE_TESTS flag")
    #endif
}
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
- `.agents/skills/architecture/SKILL.md`


## 2026-03 Operational Update

### Repository Hotspots (Current)

Prioritize these files first when triaging regressions:

- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreAudio/Services/AudioRecorder.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreAudio/Services/AudioDeviceManager.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreAudio/Services/AudioRecorder+Diagnostics.swift`

Common recurring failures:

- Mic-only capture fails when input/output devices are shared.
- Sample-rate mismatches with external USB microphones.
- Diagnostic probes accidentally changing runtime behavior.

### Mic Reliability Playbook

Use this order when addressing capture reliability bugs:

1. Validate device selection and fallback order in `AudioDeviceManager`.
2. Resolve sample rate from device capability before engine start.
3. Keep start/stop paths idempotent; diagnostics must be observational only.
4. Use mic-only fallback strategy when engine graph setup fails.
5. Re-run shared-device and USB-mic scenarios before merge.

## 2026-03-04 Progression Drill

### New Evidence

- `13acce3` and `9415604` re-opened concurrency/sendability risk in the audio path.
- Recent fixes concentrated in `AudioRecorder.swift`, `AudioMerger.swift`, and `AudioRecorder+Diagnostics.swift`.

### Skill Deepening Focus

1. Add a mandatory callback audit step: every cross-thread audio callback typealias must be `@Sendable`.
2. Document a "hot path isolation map" (render callback, diagnostics, merger, writer) before changing code.
3. Add a pre-merge checklist for mixed isolation paths (`nonisolated` utility + actor-owned mutable state).
4. Pair real-time constraints review with concurrency diagnostics to avoid regressions from "quick" fixes.
