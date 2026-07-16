# Plan 031: Consolidate debugging and diagnostic signal guidance

> **Executor instructions**: Follow this plan step by step. Run every verification command and confirm the expected result before moving to the next step. If anything in the "STOP conditions" section occurs, stop and report; do not improvise. When done, update the status row for this plan in `plans/README.md` unless a reviewer told you they maintain the index.
>
> **Drift check (run first)**: `git diff --stat 491b4bb7..HEAD -- .agents/skills/debugging-strategies .agents/skills/observability-diagnostics .agents/skills/audio-realtime .agents/skills/macos-app-engineering .agents/SKILLS_INDEX.md .agents/skills/SKILLS_TAXONOMY.md .agents/docs/skill-routing.md plans/README.md`
> If any in-scope file changed since this plan was written, compare the "Current state" excerpts against the live code before proceeding; on a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: docs
- **Planned at**: commit `491b4bb7`, 2026-07-10

## Why this matters

`debugging-strategies` and `observability-diagnostics` are small, tightly coupled skills. The former tells agents to investigate unknown causes and add small instrumentation; the latter defines the structure, redaction, and failure-signature rules for that instrumentation. A single `debugging-diagnostics` skill should reduce one routing decision while preserving the important privacy-safe logging rules.

## Current state

- `.agents/skills/debugging-strategies/SKILL.md` owns unknown-root-cause investigation and already points to observability:

```text
.agents/skills/debugging-strategies/SKILL.md:10 Use this skill as the canonical owner for cross-cutting debugging methodology in Prisma.
.agents/skills/debugging-strategies/SKILL.md:37 Add the smallest useful instrumentation.
.agents/skills/debugging-strategies/SKILL.md:57 Add logging around boundaries, not everywhere.
.agents/skills/debugging-strategies/SKILL.md:58 Prefer existing diagnostics surfaces and stable log keys.
.agents/skills/debugging-strategies/SKILL.md:98 ../observability-diagnostics/SKILL.md
```

- `.agents/skills/observability-diagnostics/SKILL.md` owns diagnostic data shape and explicitly complements debugging:

```text
.agents/skills/observability-diagnostics/SKILL.md:10 Use this skill to shape diagnostic data in Prisma.
.agents/skills/observability-diagnostics/SKILL.md:12 Own logging structure, telemetry naming, payload redaction, and failure-signature guidance.
.agents/skills/observability-diagnostics/SKILL.md:13 Complement `../debugging-strategies/SKILL.md` by improving what the system emits before and during investigation.
.agents/skills/observability-diagnostics/SKILL.md:46 Never log secrets, raw credentials, or sensitive transcript content.
.agents/skills/observability-diagnostics/SKILL.md:52 Capture the first failing stage and the first actionable mismatch.
```

- `.agents/docs/skill-routing.md` currently has two adjacent sections:

```text
.agents/docs/skill-routing.md:102 Debugging, Crashes, and Flaky Behavior
.agents/docs/skill-routing.md:104 Primary: `debugging-strategies`
.agents/docs/skill-routing.md:109 Complementary: `observability-diagnostics`
.agents/docs/skill-routing.md:115 Logging, Telemetry, and Diagnostics
.agents/docs/skill-routing.md:117 Primary: `observability-diagnostics`
```

- `.agents/SKILLS_INDEX.md:68-70` also routes crashes to `debugging-strategies` and diagnostics to `observability-diagnostics`.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Find references | `rg -n "debugging-strategies|observability-diagnostics" .agents AGENTS.md plans/README.md` | Only historical plan text may remain after the migration |
| Count skills | `find .agents/skills -maxdepth 2 -name SKILL.md -print | sort | wc -l` | `22` if plan 030 has not run; `20` if plan 030 has already run |
| Guidance validation | `make guidance-check` | exit 0 |
| Diff hygiene | `git diff --check` | exit 0 |

## Scope

**In scope**:
- Create `.agents/skills/debugging-diagnostics/SKILL.md`.
- Remove `.agents/skills/debugging-strategies/` and `.agents/skills/observability-diagnostics/`.
- Update references in `.agents/skills/audio-realtime/SKILL.md`, `.agents/skills/macos-app-engineering/SKILL.md`, `.agents/SKILLS_INDEX.md`, `.agents/skills/SKILLS_TAXONOMY.md`, `.agents/docs/skill-routing.md`, and `plans/README.md`.

**Out of scope**:
- Do not modify logging implementation, telemetry implementation, Swift source, tests, or Makefile targets.
- Do not merge `audio-realtime`; low-latency audio remains a specialist owner.
- Do not merge `swift-concurrency-expert`; concrete actor isolation and `Sendable` diagnostics remain separate.
- Do not weaken the redaction rule against logging secrets, credentials, or raw transcript content.

## Git workflow

- Work on the branch or checkout the operator selected. If no branch exists, follow `AGENTS.md`.
- Commit message: `docs(agents): consolidate debugging diagnostics skill`.
- Keep this as one docs/guidance commit.

