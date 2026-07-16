# Plan 100: Pre-commit format, agent lint/test ladder, and Option-C pre-push

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer told you they maintain the index.
>
> **Drift check (run first)**: `git diff --stat c2fc714a..HEAD -- scripts/hooks/pre-commit scripts/hooks/pre-push scripts/validate-agent.sh scripts/scope-check.sh scripts/tests/workflow-test.sh AGENTS.md .agents/skills/delivery-workflow .agents/docs/build-and-test.md README.md plans/README.md`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: plans/087-fix-pre-push-reliability-and-agent-ops-followups.md, plans/089-slim-agent-validation-loop-and-pass-reuse.md
- **Category**: dx
- **Planned at**: commit `c2fc714a`, 2026-07-16
- **Completed**: 2026-07-16 on branch `chore/100-pre-commit-format-and-option-c-pre-push`

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `High/Full`
- **Parallelizable**: `no`
- **Reviewer required**: `yes` — changes merge-gate semantics for every push
- **Rationale**: Hooks + validate-agent + agent loop guidance; fail-closed Full path must stay mandatory for infra/audio/etc.
- **Escalate when**: Implementation would remove Full pre-push entirely, or would format the whole monorepo on every commit.

## Why this matters

Scripts are cheaper and more reliable than agents for mechanical work. Today:

- Pre-commit only **checks** SwiftFormat/SwiftLint and tells humans/agents to run
  `make lint-fix` (token-expensive retry loops).
- Pre-push always runs `validate-agent --lane auto --committed`, which still executes
  Fast scoped tests even when the agent already ran (or should have run) end-of-task
  module tests — slow pushes for Low/Fast work.
- Agent guidance after plan 089 says “trust pre-push”, which under-emphasizes
  mandatory end-of-task lint and the test ladder.

This plan makes scripts own formatting at commit time, makes agents own lint +
scaled tests at task close, and switches pre-push to **Option C**:

- **Always** run a light pre-push.
- Run **Full** `validate-agent` **only** when auto-lane decision would be Full
  (scripts/Makefile/Xcode, audio/data/security/concurrency, large delta, etc.).
- When auto would be Fast: do **not** re-run Fast scoped tests on push.

## Current state

### Pre-commit (check-only)

```text
scripts/hooks/pre-commit:78-110
# SwiftFormat --lint and SwiftLint lint on staged files only
# On failure: "Run 'make lint-fix' to fix before committing."
```

### Pre-push (always auto validate-agent)

```text
scripts/hooks/pre-push:146-156
args="--lane auto --committed --base ${base_ref} --head ${head_ref}"
make validate-agent ARGS="${args}"
```

`validate-agent` Full lane runs `lint-strict` + `make build-test` (Xcode suite).
Fast lane runs `scope-check-agent` (targeted tests / possible `test-full`).

### Agent loop (089)

`.agents/skills/delivery-workflow/SKILL.md` still frames Low/Fast as
check → commit → push with pre-push owning committed validation, and does not
require end-of-task lint or the explicit test ladder.

### Manual format tools

- `make format` — SwiftFormat on `App` + `Packages/.../Sources` (whole trees)
- `make lint-fix` — SwiftFormat + SwiftLint `--fix` on those trees

Pre-commit must **not** call whole-tree format; only staged paths.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Hook syntax | `bash -n scripts/hooks/pre-commit scripts/hooks/pre-push` | exit 0 |
| Workflow fixtures | `make workflow-test` | `WORKFLOW_TEST_STATUS=PASS` |
| Guidance | `make guidance-check` | exit 0 |
| Full gate (scripts changed) | `make validate-agent ARGS="--lane full --no-reuse --agent"` | exit 0 |
| Pre-push Fast path smoke | fixture / dry protocol in workflow-test | light path, no `build-test` |
| Pre-push Full path smoke | fixture with `scripts/*` change | Full/`build-test` invoked or equivalent |

## Suggested executor toolkit

- `delivery-workflow` for loop/gate text
- `project-standards` for AGENTS alignment
- Do not weaken Full triggers in `scope-check.sh` without explicit STOP

## Scope

**In scope**:

