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

### Navigation Service Bridge
* **Environment Dependency**: The `NavigationService` relies on a `register` call from a SwiftUI view's `.onAppear` to obtain a valid `OpenWindowAction`. 
  * *Context*: Introduced [2025-12-26] when transitioning from native `Settings` scene to `WindowGroup` for better window control. If the service is used before any view with the registration logic appears, it falls back to a brittle AppKit action selector.
* **Window Lifecycle**: Opening multiple instances of the Settings window is possible via `WindowGroup` (id: "settings"), whereas the native `Settings` scene ensures a single instance.
  * *Context*: Multi-window support is a side effect of using `WindowGroup` to gain access to all traffic lights (minimize/maximize).
