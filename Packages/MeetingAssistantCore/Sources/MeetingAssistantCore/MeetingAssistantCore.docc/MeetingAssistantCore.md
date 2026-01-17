# ``MeetingAssistantCore``

MeetingAssistantCore is the foundational framework for the Meeting Assistant application, providing high-performance audio recording, transcription services, and robust data management.

## Overview

MeetingAssistantCore follows **Clean Architecture** and **MVVM** principles to ensure a scalable and testable codebase. It leverages modern Swift features like **Actors** for concurrency and **ScreenCaptureKit** for high-quality audio capture.

### Key Components

- **Audio System**: Low-latency recording using `AVAudioEngine` and `ScreenCaptureKit`.
- **Domain Layer**: Core business logic, entities, and repository interfaces.
- **Services**: Implementations for networking, storage, and AI processing.
- **Infrastructure**: Low-level abstractions for external API integrations.

## Topics

### Audio Recording
- ``RecordingManager``
- ``AudioRecorder``
- ``SystemAudioRecorder``

### Transcription & AI
- ``TranscriptionClient``
- ``AIProvider``
- ``AITranscriptionResult``

### Data Management
- ``StorageService``
- ``MeetingRepository``
- ``TranscriptionStorageRepository``

### Infrastructure
- ``HTTPClient``
- ``APIEndpoint``
- ``NetworkError``

## Articles
- <doc:GettingStarted>
- <doc:AudioRecordingWorkflow>
- <doc:CleanArchitectureGuide>