- `scripts/hooks/pre-commit`
- `scripts/hooks/pre-push`
- `scripts/validate-agent.sh` only if needed for a `--lane auto --push-light` /
  dry-run-then-conditional-full helper (prefer keeping logic in the hook +
  existing `--dry-run` / `--lane` flags; extract a tiny helper under
  `scripts/lib/` only if the hook would become unreadable)
- `scripts/tests/workflow-test.sh` (+ optional new `scripts/tests/*-test.sh`)
- `AGENTS.md`
- `.agents/skills/delivery-workflow/SKILL.md`
- `.agents/skills/delivery-workflow/references/delivery-workflow-details.md`
- `.agents/docs/build-and-test.md`
- `README.md` (hooks blurb only, if present)
- `plans/README.md`

**Out of scope**:

- Adding GitHub Actions CI as a substitute merge gate (explicit non-goal of Option C)
- Changing SwiftLint/SwiftFormat rule sets
- Changing Full-lane contents (`lint-strict` + `build-test`)
- Weakening `scope-check` Full triggers for `scripts/*`, audio, etc.
- Whole-tree format on every commit
- Making `SKIP_TESTS=1` the normal path

## Policy contract (implement exactly)

### A. Pre-commit — apply format (staged only)

When staged `.swift` files exist and `SKIP_LINT` is not `1`:

1. Run SwiftFormat **write** mode on each staged file (not `--lint`).
2. Optionally run SwiftLint `--fix` on those same staged files (recommended;
   keeps autofix in the script layer).
3. `git add` the staged Swift paths again so formatting is included in the commit.
4. Re-run SwiftFormat `--lint` + SwiftLint lint on those paths; fail if anything
   remains that autofix could not fix.
5. Do **not** format unstaged/untracked files.
6. Keep `SKIP_LINT=1` as emergency bypass only.

### B. Agent routine — lint + test ladder

Update delivery-workflow / AGENTS so agents must:

| Phase | Required when | Action |
|---|---|---|
| During task | Behavior/Swift changed | Targeted unit tests for the slice |
| End of task/plan | Any `.swift` touched | Lint that fails closed on the delta (prefer strict/changed-path; at minimum `make lint-strict-agent` or equivalent scoped strict check — do not rely on advisory `make lint` that exits 0 with warnings) |
| End of task/plan | Behavior changed | Step up to **affected-module** validation: `make validate-agent ARGS="--lane auto --base main --agent"` on a clean tree (or `--committed` after commit). This is the Fast scoped / auto path — **not** optional for product behavior changes |
| Escalate to Full suite | Auto/Full triggers | `make validate-agent ARGS="--lane full ..."` or let Option-C pre-push run Full |
| Guidance-only | No Swift / no scripts | `make guidance-check`; no product test ladder |

Clarify vocabulary in guidance:

- **Targeted tests** = per-file/`--test` during the slice
- **Affected-module / auto Fast** = `validate-agent --lane auto` Fast path (scope-check)
- **Full suite** = Full lane `build-test` (Xcode), not merely `make test-full`

### C. Pre-push — Option C

For each branch push range (keep existing base/head / empty-base / ref safety):

1. Compute the auto lane the same way `validate-agent --lane auto` would
   (reuse `scope-check.sh --dry-run --agent --committed ...` decision JSON
   `decision.selectedLane`).
2. **If `selectedLane=full`:** run
   `make validate-agent ARGS="--lane full --committed --base ... --head ... --agent"`
   (reuse fingerprints when valid). This remains mandatory for scripts/audio/infra/etc.
3. **If `selectedLane=fast`:** run the **light** path only:
   - Do **not** run `scope-check` targeted tests, `test-full`, or `build-test`.
   - Light path minimum: succeed after printing that Fast push relies on
     end-of-task agent/module validation; optionally verify working tree is
     not required; keep ref/base validation.
   - Allowed cheap extras (optional, keep total seconds-low): confirm no
     unexpected empty range; do **not** add Xcode.
4. Preserve `SKIP_TESTS=1` as emergency bypass with a loud warning.
5. Preserve rust-audio failure hints when Full path runs and staging fails.
6. Update workflow fixtures: Fast-range push must not invoke `build-test`;
   Full-range push (e.g. touch `scripts/foo.sh` in fixture) must invoke Full.

## Git workflow

