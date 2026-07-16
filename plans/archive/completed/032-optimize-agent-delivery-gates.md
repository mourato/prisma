# Plan 032: Optimize agent delivery gates for compact staged validation

> **Executor instructions**: Follow this plan step by step. Run every verification command and confirm the expected result before moving to the next step. If anything in the "STOP conditions" section occurs, stop and report; do not improvise. When done, update the status row for this plan in `plans/README.md` unless a reviewer told you they maintain the index.
>
> **Drift check (run first)**: `git diff --stat 403cf259..HEAD -- AGENTS.md README.md Makefile scripts/hooks/pre-commit scripts/hooks/pre-push scripts/lint.sh scripts/scope-check.sh .agents/skills/delivery-workflow/SKILL.md .agents/docs/build-and-test.md plans/README.md`
> If any in-scope file changed since this plan was written, compare the "Current state" excerpts against the live code before proceeding; on a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: dx
- **Planned at**: commit `403cf259`, 2026-07-10

## Why this matters

Prisma already has useful compact agent commands, scoped validation, and hooks, but the current delivery path is not optimized around token cost. Cheap staged lint/format is disabled by default at commit time, while the push hook runs the verbose `make scope-check` path even though `make scope-check-agent` exists. Full-lane guidance also says `make lint`, but the lint script is non-blocking unless `STRICT_LINT=1`, which can make agents spend tokens reporting a gate that did not actually enforce lint. This plan tightens the sequence: cheap staged checks before commit, compact scoped validation before push, and clear guidance for when agents should run dry-run planning, agent-mode checks, strict lint, and full gates.

## Current state

- `AGENTS.md` defines Fast and Full lanes, but its examples use mostly human-readable commands:

```text
AGENTS.md:162 - Iteration gate (default): lint/format + scoped checks for touched files/subsystem
AGENTS.md:164 - `make scope-check` (smart targeted checks + automatic escalation)
AGENTS.md:176 - Run `make build-test` at key milestones
AGENTS.md:178 - `make build-test`
AGENTS.md:179 - `make lint` (mandatory for all Full-lane changes)
AGENTS.md:191 `make scope-check` is the canonical command for steps 1-3 above during iteration.
```

- `.agents/skills/delivery-workflow/SKILL.md` owns the same policy and already lists compact commands, but does not make compact mode the agent default:

```text
.agents/skills/delivery-workflow/SKILL.md:66 Run staged lint/format checks or equivalent lightweight checks when relevant.
.agents/skills/delivery-workflow/SKILL.md:68 Before push/merge, run `make scope-check`.
.agents/skills/delivery-workflow/SKILL.md:76 Before push/merge, run:
.agents/skills/delivery-workflow/SKILL.md:77   - `make build-test`
.agents/skills/delivery-workflow/SKILL.md:78   - `make lint`
.agents/skills/delivery-workflow/SKILL.md:116 # Compact AI-agent mode
.agents/skills/delivery-workflow/SKILL.md:119 make lint-agent
.agents/skills/delivery-workflow/SKILL.md:120 make scope-check-agent
```

- `Makefile` exposes compact targets:

```text
Makefile:39 `make scope-check` - Run scoped validation
Makefile:40 `make scope-check-agent` - Run scoped validation in compact agent mode
Makefile:46 `make lint-agent` - Run lint with compact machine-readable output
Makefile:175 scope-check:
Makefile:178 scope-check-agent:
Makefile:197 lint-agent:
```

- `scripts/scope-check.sh` can preview decisions without running checks and can emit compact agent results:

```text
scripts/scope-check.sh:37 --base REF
scripts/scope-check.sh:41 --dry-run
scripts/scope-check.sh:43 --agent
scripts/scope-check.sh:424 Scoped validation plan:
scripts/scope-check.sh:430 Strategy: full gate (make build-test)
scripts/scope-check.sh:465 Strategy: scoped checks
scripts/scope-check.sh:518 ma_agent_write_result_json ...
scripts/scope-check.sh:519 ma_agent_emit_result ...
```

