# Plan 052: Design an Assistant automation-rule spike

> **Executor instructions**: This is a product/architecture design spike. Do not build a general automation engine during this plan. Any prototype or code change requires thermo review and must remain behind an explicit boundary.
>
> **Drift check**: `git diff --stat 80ed5788..HEAD -- Packages/MeetingAssistantCore/Sources/UI/Services/AssistantVoiceCommand Packages/MeetingAssistantCore/Sources/Infrastructure/Services Packages/MeetingAssistantCore/Sources/UI/Services/Assistant* Packages/MeetingAssistantCore/Tests plans/README.md`

## Status

- **Priority**: P3
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/042-decompose-recording-runtime-hotspots.md
- **Category**: direction
- **Planned at**: commit `80ed5788`, 2026-07-12
- **Related issue**: #91

## Why this matters

The MacroWhisper analysis identifies voice/app/mode triggers and deterministic action priority as a possible extension of Prisma's existing Assistant, integrations, deep-link, script, and shortcut infrastructure. It is not a current bug and would expand product scope, so the first deliverable must be a bounded design decision rather than a broad feature implementation.

## Current state

- Assistant processing is already split into recording, transcription, AI, normalization, and dispatch phases.
- Existing integration dispatch, script execution, text selection, shortcuts, and settings persistence are reusable blocks.
- No persisted automation rule model, evaluator, conflict policy, or CLI surface exists.

## Commands you will need

| Purpose | Command | Expected result |
|---|---|---|
| Assistant tests | `swift test --package-path Packages/MeetingAssistantCore --filter 'Assistant.*Tests|Integration.*Tests'` | exit 0 |
| Build/lint | `make build-agent && make lint` | exit 0 |
| Full gate if prototype added | `make build-test` | exit 0, baseline classified |

## Scope

**In scope**:

- A design note defining an MVP boundary, rule/trigger/action vocabulary, deterministic conflict resolution, safety constraints, and integration points.
- Optional pure evaluator prototype with no persistence or shell execution, only if it materially resolves an open design question.
- Tests for evaluator determinism if a prototype is built.
- `plans/README.md`

**Out of scope**:

- A user-facing automation editor, CLI, CloudKit sync, arbitrary shell execution, or broad rule persistence.
- Copying MacroWhisper's implementation or UX.

## Steps

### Step 1: Define the smallest product boundary

Decide whether Prisma should support one-shot voice triggers, app/mode conditions, or both. Specify safety/confirmation rules and how actions reuse existing dispatchers.

**Verify**: design note contains explicit included/excluded cases and open decisions.

### Step 2: Validate architecture fit

Map the proposed domain contracts to existing Assistant phase/integration boundaries. Reject any design that requires a second recording pipeline or bypasses existing credential/security policies.

**Verify**: architecture map cites concrete current types and has no duplicate pipeline.

### Step 3: Review and decide

Run thermo review if a prototype exists; otherwise perform a documented architecture review. Record whether to proceed, defer, or reject the feature in issue #91.

**Verify**: issue has a decision and the ledger status is updated.

## Done criteria

- [ ] MVP scope, safety model, and vocabulary are documented.
- [ ] Existing Assistant/integration boundaries are reused in the design.
- [ ] No general automation engine or unsafe execution surface was added.
- [ ] Any prototype is deterministic, tested, and reviewed.
- [ ] Issue #91 is updated with the decision.
- [ ] `plans/README.md` status row updated.

## STOP conditions

- Product scope cannot be decided without user research or a maintainer decision.
- The design requires arbitrary shell/script execution without a safety model.
- The proposal duplicates Assistant recording or dispatch infrastructure.

## Maintenance notes

Keep this direction separate from the current recording workflow. Revisit only after the core recording/runtime decomposition is stable.
