---
name: concurrency
description: Advanced concurrency patterns in Swift. Covers async/await, actors, MainActor isolation, and deadlock prevention. Use when managing parallel execution or thread safety.
---

# Concurrency & Thread Safety

## Overview

Standards for safe, efficient parallel execution using Swift’s structured concurrency and actors.

## 1. Modern Concurrency

- **Async/Await**: Prefer `async`/`await` over completion handlers or GCD callbacks.
- **Actors**: Use `actor` for thread-safe state isolation of background components.
- **MainActor**: Ensure all UI-bound components and ViewModels are isolated to the `@MainActor`.

## 2. Capturing & Sendability

- **@Sendable**: Mark closures passed across concurrency boundaries as `@Sendable`.
- **Capture Groups**: Use `[weak self]` in closures that might outlive their owner, even in async contexts when self is not Sendable.
- **Checked Sendable**: Avoid `@unchecked Sendable` unless absolutely necessary for external C/Obj-C compatibility.

## 3. Deadlock & Race Prevention

**CRITICAL**: Avoid nested locking or properties that acquire locks internally and are called frequently.
- Use `OSAllocatedUnfairLock` for performance-critical low-level locking.
- Ensure computed properties (like `isEmpty` or `count`) do not block or acquire locks that might be held by the calling thread.
- Establish a consistent lock acquisition order if multiple locks are required.

## 4. Practical Examples

```swift
// ✅ Safe MainActor isolation
@MainActor
class WorkspaceViewModel: ObservableObject {
    func refresh() async {
        // Safe UI work
    }
}

// ✅ Safe closure capturing
Task { [weak self] in
    await self?.performServiceAction()
}
```