- The pre-commit hook currently skips staged lint/format unless `RUN_LINT=1`:

```text
scripts/hooks/pre-commit:3 Fast checks on STAGED files only - non-blocking lint/format
scripts/hooks/pre-commit:20 STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep '\.swift$' || true)
scripts/hooks/pre-commit:29 # Lint/format checks are optional to avoid blocking commits.
scripts/hooks/pre-commit:30 if [ "${RUN_LINT}" != "1" ]; then
scripts/hooks/pre-commit:31     echo "Lint/format checks skipped. Set RUN_LINT=1 to enable."
scripts/hooks/pre-commit:33     echo "pre-commit checks passed"
```

- The pre-push hook runs the non-agent scoped check:

```text
scripts/hooks/pre-push:3 Ensures tests pass before pushing. Set SKIP_TESTS=1 to bypass.
scripts/hooks/pre-push:18 make scope-check ARGS="--base ${DEFAULT_BRANCH}"
```

- `scripts/lint.sh` reports warnings but exits 0 unless `STRICT_LINT=1`:

```text
scripts/lint.sh:14 STRICT_LINT="${STRICT_LINT:-0}"
scripts/lint.sh:95 STATUS="PASS"
scripts/lint.sh:98 if [ "${HAS_ISSUES}" -eq 1 ]; then
scripts/lint.sh:99     if [ "${STRICT_LINT}" -eq 1 ]; then
scripts/lint.sh:100        STATUS="FAIL"
scripts/lint.sh:102        EXIT_CODE=1
scripts/lint.sh:104        STATUS="WARN"
scripts/lint.sh:105        SUMMARY="Lint warnings/issues detected (non-blocking)"
```

- `.agents/docs/build-and-test.md` documents both compact commands and human workflows, but "before commit" still recommends manual test/lint rather than the actual staged hook policy:

```text
.agents/docs/build-and-test.md:65 Agent-optimized commands
.agents/docs/build-and-test.md:70 make scope-check-agent
.agents/docs/build-and-test.md:72 make lint-agent
.agents/docs/build-and-test.md:251 Minimum Verification Gates
.agents/docs/build-and-test.md:273 Before committing | `make test-smoke && make lint`
```

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Shell syntax | `bash -n scripts/hooks/pre-commit scripts/hooks/pre-push scripts/lint.sh scripts/scope-check.sh` | exit 0 |
| Guidance validation | `make guidance-check` | exit 0 |
| Diff hygiene | `git diff --check` | exit 0 |
| Hook no-Swift path | `scripts/hooks/pre-commit` | exit 0 when no Swift files are staged |
| Scoped decision preview | `make scope-check-agent ARGS="--dry-run --base main"` | exit 0 and prints compact `AGENT_*` result lines |
| Agent lint baseline | `make lint-agent` | exit 0; may return `AGENT_STATUS=WARN` if baseline warnings exist |

## Suggested executor toolkit

- Use `delivery-workflow` for risk lane and validation gate changes.
- Use `project-standards` for guidance/index synchronization if skill or `AGENTS.md` text changes.
- Do not use `improve` while implementing this plan; this plan is already the handoff artifact.

## Scope

**In scope**:
- `scripts/hooks/pre-commit`
- `scripts/hooks/pre-push`
- `scripts/lint.sh` only if needed to expose a strict/agent path cleanly
- `Makefile` only for small command aliases such as `lint-strict` / `lint-strict-agent` if they make the workflow clearer
- `AGENTS.md`
- `.agents/skills/delivery-workflow/SKILL.md`
- `.agents/docs/build-and-test.md`
- `README.md`
- `plans/README.md`

