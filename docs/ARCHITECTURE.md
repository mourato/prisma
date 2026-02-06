# Project Architecture

> **Last updated:** 2026-02-06
> **Tags:** #Architecture, #MVVM, #CleanArchitecture, #Audio

## 1. Overview

This project is organized to maximize modularity, testability, and separation of concerns.

- Presentation follows **MVVM** (SwiftUI Views + ObservableObject ViewModels).
- Core services and data access follow a simplified **Clean Architecture** style (Domain / Data / Infrastructure boundaries).

## 2. Main layers (and where they live)

### Presentation

- SwiftUI Views: `Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Views/`
- ViewModels: `Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/ViewModels/`
- Coordinators (navigation / orchestration): `Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Presentation/Coordinators/`

Guidelines:

- Views react to ViewModel state.
- ViewModels expose state and intent, and depend on abstractions when possible.

### Domain

- Entities and interfaces: `Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Domain/`
- Use cases: `Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Domain/UseCases/`

Guidelines:

- Domain should not depend on platform frameworks unless strictly necessary.
- Use cases should be small, testable, and composable.

### Data

- Repositories and persistence: `Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Data/`

Guidelines:

- Repositories implement Domain interfaces.
- Persistence is abstracted behind protocols to keep switching cost low.

### Infrastructure

- System integrations, networking, providers: `Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Infrastructure/`

Guidelines:

- Anything that talks to the “outside world” (OS APIs, HTTP, metrics, crash reporting) should live here.

---

## 3. Audio subsystem architecture

The audio pipeline is designed for high performance and low latency, capturing microphone and system audio (ScreenCaptureKit).

### Key components

#### 1. `SystemAudioRecorder` (producer)

- Captures system audio via `ScreenCaptureKit`.
- Runs on a dedicated background queue (`userInitiated`).
- Uses a `nonisolated` callback (`onAudioBuffer`) to push buffers to the consumer without hopping to the Main Actor.
- Uses `OSAllocatedUnfairLock` to protect callback storage.

#### 2. `AudioBufferQueue` (bridge)

- Thread-safe FIFO bridge between push-based SCK producer and pull-based AVAudioEngine consumer.
- Fixed-size circular buffer (ring buffer).
- Uses `OSAllocatedUnfairLock` for minimal overhead.
- Pre-allocates storage to minimize allocations during recording.

#### 3. `AudioRecorder` (consumer / mixer)

- Manages the `AVAudioEngine` graph.
- Uses `AVAudioSourceNode` to pull from `AudioBufferQueue`.
- Merges microphone and system audio.
- Uses `memcpy` / unsafe buffers for hot-path copying (performance-critical).

#### 4. `AudioRecordingWorker` (writer)

- Handles file writing and metering.
- Implemented as a Swift actor for isolation and thread safety.

### Memory & performance policy

- Avoid allocations on the audio hot path.
- Do not touch the Main Actor from real-time callbacks.
- `NSLock` is forbidden in the render thread; prefer `OSAllocatedUnfairLock`.

## 4. Cross references

- `.agents/rules/testing.md`
- `.agents/rules/architecture.md`
- `.agents/skills/audio-realtime/SKILL.md`
- `.agents/skills/quality-assurance/SKILL.md`
