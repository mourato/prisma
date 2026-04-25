---
name: data-persistence
description: This skill should be used when the user asks to "store/load data", "design repositories", "plan migrations", or "implement persistence synchronization".
---

# Data Persistence Strategies

## Role

Use this skill as the canonical owner for storage, repository, and migration guidance in Prisma.

- Own persistence-mechanism choice, migration expectations, and repository abstraction guidance.
- Keep storage advice aligned with data integrity and recoverability requirements.
- Delegate secret storage and broader security baseline decisions to their specialist owners.

## Scope Boundary

- Use this skill for repositories, storage design, migration planning, and persistence synchronization.
- Use `../keychain-security/SKILL.md` for credential persistence.
- Use `../security/SKILL.md` for sensitive-data policy beyond persistence mechanics.

## When to Use

Use this skill when the user asks to store/load data, design repositories, plan migrations, or implement persistence synchronization.

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

## 2026-03 Operational Update

### Repository Persistence Hotspots

Prioritize these files when storage behavior changes:

- `Packages/MeetingAssistantCore/Sources/Data/Data/CoreData/CoreDataStack.swift`
- `Packages/MeetingAssistantCore/Sources/Data/Services/StorageService/StorageService.swift`
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Services/KeychainManager.swift`

### Migration Invariants (Must Hold)

For rename/migration work, verify all invariants:

1. Existing user defaults remain readable after migration.
2. Keychain identifiers continue resolving previous credentials.
3. Persistent store path migration is deterministic and idempotent.
4. Retention cleanup never deletes dashboard history unexpectedly.
5. Failure path preserves recoverability (no partial destructive migration).

### Persistence Change Workflow

1. Define target invariant set before implementation.
2. Reuse existing repository/storage abstractions (`reuse -> extend -> create`).
3. Add tests for forward migration and no-op re-run migration.
4. Validate cleanup logic with realistic historical data fixtures.

## 2026-03-04 Progression Drill

### New Evidence

- `0d986f8` added new persisted meeting-conversation data paths.
- `TranscriptionMO` and CoreData mapping were updated with domain/UI coupling points.

### Skill Deepening Focus

1. Add migration checks for newly persisted conversation/model fields (including no-op re-run).
2. Validate round-trip mapping integrity: CoreData -> Domain -> UI -> persistence.
3. Document recovery behavior for partially populated legacy records.
4. Enforce idempotent write semantics for conversation state updates.