- Branch: `chore/100-pre-commit-format-and-option-c-pre-push`
- Suggested commits:
  1. `fix(hooks): apply staged SwiftFormat on pre-commit`
  2. `fix(hooks): Option-C pre-push (light Fast, mandatory Full)`
  3. `test(workflow): cover Option-C pre-push and format pre-commit`
  4. `docs(delivery): agent lint + test ladder; Option-C push policy`
- Do NOT push unless asked.

## Steps

### Step 1: Pre-commit applies staged format (+ lint fix)

Rewrite the Swift section of `scripts/hooks/pre-commit` per Policy A.

**Verify**:

```bash
bash -n scripts/hooks/pre-commit
# Manual or fixture: stage an intentionally misformatted Swift file → commit
# succeeds and the commit blob contains formatted code; unstaged files untouched.
```

Add/extend a workflow fixture that uses a temp repo + stub swiftformat/swiftlint
or real tools if available.

### Step 2: Implement Option-C pre-push

Edit `scripts/hooks/pre-push` per Policy C. Prefer:

```bash
# 1) dry-run auto decision on committed range
# 2) if full -> validate-agent --lane full --committed ...
# 3) if fast -> light pass (no test/build)
```

Do not call `validate-agent --lane auto` on the Fast path (that still runs tests).

**Verify**: `bash -n scripts/hooks/pre-push`; update `test_pre_push_protocol` and add
explicit Fast-vs-Full cases in `scripts/tests/workflow-test.sh`.

### Step 3: Guidance — lint + test ladder + Option C

Update:

- `AGENTS.md` (short Agent Validation Loop pointer)
- `delivery-workflow/SKILL.md` Agent validation loop (Policy B + C)
- `delivery-workflow-details.md` Hook section
- `.agents/docs/build-and-test.md` Quick Navigation / hooks
- `README.md` if it still says pre-push always runs scoped/full validation the old way

Replace “trust pre-push to run Fast tests” with “end-of-task module validation is
required; pre-push is light unless auto is Full”.

**Verify**: `make guidance-check`

### Step 4: Validation

```bash
make workflow-test
make guidance-check
make validate-agent ARGS="--lane full --no-reuse --agent"
```

Update `plans/README.md` status to DONE; next plan number → 101.

## Test plan

- Pre-commit: staged format mutates + re-stages; unstaged untouched; `SKIP_LINT=1` bypass
- Pre-push Fast fixture: no `build-test` / no scope-check test execution
- Pre-push Full fixture (scripts change): Full lane runs (or dry-run decision full + full command invoked)
- Existing committed isolation / reuse fixtures still PASS where applicable
- No product XCTest changes required

## Done criteria

- [x] Pre-commit applies SwiftFormat (and recommended SwiftLint `--fix`) to staged Swift files and re-stages them
- [x] Pre-commit still fails on residual non-autofixable lint
- [x] Pre-push Fast path does not run targeted tests / `test-full` / `build-test`
- [x] Pre-push Full path still runs Full `validate-agent` when auto decision is Full
- [x] Agent guidance mandates end-of-task lint (Swift) + affected-module auto validation for behavior changes
- [x] `make workflow-test` PASS
- [x] `make guidance-check` PASS
- [x] `make validate-agent ARGS="--lane full --no-reuse --agent"` PASS
- [x] `plans/README.md` updated

## STOP conditions

- Fast pre-push path would still invoke `validate-agent --lane auto` (that reintroduces Fast tests) — stop and fix.
- Full triggers would be narrowed to make pushes faster — stop; Option C only changes Fast-path push cost.
- Pre-commit formats entire `App/` or `Packages/` trees — stop; staged-only.
- Residual lint after autofix is ignored — stop; must fail closed.
- Fixture cannot distinguish Fast vs Full push behavior — stop and redesign the test before merging.

## Maintenance notes

- Reviewers should reject “pre-push does nothing” PRs; light ≠ empty of policy, and Full remains mandatory for infra/audio/etc.
- If agents skip end-of-task module tests on Fast work, regressions can reach remote — reinforce in review until CI exists; do not silently restore Fast tests on every push without a new plan.
- `make format` / `make lint-fix` remain available for whole-tree cleanup; hooks stay staged-scoped.
- Future CI can mirror Option C (light PR checks + Full on infra paths) without changing this contract.
