---
name: architecture
description: This skill should be used when the user asks to "design module boundaries", "apply Clean Architecture", "refactor architecture", or "define dependency injection" in this project.
---

# Architecture Principles

## Overview

Project architectural standards ensuring testability, maintainability, and clear separation of concerns.

## 1. Patterns & Structure

- **MVVM / Clean Architecture**: Separate presentation logic (ViewModels) from business logic (Services/Repositories) and views (SwiftUI/AppKit).
- **Dependency Injection (DI)**: Inject dependencies explicitly through initializers. Avoid direct usage of `.shared` singletons within ViewModels to facilitate unit testing.
- **Protocol-Oriented Programming (POP)**: Use protocols to define abstractions. Favor composition over class-based inheritance.
- **Reusable Blocks First**: For both logic and UI-supporting abstractions, apply `reuse -> extend -> create` before introducing new types.

## 2. Canonical Module Layout

- `MeetingAssistantCoreCommon` — shared logging, config, utilities, resources
- `MeetingAssistantCoreDomain` — entities, contracts, use cases
- `MeetingAssistantCoreInfrastructure` — OS/external adapters (Keychain, networking, providers)
- `MeetingAssistantCoreData` — persistence repositories and storage adapters
- `MeetingAssistantCoreAudio` — capture, buffering, rendering, file-writing pipeline
- `MeetingAssistantCoreAI` — transcription, post-processing, rendering
- `MeetingAssistantCoreUI` — view models, coordinators, SwiftUI/AppKit presentation
- `MeetingAssistantCore` — compatibility export layer for app/tests

Boundary rule: depend inward through protocols, not across feature layers through concrete types.

## 3. Audio Hot-Path Constraints

- Keep real-time callbacks allocation-minimal and free from MainActor hops.
- Prefer `OSAllocatedUnfairLock` in hot paths; avoid `NSLock` in render callbacks.
- Use pre-allocation and fixed-size buffers for producer/consumer bridges.
- Route non-real-time work (file IO, diagnostics, formatting) out of render callbacks.

## 4. Best Practices

- **Lean ViewModels**: Delegate heavy logic (networking, filtering, processing) to dedicated services.
- **Async Flow**: Adopt `async/await` or `Combine` for asynchronous streams instead of nested completion closures.
- **State Management**: Use `@Published` and `@ObservedObject` carefully to ensure predictable UI updates.
- **Extraction over Duplication**: When behavior repeats, extract to a reusable use case/service/helper in the owning module.
- **Architecture Checks**: For cross-module refactors, run `make arch-check` before merge.
