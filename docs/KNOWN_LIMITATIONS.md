# Known Limitations

This document tracks known limitations for features and initiatives within the project. Each entry provides context on why the limitation exists and when it was introduced, aiding future improvements.

## Initiatives

### Speaker Diarization (FluidAudio)
* **Performance Impact**: Diarization is computationally expensive and significantly increases processing time.
  * *Context*: Introduced [2025-12-26] with the initial FluidAudio integration. Kept as an optional feature (Settings > AI) to allow users to opt-in to the performance cost.
* **Alignment Accuracy**: Text-to-speaker alignment relies on ASR token timings. Low-confidence transcriptions may result in imperfect speaker segmentation.
  * *Context*: Inherited from the `FluidAIModelManager` implementation strategy where ASR and Diarization run as separate passes and are merged post-hoc.
* **UI Representation**: Currently, there is no verified UI for displaying speaker segments, only the data model supports it.
  * *Context*: Scope of initial implementation was limited to Data and Service layer. UI implementation is a future task.

### Settings Architecture & Localization
  * *Context*: Side effect of moving to a custom `NavigationSplitView` implementation [2025-12-26].
* **Language Selection Persistence**: Changing the app language from settings requires a manual app restart to take effect.
  * *Context*: `AppleLanguages` UserDefaults key strictly controls localization load order at launch. Dynamic language switching at runtime is technically complex and not implemented in this release [2025-12-27].

### Storage Service
* **Scalability (JSON Based)**: The current `FileSystemStorageService` loads and decodes ALL transcription JSON files into memory at startup. This works for hundreds of files but will degrade performance with thousands.
  * *Context*: [2025-12-27] Optimized to run in a detached background task to prevent UI blocking, but the fundamental O(n) memory and IO cost remains. Future recommendation: Migrate to CoreData or SQLite (GRDB).

### Audio Recording
* **(RESOLVED) Concurrency (Unchecked Sendable)**: `AudioRecordingWorker` was migrated from `@unchecked Sendable` to Actor pattern for automatic thread safety isolation.
  * *Context*: [2026-01-10] Refactored to use Swift 6 Actor pattern, eliminating the need for manual synchronization and improving thread safety guarantees.
* **(RESOLVED) Partial Buffer Consumption**: Previously, the `AVAudioSourceNode` discarded unconsumed frames when a buffer exceeded the requested `frameCount`, causing intermittent audio loss.
  * *Context*: [2025-12-27] Fixed by introducing `PartialBufferState` to track unconsumed frames across render cycles.

### Testing & Concurrency Validation
* **Concurrency Test Coverage**: Added comprehensive concurrency tests to validate thread safety and Actor isolation.
  * *Context*: [2026-01-10] Implemented `ConcurrencyTests.swift` with tests for `RecordingActor` isolation, `AudioRecordingWorker` concurrent buffer processing, and stress testing under high concurrency loads. Tests validate absence of race conditions and proper state consistency across multiple threads.
* **XCTest Runner Instability (Background Environment)**: The XCTest runner in some background/headless environments (like CI or terminal-only sessions) may experience silent process exits when executing tests that combine `Swift Concurrency (Actors)`, `AVFoundation`, and `XCTest.measure` blocks.
  * *Context*: [2026-01-13] Identified during performance guardrail implementation. Impacted tests in `AudioRecordingWorkerTests.swift`, `AudioBufferQueueTests.swift` (concurrent operations), and `AudioSystemTests.swift` (integration performance).
  * *Status*: MITIGATED (Unstable performance tests have been commented out with logic preserved for local/Xcode execution).
  * *Recommendation*: Run performance tests within the Xcode IDE environment where the runner is more stable, or use a dedicated performance testing target.

### Performance Baselines
* **AudioBufferQueue Throughput**: Low-level circular buffer operations are highly optimized using `OSAllocatedUnfairLock`.
  * *Baseline*: Enqueue/Dequeue of 1024-frame buffers (PCM Float32) averages < 0.05ms per operation on Apple Silicon.
* **Recording State Management**: `RecordingManager` state transitions (Start/Stop) are asynchronous but should complete within < 100ms for responsiveness.
  * *Baseline*: Local measurement [2026-01-14] shows transitions typically under 50ms when transcription is not immediately queued.

### Security (Filesystem)
* **(RESOLVED) Path Traversal Risk**: `recordingsDirectory` now validates paths using `resolvingSymlinksInPath()` and container boundary checks.
  * *Context*: [2025-12-27] Identified during code review. Fixed [2026-01-17] with path sanitization.
  * *Implementation*: `validatePath()` method checks for `..` patterns, resolves symlinks, and ensures paths remain within the app container.

* **Memory Safety (Unsafe Pointers)**: The optimized `AudioRecorder` uses `memset` and `UnsafeMutableBufferPointer` for performance.
  * *Context*: [2025-12-27] Replaced safe loop with fast copy. This introduces risk of buffer overflow if pointer arithmetic is ever flawed. Any changes to `createSystemSourceNode` or `PartialBufferState` must be peer-reviewed for correctness.

### Logging
* **Privacy Level**: `AppLogger` is currently configured with `{ privacy: .public }` for all log levels to aid in debugging strict concurrency crashes.
  * *Context*: [2025-12-27] This logs potentially sensitive metadata to the system console. Must be changed to `.private` or `.auto` before public App Store release.
