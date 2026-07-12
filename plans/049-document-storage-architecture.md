# Plan 049: Document the current storage architecture and migration policy

> **Executor instructions**: Documentation-only plan. Do not modify Swift source or persistence behavior. No code review is required; run the documentation/link validation gates.
>
> **Drift check**: `git diff --stat 80ed5788..HEAD -- .agents/docs README.md plans/README.md`

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: LOW
- **Depends on**: none
- **Category**: docs
- **Planned at**: commit `80ed5788`, 2026-07-12
- **Related issue**: #51

## Why this matters

Prisma uses Core Data, repositories, legacy-store migration, filesystem audio cleanup, UserDefaults settings, and Keychain credentials. The current architecture is reconstructible from code but lacks one maintained explanation of boundaries, migration safety, cleanup, and privacy. This creates unnecessary risk for future FRC/FTS, CloudKit, retention, and concurrency work.

## Current state

- `CoreDataStack.swift` owns persistent-store loading, migration, contexts, and in-memory fallback.
- `CoreDataTranscriptionStorageRepository.swift` owns Core Data mapping/query operations.
- `StorageService`/`RetentionCleanup` owns application-level storage and cleanup orchestration.
- `KeychainManager` owns credentials; transcripts/audio remain local.
- Existing guidance forbids a root `docs/` folder; new reference documentation belongs under `.agents/docs/`.

## Commands you will need

| Purpose | Command | Expected result |
|---|---|---|
| Guidance validation | `make guidance-check` | exit 0 |
| Link/target validation | `git diff --check` | exit 0 |
| Scope | `git status --short` | only documentation files changed |

## Scope

**In scope**:

- A new `.agents/docs/storage-architecture.md` or an existing `.agents/docs/` document selected by the executor.
- `plans/README.md`

**Out of scope**:

- Any Swift source, Core Data model, migration, schema, entitlement, or backup implementation.
- Promising CloudKit, FRC, FTS, or backup features that do not exist.

## Steps

### Step 1: Write the architecture map

Document the data flow from capture/transcription to domain model, repository, Core Data entities, filesystem audio, retention cleanup, and UI ViewModels. Include ownership and actor/context boundaries using current names from the code.

**Verify**: every referenced path exists and terminology matches the current source.

### Step 2: Record migration and privacy contracts

Document legacy-store migration, in-memory fallback, cleanup safety, Keychain boundaries, local-first guarantees, and what is deliberately not synchronized. State that #97/#98 are measurement-gated follow-ups rather than current implementations.

**Verify**: no undocumented future feature is presented as shipped behavior.

### Step 3: Validate documentation

Run guidance and diff checks, then update issue #51 with the document path and current limitations.

**Verify**: `make guidance-check && git diff --check` -> both exit 0.

## Done criteria

- [ ] Storage boundaries, migration, cleanup, credential, and privacy policies are documented.
- [ ] The document lives under `.agents/docs/`, not root `docs/`.
- [ ] All links/paths are valid and guidance validation passes.
- [ ] Issue #51 is updated with the final document path.
- [ ] `plans/README.md` status row updated.

## STOP conditions

- The current code contradicts a proposed architectural statement; document the contradiction instead of silently choosing a design.
- A new document would duplicate an existing maintained reference; update the existing owner instead.

## Maintenance notes

Update this document whenever persistence schema, migration policy, cleanup ownership, or credential residency changes.
