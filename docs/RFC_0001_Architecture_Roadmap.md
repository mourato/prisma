# RFC 0001 — Architecture Roadmap

Status: Accepted (B2 consolidation complete on `main`)
Last updated: 2026-02-06

## Context

The codebase follows a layered architecture (Presentation / Domain / Data / Infrastructure) with strict real-time constraints in the audio path.

This RFC records the selected architecture direction and its current implementation status.

## Goals

- Keep the audio hot path safe and allocation-minimal.
- Improve persistence scalability for large transcription datasets.
- Reduce coupling in `MeetingAssistantCore` through explicit module boundaries.
- Keep decisions reviewable and documented.
- Standardize communication: English-only docs and code comments.

## Non-goals

- Risky large rewrites in the real-time audio pipeline.
- Abstractions without operational payoff.

---

## Proposal A — Storage migration (JSON → Core Data)

### Decision
Accepted as ongoing migration.

### Current status
- Core Data path exists and is active for key flows.
- Hybrid/compatibility behavior remains for legacy data paths.
- Full migration hardening and legacy cleanup are still pending.

### Next milestone
- Define and execute explicit one-time migration checkpoints.
- Keep JSON as import/export format only.

---

## Proposal B — `MeetingAssistantCore` modular split

### Decision
Accepted as **B2** (enforced multi-target split).

### Implemented module layout
- `MeetingAssistantCoreCommon`
- `MeetingAssistantCoreDomain`
- `MeetingAssistantCoreInfrastructure`
- `MeetingAssistantCoreData`
- `MeetingAssistantCoreAudio`
- `MeetingAssistantCoreAI`
- `MeetingAssistantCoreUI`
- `MeetingAssistantCore` (compatibility export layer)

### Validation status (2026-02-06)
- `make build`: passed
- `make test`: passed (147 tests, 16 skipped, 0 failures)

### Notes
- Module access-control and import boundaries were adjusted to unblock compilation/tests.
- Test target dependencies were aligned with module ownership where internal symbols are used.

---

## Proposal C — Concurrency and `Sendable` hygiene

### Decision
Accepted and ongoing.

### Current status
- Concurrency issues blocking the B2 split were resolved for this phase.
- Remaining `@unchecked Sendable` usage should continue to be audited case-by-case.

### Rule
Use actors or explicit isolation by default; keep `@unchecked Sendable` only where performance constraints justify it.

---

## Proposal D — AI isolation strategy (process boundaries)

### Decision
Accepted as staged approach.

### Current status
- Local ASR stays in-process for performance.
- Additional XPC isolation for remote-provider concerns remains optional and should be triggered by concrete reliability/security needs.

---

## Proposal E — English-only docs/comments

### Decision
Accepted and enforced.

### Current status
- Project standards now explicitly require English for documentation and code comments.
- `AGENTS.md`, skills, and `README.md` were updated to reflect this policy.

---

## Operational outcomes from this phase

- B2 modular split is fully integrated on `main` with green build/tests.
- Project standards and skills were updated to the modular layout and current paths.
- Architecture decisions are now codified as actionable guidance instead of open questions.

## Next actions

1. Complete the remaining storage migration cleanup and deprecate legacy-only paths.
2. Reduce lint debt from pre-existing large files (especially `RecordingManager`) without changing behavior.
3. Add lightweight architecture checks to CI (module-boundary and import-surface checks).
