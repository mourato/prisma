# Plan 030: Consolidate delivery workflow guidance into one skill

> **Executor instructions**: Follow this plan step by step. Run every verification command and confirm the expected result before moving to the next step. If anything in the "STOP conditions" section occurs, stop and report; do not improvise. When done, update the status row for this plan in `plans/README.md` unless a reviewer told you they maintain the index.
>
> **Drift check (run first)**: `git diff --stat 491b4bb7..HEAD -- .agents/skills/task-lifecycle .agents/skills/quality-assurance .agents/skills/git-workflow .agents/skills/testing-xctest .agents/skills/thermo-nuclear-code-quality-review .agents/skills/macos-app-engineering .agents/skills/intelligence-kernel .agents/skills/code-quality .agents/skills/project-standards .agents/SKILLS_INDEX.md .agents/skills/SKILLS_TAXONOMY.md .agents/docs/skill-routing.md AGENTS.md plans/README.md`
> If any in-scope file changed since this plan was written, compare the "Current state" excerpts against the live code before proceeding; on a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: LOW
- **Depends on**: none
- **Category**: docs
- **Planned at**: commit `491b4bb7`, 2026-07-10

## Why this matters

`task-lifecycle`, `quality-assurance`, and `git-workflow` describe one delivery workflow split across three skills. Smaller executor models must currently read and reconcile all three to classify risk, choose checks, commit safely, and report evidence. Consolidating them into a single `delivery-workflow` skill should reduce routing hops, remove cross-skill ping-pong, and lower the Prisma skill count from 23 to 21 without weakening the existing risk, validation, or Git rules.

## Current state

- `.agents/skills/task-lifecycle/SKILL.md` is a router for macro flow and delegates to QA and Git:

```text
.agents/skills/task-lifecycle/SKILL.md:10 Use this skill as the lightweight router for Prisma task execution.
.agents/skills/task-lifecycle/SKILL.md:18 This skill owns macro flow only.
.agents/skills/task-lifecycle/SKILL.md:19 Use `../quality-assurance/SKILL.md` for validation commands and escalation.
.agents/skills/task-lifecycle/SKILL.md:20 Use `../git-workflow/SKILL.md` for Git operations.
.agents/skills/task-lifecycle/SKILL.md:52 Fast lane merge gate: `make scope-check`
.agents/skills/task-lifecycle/SKILL.md:53 Full lane merge gate: `make build-test` + `make lint`
```

- `.agents/skills/quality-assurance/SKILL.md` owns command mapping but depends on lifecycle for lane policy:

```text
.agents/skills/quality-assurance/SKILL.md:14 `AGENTS.md` and `../task-lifecycle/SKILL.md` own risk classification and lane policy.
.agents/skills/quality-assurance/SKILL.md:15 This skill translates those lanes into concrete validation commands.
.agents/skills/quality-assurance/SKILL.md:21 Own command mapping, validation order, escalation triggers, and scope-based checks.
.agents/skills/quality-assurance/SKILL.md:22 Do not own risk classification, lane selection, Git workflow, or review output formatting.
.agents/skills/quality-assurance/SKILL.md:60 Targeted tests (`./scripts/run-tests.sh --suite dev --file ...` / `--test ...`)
.agents/skills/quality-assurance/SKILL.md:65 Canonical automation for this sequence: `make scope-check`.
```

- `.agents/skills/git-workflow/SKILL.md` owns Git mechanics but depends on lifecycle and QA for the gate:

```text
.agents/skills/git-workflow/SKILL.md:12 Own branch, commit, PR, merge, and cleanup mechanics.
.agents/skills/git-workflow/SKILL.md:19 Use `../task-lifecycle/SKILL.md` for risk classification and lifecycle sequencing.
.agents/skills/git-workflow/SKILL.md:20 Use `../quality-assurance/SKILL.md` for concrete validation commands and merge gates.
.agents/skills/git-workflow/SKILL.md:30 Use Conventional Commits: `<type>(<optional-scope>): <summary>`.
.agents/skills/git-workflow/SKILL.md:34 Before push/merge, run the lane gate selected by `task-lifecycle` and mapped by `quality-assurance`.
```

- `.agents/skills/project-standards/SKILL.md` currently preserves the three-way split:

```text
.agents/skills/project-standards/SKILL.md:39 Keep workflow ownership explicit and non-overlapping: `task-lifecycle` owns macro flow and risk lanes, `quality-assurance` owns command mapping and validation strategy, `git-workflow` owns Prisma Git mechanics...
```

