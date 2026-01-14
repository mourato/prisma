# Audio System Architecture

## Overview
The audio recording system in `MeetingAssistantCore` is designed for high-performance, low-latency capture of both Microphone (Input Node) and System Audio (ScreenCaptureKit).

## Key Components

### 1. SystemAudioRecorder (Producer)
- **Role**: Captures system audio via `ScreenCaptureKit`.
- **Concurrency**: Operates on a dedicated background queue (`userInitiated`).
- **Optimization**: Uses a `nonisolated` callback property (`onAudioBuffer`) to push buffers directly to the consumer without hopping to the Main Actor.
- **Safety**: `CallbackStorage` is protected by `OSAllocatedUnfairLock` to ensure thread-safe updates to the callback closure.

### 2. AudioBufferQueue (Bridge)
- **Role**: Thread-safe FIFO bridge between the Push-based producer (SCK) and Pull-based consumer (AVAudioEngine).
- **Structure**: Fixed-size Circular Buffer (Ring Buffer).
- **Concurrency**: Uses `OSAllocatedUnfairLock` (Spinlock equivalent) for extremely low overhead blocking (nanoseconds).
- **Allocation**: Pre-allocates storage to ensure **Zero Allocations** during the steady-state recording loop.

### 3. AudioRecorder (Consumer/Mixer)
- **Role**: Manages the `AVAudioEngine` graph.
- **Components**:
    - `AVAudioSourceNode`: Pulls data from `AudioBufferQueue`.
    - `AVAudioMixerNode`: Merges Mic and System audio.
- **Optimization**: Uses `memcpy` (via `UnsafeMutableBufferPointer`) for audio buffer copying instead of naive loops, reducing CPU usage during the high-frequency render callback (Hot Path).

### 4. AudioRecordingWorker (Writer)
- **Role**: Handles file writing and metering.
- **Pattern**: **Worker Pattern** (Extracted from `AudioRecorder`).
- **Concurrency**: Implemented as a Swift **Actor** for automatic thread safety and state isolation.
- **Optimization**: Processes buffers non-isolatedly when possible to minimize actor contention.

## Memory Management Policy
- **Cycle Prevention**: All coordinators and long-lived services must use `[weak self]` in closures.
- **Audit Tooling**: Services implement `deinit` logging (via `AppLogger`) to verify deallocation during manual and automated audits.
- **Verification**: `MemorySanityTests` in the test suite automate the verification of component deallocation.

## Performance Policy
- **Zero Allocation**: The audio hot path (Producer to Consumer) must favor pre-allocated buffers and avoid heap allocations during active recording.
- **Guardrails**: Performance is tracked via `XCTMetric` tests (where runner stability permits).
- **Baselines**:
    - Circular buffer operations: < 0.05ms (Apple Silicon).
    - State transitions: < 100ms for user-perceived responsiveness.

## Data Flow
1. **SCStream** (System) -> `SystemAudioRecorder` -> `buffer`
2. `buffer` -> `AudioBufferQueue` (Ring Buffer) [Push]
3. `AVAudioEngine` (Render Thread) -> `AudioRecorder` -> `createSystemSourceNode` [Pull]
4. `AudioBufferQueue` -> `memcpy` -> `AVAudioBufferList`
5. `AVAudioMixerNode` -> `Tap` -> `AudioRecordingWorker` -> `AVAudioFile`

## Critical Constraints
- **Main Actor Isolation**: The audio hot path (callbacks) MUST NOT touch the Main Actor. `nonisolated` and `@Sendable` annotations are critical.
- **Memory Safety**: Direct pointer manipulation (`memcpy`) requires careful bound checking (`min(target, filled)`).
- **Locking**: `NSLock` is forbidden in the real-time audio thread (`AudioSourceNode`). `OSAllocatedUnfairLock` is the only permitted synchronization primitive there.