## Steps

### Step 1: Create the consolidated skill

Create `.agents/skills/debugging-diagnostics/SKILL.md` with frontmatter like:

```yaml
---
name: debugging-diagnostics
description: This skill should be used when the user asks to debug bugs, investigate crashes, analyze flaky behavior, trace unknown root causes, add logging, improve telemetry, or standardize diagnostic signals in Prisma.
---
```

The body must include:

1. Role: canonical owner for unknown-root-cause investigation and diagnostic signal design.
2. Scope boundaries: use it for repro, hypothesis testing, logging, telemetry names, redaction, failure signatures, and metric correlation; delegate confirmed audio hot-path issues to `../audio-realtime/SKILL.md`, confirmed SwiftUI/app fixes to `../macos-app-engineering/SKILL.md`, and concrete actor isolation or `Sendable` compiler diagnostics to `../swift-concurrency-expert/SKILL.md`.
3. Investigation workflow from `debugging-strategies`.
4. Diagnostic standards from `observability-diagnostics`, especially logging, telemetry, redaction, and failure signatures.
5. Existing repository references from `observability-diagnostics`.
6. Useful local commands from `debugging-strategies`.
7. Related skills: `audio-realtime`, `macos-app-engineering`, `swift-concurrency-expert`.

Keep the consolidated file short; do not paste every reference asset description unless it still exists and is useful.

**Verify**: `test -f .agents/skills/debugging-diagnostics/SKILL.md && rg -n "Investigation Workflow|Diagnostic Standards|Redaction|Failure Signatures" .agents/skills/debugging-diagnostics/SKILL.md` -> all four headings/phrases appear.

### Step 2: Remove obsolete split skills

Delete:

- `.agents/skills/debugging-strategies/`
- `.agents/skills/observability-diagnostics/`

If `debugging-strategies` contains useful `assets/` or `references/` files, either move the still-relevant files under `.agents/skills/debugging-diagnostics/` and update links, or delete stale ones. Do not leave an orphaned folder.

**Verify**: `test ! -e .agents/skills/debugging-strategies && test ! -e .agents/skills/observability-diagnostics` -> exit 0.

### Step 3: Update routing and references

Update:

- `.agents/SKILLS_INDEX.md`: replace both rows and quick-reference entries with `debugging-diagnostics`.
- `.agents/skills/SKILLS_TAXONOMY.md`: replace both rows with one runtime/performance row. Keep `audio-realtime` and `swift-concurrency-expert` as specialist owners.
- `.agents/docs/skill-routing.md`: merge the "Debugging, Crashes, and Flaky Behavior" and "Logging, Telemetry, and Diagnostics" sections into one `debugging-diagnostics` section.
- `.agents/skills/audio-realtime/SKILL.md`: replace references to `debugging-strategies` with `debugging-diagnostics`.
- `.agents/skills/macos-app-engineering/SKILL.md`: replace references to `debugging-strategies` with `debugging-diagnostics`.
- `plans/README.md`: mark this plan `DONE` when finished.

**Verify**: `rg -n "debugging-strategies|observability-diagnostics" .agents AGENTS.md` -> no matches.

### Step 4: Validate guidance

Run:

```bash
make guidance-check
git diff --check
find .agents/skills -maxdepth 2 -name SKILL.md -print | sort | wc -l
```

Expected:

- `make guidance-check` exits 0.
- `git diff --check` exits 0.
- Skill count is `22` if plan 030 has not run; `20` if plan 030 has already run.

## Test plan

No Swift tests are required because this is documentation/guidance-only. Validate through:

- `make guidance-check`
- `git diff --check`
- reference cleanup using `rg`
- skill count using `find ... | wc -l`

## Done criteria

- [ ] `.agents/skills/debugging-diagnostics/SKILL.md` exists and contains investigation and diagnostic-signal rules.
- [ ] `.agents/skills/debugging-strategies/` and `.agents/skills/observability-diagnostics/` are removed.
- [ ] No active `.agents` or `AGENTS.md` reference points to the removed skill names.
- [ ] Redaction guidance still explicitly forbids logging secrets, credentials, or raw transcript content.
- [ ] `audio-realtime`, `macos-app-engineering`, and `swift-concurrency-expert` remain separate skills.
- [ ] `make guidance-check` exits 0.
- [ ] `git diff --check` exits 0.
- [ ] `plans/README.md` status row for plan 031 is updated.

## STOP conditions

Stop and report back if:

- The current files do not match the excerpts above after the drift check.
- Moving `debugging-strategies` reference assets breaks `make guidance-check` and the fix is not just a link/path update.
- The consolidation would remove or weaken privacy/redaction guidance.
- The work appears to require source-code logging or telemetry changes.

## Maintenance notes

After this lands, debugging plans should start with reproduction and hypothesis narrowing, then design diagnostic signals only where needed. Reviewers should check that the new skill does not encourage noisy logs and that it keeps privacy-safe payload rules visible.
