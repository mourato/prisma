---
name: data-persistence
description: Strategies for local and cloud data storage. Covers UserDefaults, Core Data, Keychain, and migration planning. Use when implementing data saving, loading, or encryption.
---

# Data Persistence Strategies

## Overview

Guidelines for choosing the right storage mechanism and ensuring data integrity and security.

## 1. Storage Mechanisms

- **UserDefaults**: Use for lightweight preferences and simple key-value pairs.
- **Core Data / Persistence**: Use for complex models, relationships, and large datasets.
- **Keychain**: **MANDATORY** for sensitive data (API keys, passwords, tokens). Never store secrets in UserDefaults or plain files.

## 2. Integrity & Lifecycle

- **Migration Planning**: Plan for schema changes from the start (versioning, lightweight vs. heavy migration).
- **Cloud Sync**: Implement iCloud synchronization (CloudKit or `NSUbiquitousKeyValueStore`) where appropriate for user settings.
- **Threading**: Perform database operations on background contexts to avoid blocking the main thread.

## 3. Best Practices

- **Abstraction**: Use protocol-based repositories to decouple business logic from the specific persistence implementation.
- **Error Handling**: Gracefully handle missing data or corruption; provide default states where necessary.
- **Cleanup**: Implement data pruning or expiration policies for cached or temporary data.
