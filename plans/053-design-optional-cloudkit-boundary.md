# Plan 053: Decide whether optional CloudKit sync fits Prisma's privacy boundary

> **Executor instructions**: This is a privacy/product design spike. Do not add CloudKit entitlements, network sync, or persisted cloud state until the decision and threat model are approved. Any prototype requires thermo and security review.
>
> **Drift check**: `git diff --stat 80ed5788..HEAD -- Packages/MeetingAssistantCore/Sources/Data Packages/MeetingAssistantCore/Sources/Infrastructure Packages/MeetingAssistantCore/Sources/UI Packages/MeetingAssistantCore/Tests .agents/docs plans/README.md`

## Status

- **Priority**: P3
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: plans/049-document-storage-architecture.md
- **Category**: direction
- **Planned at**: commit `80ed5788`, 2026-07-12
- **Related issue**: #54

## Why this matters

CloudKit could synchronize vocabulary or selected settings across a user's Macs, but Prisma's core promise is local-first handling of sensitive meeting data. The issue is still a plausible roadmap item, not an implementation-ready requirement. A decision must define exactly what may leave the device, how conflicts work, and how disabling sync removes/retains remote data.

## Current state

- Core Data stores meetings/transcriptions locally; UserDefaults stores settings; Keychain stores provider credentials.
- No CloudKit container, entitlement, sync repository, conflict policy, or sync status UI exists.
- Existing storage documentation is currently incomplete; Plan 049 must establish the local boundary first.

## Commands you will need

| Purpose | Command | Expected result |
|---|---|---|
| Storage tests | `make test-sensitive` | exit 0 or baseline classified |
| Architecture | `make arch-check` | exit 0 |
| Build if prototype exists | `make build-agent` | exit 0 |

## Scope

**In scope**:

- A privacy/threat-model and product decision document.
- Inventory of candidate data: vocabulary, non-sensitive settings, metadata, credentials, transcripts, audio.
- Conflict, deletion, opt-in/out, migration, offline, and failure behavior.
- Optional throwaway schema prototype only if it answers a concrete question; no production sync.
- `plans/README.md`

**Out of scope**:

- CloudKit entitlements or production containers.
- Syncing transcripts, audio, API keys, or personal identifiers.
- User-facing toggle/status implementation before approval.

## Steps

### Step 1: Define the data boundary

Classify every candidate field as local-only, optionally syncable, or prohibited. State the privacy rationale and deletion semantics.

**Verify**: no candidate is marked syncable without an explicit conflict/deletion policy.

### Step 2: Evaluate architecture and operational cost

Assess CloudKit account requirements, offline behavior, schema evolution, conflict resolution, opt-out deletion, testing, and release entitlements. Compare the value against local export/backup alternatives.

**Verify**: decision document names a recommended path and rejected alternatives.

### Step 3: Review and decide

Run thermo/security review for any prototype. Record approved, deferred, or rejected status in issue #54. Do not begin implementation without explicit product approval.

**Verify**: no production code or entitlements changed; issue and ledger updated.

## Done criteria

- [ ] Syncable/prohibited/local-only data is explicit.
- [ ] Privacy, conflict, deletion, opt-out, and migration behavior is defined.
- [ ] Local-first guarantees remain intact.
- [ ] No production CloudKit implementation was added during the spike.
- [ ] Issue #54 contains the current decision and priority.
- [ ] `plans/README.md` status row updated.

## STOP conditions

- Syncing metadata can reveal sensitive meeting information without a reviewed policy.
- CloudKit testing requires real user data or unapproved credentials.
- Product ownership cannot decide between sync and local export/backup.

## Maintenance notes

Treat cloud sync as an opt-in product boundary, not a persistence refactor. Reuse repository abstractions only after the data policy is approved.