- `.agents/SKILLS_INDEX.md:89-94` has an "Engineering Workflow Ownership" section listing `task-lifecycle`, `quality-assurance`, and `git-workflow` separately.
- `.agents/docs/skill-routing.md:160-166` separates verification policy from XCTest implementation, and `.agents/docs/skill-routing.md:221-227` lists `git-workflow`, `quality-assurance`, and `task-lifecycle` as separate direct-access skills.
- Keep `.agents/skills/testing-xctest/SKILL.md` separate. It owns XCTest code structure, not lane or command policy:

```text
.agents/skills/testing-xctest/SKILL.md:10 Use this skill for XCTest implementation details in Prisma.
.agents/skills/testing-xctest/SKILL.md:26 Do not use this skill to choose lane policy or merge gates.
```

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Find references | `rg -n "task-lifecycle|quality-assurance|git-workflow" .agents AGENTS.md plans/README.md` | Only historical plan text may remain after the migration |
| Count skills | `find .agents/skills -maxdepth 2 -name SKILL.md -print | sort | wc -l` | `21` after this plan if plan 031 has not run; `20` if plan 031 has already run |
| Guidance validation | `make guidance-check` | exit 0 |
| Diff hygiene | `git diff --check` | exit 0 |

## Scope

**In scope**:
- Create `.agents/skills/delivery-workflow/SKILL.md`.
- Remove `.agents/skills/task-lifecycle/`, `.agents/skills/quality-assurance/`, and `.agents/skills/git-workflow/`.
- Update references in `.agents/skills/testing-xctest/SKILL.md`, `.agents/skills/thermo-nuclear-code-quality-review/SKILL.md`, `.agents/skills/macos-app-engineering/SKILL.md`, `.agents/skills/intelligence-kernel/SKILL.md`, `.agents/skills/code-quality/SKILL.md`, `.agents/skills/project-standards/SKILL.md`, `.agents/SKILLS_INDEX.md`, `.agents/skills/SKILLS_TAXONOMY.md`, `.agents/docs/skill-routing.md`, `AGENTS.md`, and `plans/README.md`.

**Out of scope**:
- Do not merge `testing-xctest`; it remains the XCTest implementation owner.
- Do not merge `thermo-nuclear-code-quality-review`; it remains the default review owner.
- Do not change `Makefile`, scripts, CI, Swift source, or tests.
- Do not delete historical references inside already completed plan descriptions except when they are part of the active status/dependency text that should guide future agents.

## Git workflow

- Work on the branch or checkout the operator selected. If no branch exists, follow `AGENTS.md`.
- Commit message: `docs(agents): consolidate delivery workflow skill`.
- Keep this as one docs/guidance commit.

## Steps

### Step 1: Create the consolidated skill

Create `.agents/skills/delivery-workflow/SKILL.md` with frontmatter like:

```yaml
---
name: delivery-workflow
description: This skill should be used when the user asks to classify risk, select a Prisma execution lane, choose validation commands, run quality checks, commit, prepare PRs, merge, or enforce pre-merge workflow.
---
```

The body must absorb, in this order:

1. Role: canonical owner for Prisma delivery workflow from risk classification through integration.
2. Scope boundaries: owns risk/lane selection, lifecycle sequencing, validation command mapping, escalation triggers, Git/PR mechanics, and evidence reporting; delegates XCTest code structure to `../testing-xctest/SKILL.md` and review findings/semaforo severity to `../thermo-nuclear-code-quality-review/SKILL.md`.
3. Risk matrix copied from `task-lifecycle`.
4. Lifecycle copied from `task-lifecycle`, but replace "use QA/Git" with direct sections in this same skill.
5. Scoped validation intelligence and lane gates copied from `quality-assurance`, including `make scope-check`, `make build-test`, `make lint`, `make preview-check`, `make arch-check`, and `make guidance-check`.
6. Git mechanics copied from `git-workflow`, including preserving unrelated changes, Conventional Commits, `SKIP_DAILY_VERSION_BUMP=1`, `gh --body-file`, and non-destructive Git behavior.
7. Evidence to report: risk level/lane, reuse decision, commands/results, review outcome when relevant, escalation rationale, known baseline failures.
8. Related skills: `../testing-xctest/SKILL.md` and `../thermo-nuclear-code-quality-review/SKILL.md`.

Keep the new file concise. Do not paste the long progression-drill history from `quality-assurance`; summarize only durable rules that still change behavior.