**Out of scope**:
- Do not change Swift source, tests, app behavior, CI workflows, release signing, or Xcode project files.
- Do not make pre-commit run tests. Pre-commit should stay a cheap staged lint/format gate.
- Do not make pre-push run full gates unconditionally. It should keep `scope-check` escalation logic.
- Do not weaken High-risk escalation to `make build-test`.
- Do not bypass existing `SKIP_TESTS=1`; keep it available and clearly marked as an emergency bypass.

## Git workflow

- Branch: use the operator-selected branch. If none is selected, create `docs/032-agent-delivery-gates`.
- Commit message: `docs(workflow): optimize agent delivery gates`.
- Keep tooling/guidance edits in one commit unless the strict-lint baseline requires a separate follow-up.

## Steps

### Step 1: Make pre-commit enforce cheap staged lint/format by default

Edit `scripts/hooks/pre-commit` so staged Swift lint/format checks run by default for staged Swift files.

Target behavior:

- If no Swift files are staged, exit 0 quickly.
- If Swift files are staged, run SwiftFormat lint and SwiftLint only on those staged files.
- If SwiftFormat or SwiftLint is missing, exit 1 with the existing install hint.
- If formatting or lint fails for any staged file, exit 1 and print a short remediation message.
- Keep an explicit bypass, for example `SKIP_LINT=1 git commit ...`, with output saying the staged lint/format gate was skipped.
- Do not run tests from pre-commit.

Do not preserve the current "RUN_LINT=1 to enable" default. If you keep `RUN_LINT`, make it backward-compatible only as an alias for enabling the same default path, not as the primary control.

**Verify**: `bash -n scripts/hooks/pre-commit` -> exit 0.

### Step 2: Make pre-push use compact scoped validation by default

Edit `scripts/hooks/pre-push` so it keeps the current `SKIP_TESTS=1` bypass and default-branch detection, but runs the compact scoped gate:

```bash
make scope-check-agent ARGS="--base ${DEFAULT_BRANCH}"
```

Add an explicit verbose override for humans, for example:

```bash
if [ "${PUSH_CHECK_VERBOSE:-0}" = "1" ]; then
    make scope-check ARGS="--base ${DEFAULT_BRANCH}"
else
    make scope-check-agent ARGS="--base ${DEFAULT_BRANCH}"
fi
```

This preserves scope escalation while reducing terminal/token output for agents.

**Verify**: `bash -n scripts/hooks/pre-push` -> exit 0.

### Step 3: Make strict lint an explicit Full-lane command

Inspect the current lint baseline with:

```bash
make lint-agent
STRICT_LINT=1 make lint-agent
```

If `STRICT_LINT=1 make lint-agent` passes, add clear strict aliases to `Makefile`:

```make
lint-strict:
	@STRICT_LINT=1 ./scripts/lint.sh

lint-strict-agent:
	@MA_AGENT_MODE=1 MA_AGENT_LOG_DIR="$(AGENT_LOG_DIR)" STRICT_LINT=1 ./scripts/lint.sh --agent
```

Then update Full-lane docs to prefer `make lint-strict-agent` for AI agents and `make lint-strict` for human strict gates.

If `STRICT_LINT=1 make lint-agent` fails on pre-existing repo-wide baseline warnings, STOP and report the failing summary instead of switching Full-lane policy to strict repo-wide lint. In that case, keep the staged pre-commit lint enforcement from Step 1 and compact pre-push from Step 2, then create a separate follow-up plan to retire the lint baseline.

**Verify**: `make lint-agent` -> exit 0; `STRICT_LINT=1 make lint-agent` -> exit 0 before adding strict lane docs.

### Step 4: Update delivery guidance for token-economical sequencing

Update `AGENTS.md`, `.agents/skills/delivery-workflow/SKILL.md`, `.agents/docs/build-and-test.md`, and `README.md` to describe this sequence:

1. During implementation, run `make scope-check-agent ARGS="--dry-run --base main"` when the agent is unsure which gate will run. This is a planning preview, not proof.
2. Run the smallest meaningful changed-path check: targeted test, `make build-agent`, `make preview-check`, `make arch-check`, or `make guidance-check`.
3. Before commit, rely on the staged pre-commit lint/format gate for staged Swift files; run `make lint-fix` when it fails.
4. Before push, rely on `make scope-check-agent ARGS="--base <default-branch>"` through the pre-push hook.
5. For Full lane, keep `make build-test` mandatory and use strict lint only if Step 3 proved the strict baseline is green.
6. For release or high-confidence final validation, keep `make preflight-agent` or `make deliverable-gate` as explicit heavier gates.

Make the tradeoff explicit: do not run tests before every commit by default because it increases latency and token use; do run staged lint/format before every commit because it is cheap and catches mechanical issues early.

**Verify**: `rg -n "scope-check-agent|pre-commit|pre-push|lint-strict|STRICT_LINT|dry-run" AGENTS.md .agents/skills/delivery-workflow/SKILL.md .agents/docs/build-and-test.md README.md` -> updated references appear.

### Step 5: Validate and update the plan ledger

Update `plans/README.md` row 032 from `TODO` to `DONE` after implementation.

Run:

```bash
bash -n scripts/hooks/pre-commit scripts/hooks/pre-push scripts/lint.sh scripts/scope-check.sh
make guidance-check
git diff --check
make scope-check-agent ARGS="--dry-run --base main"
make lint-agent
```

Expected:

- shell syntax exits 0
- `make guidance-check` exits 0
- `git diff --check` exits 0
- scoped dry-run exits 0 and emits compact `AGENT_*` result lines
- `make lint-agent` exits 0; `AGENT_STATUS` may be `PASS` or `WARN`

## Test plan

No Swift unit tests are required unless implementation accidentally touches Swift source, which is out of scope. Verification is script/guidance focused:

- `bash -n scripts/hooks/pre-commit scripts/hooks/pre-push scripts/lint.sh scripts/scope-check.sh`
- `scripts/hooks/pre-commit` with no staged Swift files
- `make scope-check-agent ARGS="--dry-run --base main"`
- `make lint-agent`
- `make guidance-check`
- `git diff --check`

If strict lint aliases are added, also run:

- `make lint-strict-agent`

## Done criteria

- [ ] Pre-commit runs staged Swift lint/format by default and fails on staged issues.
- [ ] Pre-commit still does not run tests.
- [ ] Pre-commit has an explicit bypass such as `SKIP_LINT=1`.
- [ ] Pre-push runs compact `make scope-check-agent ARGS="--base <default-branch>"` by default.
- [ ] Pre-push keeps `SKIP_TESTS=1` and has a verbose override for human output.
- [ ] Full-lane lint guidance is honest about strict vs non-strict lint behavior.
- [ ] Agent guidance documents dry-run scoped planning before expensive checks.
- [ ] `make guidance-check` exits 0.
- [ ] `git diff --check` exits 0.
- [ ] `plans/README.md` marks plan 032 `DONE`.

## STOP conditions

Stop and report back if:

- `STRICT_LINT=1 make lint-agent` fails before any changes and the only way forward appears to be making repo-wide lint strict in the same patch.
- Changing pre-commit to fail staged lint/format issues exposes a SwiftLint/SwiftFormat behavior that cannot check individual staged files reliably.
- `make scope-check-agent ARGS="--dry-run --base main"` mutates the working tree or does not emit agent result lines.
- The implementation would require changing CI workflows, Swift source, Xcode project files, release scripts, or test semantics.
- Any gate becomes weaker for High-risk changes.

## Maintenance notes

This plan intentionally keeps tests out of pre-commit. The optimized contract is: cheap mechanical checks before commit, compact scoped validation before push, full gates only when lane/risk requires them, and explicit heavier gates for release confidence. Reviewers should check that the resulting guidance teaches agents to run fewer broad commands while still preserving changed-path evidence and High-risk escalation.
