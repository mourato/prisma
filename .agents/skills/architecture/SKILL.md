---
name: architecture
description: Core architectural principles including MVVM, Clean Architecture, Dependency Injection, and Protocol-Oriented Programming. Use when designing new modules or refactoring existing ones.
---

# Architecture Principles

## Overview

Project architectural standards ensuring testability, maintainability, and clear separation of concerns.

## 1. Patterns & Structure

- **MVVM / Clean Architecture**: Separate presentation logic (ViewModels) from business logic (Services/Repositories) and views (SwiftUI/AppKit).
- **Dependency Injection (DI)**: Inject dependencies explicitly through initializers. Avoid direct usage of `.shared` singletons within ViewModels to facilitate unit testing.
- **Protocol-Oriented Programming (POP)**: Use protocols to define abstractions. Favor composition over class-based inheritance.

## 2. Project Layers

- **Presentation Layer**: SwiftUI or AppKit Views reacting to ViewModel state. ViewModels depend on protocols, not concrete implementations.
- **Domain/Core Layer**: Encapsulated within frameworks (e.g., `MeetingAssistantCore`). Contains business logic for recording, transcription, and data management.
- **Infrastructure Layer**: Storage services, networking clients, and external integrations. All infrastructure components should be protocol-based.

## 3. Best Practices

- **Lean ViewModels**: Delegate heavy logic (networking, filtering, processing) to dedicated services.
- **Async Flow**: Adopt `Async/Await` or `Combine` for managing asynchronous data streams instead of nested completion closures.
- **State Management**: Use `@Published` and `@ObservedObject` carefully to ensure predictable UI updates.
