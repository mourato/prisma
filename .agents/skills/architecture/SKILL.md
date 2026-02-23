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

## 2. Project Layers

- **Presentation Layer**: SwiftUI or AppKit Views reacting to ViewModel state. ViewModels depend on protocols, not concrete implementations.
- **Domain/Core Layer**: Encapsulated within frameworks (e.g., `MeetingAssistantCore`). Contains business logic for recording, transcription, and data management.
- **Infrastructure Layer**: Storage services, networking clients, and external integrations. All infrastructure components should be protocol-based.

## 3. Best Practices

- **Lean ViewModels**: Delegate heavy logic (networking, filtering, processing) to dedicated services.
- **Async Flow**: Adopt `Async/Await` or `Combine` for managing asynchronous data streams instead of nested completion closures.
- **State Management**: Use `@Published` and `@ObservedObject` carefully to ensure predictable UI updates.
- **Extraction over Duplication**: When behavior starts repeating, extract it into a reusable use case/service/helper in the appropriate module.
