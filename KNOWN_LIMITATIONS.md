# Known Limitations

This document tracks known limitations and intentional trade-offs in the project. Each entry includes context on why the limitation exists and what a future improvement could look like.

> **Last updated:** 2026-02-06

## Storage

### Filesystem storage (JSON) does not scale to thousands of items

- **What:** `FileSystemStorageService` loads and decodes all transcription JSON files when loading the library.
- **Why:** Simpler implementation and fast iteration early on.
- **Impact:** Works for hundreds of items but will degrade with thousands (I/O + memory + latency).
- **Future direction:** Migrate to Core Data or SQLite (e.g., GRDB) and keep JSON only as an export/import format.

## Audio

### High-frequency buffer allocations in `SystemAudioRecorder`

- **What:** The ScreenCaptureKit callback path allocates new buffers at a high rate.
- **Why:** Prioritized correctness and stability over a complex buffer pool.
- **Impact:** Low on modern Apple Silicon, but still suboptimal for long sessions.
- **Future direction:** Introduce a bounded buffer pool with strict ownership rules.

### Audio engine start timeout is hardcoded

- **What:** Audio engine startup uses a hardcoded timeout (10 seconds).
- **Why:** Avoids UI hangs and stuck state transitions.
- **Impact:** Recording may fail on heavily loaded systems if initialization takes longer.
- **Future direction:** Make it configurable and improve diagnostics.

## Assistant (text selection)

### Depends on clipboard + Accessibility

- **What:** The Assistant uses copy/paste to read and replace selected text.
- **Why:** Avoids private APIs and keeps compatibility across apps.
- **Impact:** Some apps may block clipboard updates or Accessibility actions.
- **Future direction:** Improve app-specific adapters and add better UX when actions fail.

## Design system

### Global theme lookup via `UserDefaults`

- **What:** Design system accent/theme tokens read from `UserDefaults`.
- **Why:** Keeps UI usage simple and consistent without heavy DI.
- **Impact:** Harder to run parallel previews/tests with different themes.
- **Future direction:** Add an injectable theme provider for previews/tests, while keeping a default global implementation.

## AI settings

### Model fetching is state-based (no background refresh)

- **What:** The list of available models refreshes only after verification or provider changes with a valid key.
- **Why:** Simpler UI state and fewer background network calls.
- **Impact:** Users may need to re-verify to refresh models.
- **Future direction:** Add a lightweight refresh mechanism with explicit user control.

### API key persistence occurs only after successful verification

- **What:** API keys are stored in Keychain only after “Verify and Save”.
- **Why:** Avoid persisting invalid/partial keys.
- **Impact:** Changes can be lost if the user navigates away before verification.
- **Future direction:** Provide a clear “Save without verify” flow with explicit warnings.

### API key is plaintext in memory while editing

- **What:** The UI binds to a `String` while editing the key.
- **Why:** SwiftUI bindings require it.
- **Impact:** Low/moderate; exposure is limited to edit time.
- **Future direction:** Keep minimizing lifetime (clear immediately after save) and avoid logging.

### Custom provider verification requires `/v1/models`

- **What:** Verification assumes a model-list endpoint exists and returns 200.
- **Why:** Needed to populate model pickers consistently.
- **Impact:** Some minimal proxies will fail verification.
- **Future direction:** Add alternate verification modes (chat-only, custom endpoints).

## macOS integration

### Auto-launch requires a properly signed app

- **What:** “Launch at login” uses `SMAppService.mainApp`.
- **Why:** Modern Login Item API.
- **Impact:** In dev/debug or unsigned builds, registration can fail.
- **Future direction:** Improve error surfacing and document expected behavior.

## Testing / CI

### XCTest runner instability for concurrency + AVFoundation in headless environments

- **What:** Some tests can exit silently in terminal/headless environments when mixing Actors + AVFoundation + performance measurements.
- **Why:** XCTest runner behavior differs between Xcode UI and headless mode.
- **Impact:** Certain performance tests are kept disabled for CI stability.
- **Future direction:** Move performance tests to a dedicated target/environment.
