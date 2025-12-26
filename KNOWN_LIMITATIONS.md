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
* **Hardcoded UI Strings**: Many UI labels and error messages in the Settings module are currently hardcoded in Portuguese, hindering internationalization.
  * *Context*: Identified [2025-12-26] during a code review of the MVVM refactoring. A migration to `Localizable.strings` is planned.
* **Tight Singleton Coupling**: ViewModels in the Settings module are directly coupled to service singletons (`RecordingManager`, `TranscriptionClient`, `FileSystemStorageService`), which limits testability via dependency injection.
  * *Context*: Part of the initial MVVM migration [2025-12-26]. Refactoring to full DI is deferred to a future cleanup phase.
* **Settings Window Persistence**: The settings window does not currently persist its position or size between launches.
  * *Context*: Side effect of moving to a custom `NavigationSplitView` implementation [2025-12-26].
