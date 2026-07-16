# Implementation Plans

This is the active plan ledger. The next available plan number is 106.

## Execution rules

- Read the complete plan and honor its STOP conditions.
- Keep one objective per execution slice and use `reuse -> extend -> create`.
- Respect dependencies and reclassify risk against the live scope.
- Preserve one writer in an explicitly isolated worktree.
- Run the plan's required lane, review, and validation before marking it done.
- Use atomic Conventional Commits; do not push unless requested.
- Keep product source out of guidance-only plans.

Status values: `TODO` | `IN PROGRESS` | `DONE` | `BLOCKED` | `REJECTED`.

## Active and current batch

| Plan | Title | Priority | Effort | Depends on | Status |
|---|---|---:|---:|---|---|
| [083](083-add-settings-form-visual-and-preview-gates.md) | Add route-wide visual evidence and truthful preview gates for Settings | P1 | M | 079, 080, 081, 082 | TODO |
| [102](102-close-fast-validation-gate.md) | Make Fast and guidance pushes pass a real technical gate | P0 | M | - | DONE |
| [103](103-align-auto-lane-with-risk-policy.md) | Make auto lane conservative for product Swift changes | P0 | M | 102 | DONE |
| [104](104-centralize-agent-routing-ownership.md) | Make `agent-ops` the single owner of delegation and profile selection | P1 | S | 103 | DONE |
| [105](105-prune-agent-operational-context.md) | Prune dead agent context and make guidance drift fail closed | P1 | L | 104 | DONE |

## Dependency order

The remediation batch is `102 -> 103 -> 104 -> 105`. Plan 083 is independent.

## Archives

- [2026-07-12 ledger history](archive/2026-07-12-plan-ledger-history.md)
- [2026-07-16 ledger history](archive/2026-07-16-plan-ledger-history.md)
- [Completed plan files](archive/completed/)

## Current decisions

- Keep this root ledger active-only; archive completed batches with Git history.
- Keep `.agents/SKILLS_INDEX.md` as the single skill catalog.
- Keep exact-range technical validation fail closed; reuse only compatible PASS evidence.