**Verify**: `test -f .agents/skills/delivery-workflow/SKILL.md && rg -n "Risk Classification|Scoped Validation|Conventional Commits|gh --body-file" .agents/skills/delivery-workflow/SKILL.md` -> all four headings/phrases appear.

### Step 2: Remove the obsolete split skills

Delete:

- `.agents/skills/task-lifecycle/`
- `.agents/skills/quality-assurance/`
- `.agents/skills/git-workflow/`

**Verify**: `test ! -e .agents/skills/task-lifecycle && test ! -e .agents/skills/quality-assurance && test ! -e .agents/skills/git-workflow` -> exit 0.

### Step 3: Update routing and registry files

Update:

- `.agents/SKILLS_INDEX.md`: replace the three rows with one `delivery-workflow` row. Update quick references so workflow/risk/verification/Git all route to `delivery-workflow`. Keep `testing-xctest` as test-code structure.
- `.agents/skills/SKILLS_TAXONOMY.md`: replace the three rows with one `delivery-workflow` row. Remove the separate Git/Collaboration group if it becomes empty.
- `.agents/docs/skill-routing.md`: replace `task-lifecycle`, `quality-assurance`, and `git-workflow` routing with `delivery-workflow`. Keep testing implementation routed to `testing-xctest`.
- `AGENTS.md`: update the "Command surface authority" sentence so `delivery-workflow` maps lane policy to concrete commands.
- `plans/README.md`: mark this plan `DONE` when finished and update any forward-looking dependency note that tells future agents to use the removed skills.

**Verify**: `rg -n "task-lifecycle|quality-assurance|git-workflow" .agents AGENTS.md` -> no matches.

### Step 4: Update remaining skill references

Update any skill that currently points to the removed split skills:

- `.agents/skills/testing-xctest/SKILL.md`
- `.agents/skills/thermo-nuclear-code-quality-review/SKILL.md`
- `.agents/skills/macos-app-engineering/SKILL.md`
- `.agents/skills/intelligence-kernel/SKILL.md`
- `.agents/skills/code-quality/SKILL.md`
- `.agents/skills/project-standards/SKILL.md`

Use `../delivery-workflow/SKILL.md` as the replacement when the reference is about lane policy, validation commands, merge gates, Git mechanics, or evidence. Preserve specialist references that are not workflow-related.

**Verify**: `rg -n "delivery-workflow" .agents AGENTS.md | wc -l` -> nonzero, and `rg -n "task-lifecycle|quality-assurance|git-workflow" .agents AGENTS.md` -> no matches.

### Step 5: Validate guidance

Run:

```bash
make guidance-check
git diff --check
find .agents/skills -maxdepth 2 -name SKILL.md -print | sort | wc -l
```

Expected:

- `make guidance-check` exits 0.
- `git diff --check` exits 0.
- Skill count is `21` if plan 031 has not run; `20` if plan 031 already ran.

## Test plan

No Swift tests are required because this is documentation/guidance-only. The test surface is guidance validation:

- `make guidance-check`
- `git diff --check`
- reference cleanup using `rg`
- skill count using `find ... | wc -l`

## Done criteria

- [ ] `.agents/skills/delivery-workflow/SKILL.md` exists and contains risk, validation, Git, and evidence rules.
- [ ] `.agents/skills/task-lifecycle/`, `.agents/skills/quality-assurance/`, and `.agents/skills/git-workflow/` are removed.
- [ ] No active `.agents` or `AGENTS.md` reference points to the removed skill names.
- [ ] `testing-xctest` and `thermo-nuclear-code-quality-review` remain separate skills.
- [ ] `make guidance-check` exits 0.
- [ ] `git diff --check` exits 0.
- [ ] `plans/README.md` status row for plan 030 is updated.

## STOP conditions

Stop and report back if:

- The current files do not match the excerpts above after the drift check.
- `make guidance-check` reports broken links that require changing source code, Makefile targets, or scripts.
- The consolidation appears to require merging `testing-xctest` or `thermo-nuclear-code-quality-review`.
- You find another active agent or tool depends on the exact skill names `task-lifecycle`, `quality-assurance`, or `git-workflow` outside `.agents` and `AGENTS.md`.

## Maintenance notes

After this lands, new workflow policy should go into `delivery-workflow`, not scattered across specialist skills. Reviewers should check that the new skill is short enough to be read routinely and that it preserves the Full-lane gates from `AGENTS.md`: `make build-test` plus `make lint`.
