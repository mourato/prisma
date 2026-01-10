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

### Security (Filesystem)
* **Path Traversal Risk**: `recordingsDirectory` is read directly from `UserDefaults` without sanitization.
  * *Context*: [2025-12-27] Identified during code review. While the App Sandbox mitigates system-wide damage, input validation should be added in future updates to prevent unrestricted writes within the container.
  * *Status*: IN_PROGRESS
  * *Start Date*: 2025-01-10
  * *Fix Plan*: Implement path sanitization using `URL.resolvingSymlinksInPath()` and validate that resolved paths remain within the app's container directory before file operations.

* **Memory Safety (Unsafe Pointers)**: The optimized `AudioRecorder` uses `memset` and `UnsafeMutableBufferPointer` for performance.
  * *Context*: [2025-12-27] Replaced safe loop with fast copy. This introduces risk of buffer overflow if pointer arithmetic is ever flawed. Any changes to `createSystemSourceNode` or `PartialBufferState` must be peer-reviewed for correctness.

### Logging
* **Privacy Level**: `AppLogger` is currently configured with `{ privacy: .public }` for all log levels to aid in debugging strict concurrency crashes.
  * *Context*: [2025-12-27] This logs potentially sensitive metadata to the system console. Must be changed to `.private` or `.auto` before public App Store release.
