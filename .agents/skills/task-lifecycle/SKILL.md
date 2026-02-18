---
name: task-lifecycle
description: This skill should be used when following the project's task lifecycle, from initialization and branching to implementation, verification, and cleanup.
---

# Universal Task Lifecycle

## Overview

This skill defines the **MANDATORY** operational standards for every coding task performed on this codebase.

The lifecycle is designed to guarantee:
- Risk-proportional quality gates
- Isolation via Worktrees when risk justifies it
- Reuse-first implementation decisions (`reuse -> extend -> create`) for logic and UI blocks
- Atomic commits (small, intention-revealing, buildable)
- A consistent local code review ritual before final push/merge
- Cleanup (worktree + branches, including remote when applicable)

Policy source:

- `AGENTS.md` is the source of truth.
- This skill operationalizes that policy and must stay aligned with it.

## Phase 0: Risk Classification (Required)

Classify the task before implementation:

- **Low risk**: docs/comments-only, localization/resource text updates, or constrained non-functional refactors in one module.
- **Medium risk**: feature/bugfix in one subsystem, public API changes, UI behavior/state changes.
- **High risk**: audio pipeline, concurrency/actor isolation, persistence, security/permissions, cross-module architectural changes, or large deltas.

If uncertain, classify as the higher risk.

Lane selection:

- **Fast lane** for Low risk.
- **Full lane** for Medium/High risk.

## Phase 1: Task Initialization

Worktree policy:

- **Full lane**: Worktree is mandatory. Never modify files in `main/`.
- **Fast lane**: Worktree is recommended. Direct branch work is acceptable for very small low-risk tasks.

1. **Context Identification**: Analyze the task and identify the target files.
2. **Reusable Block Scan (required)**:
   - Search for existing logic/UI blocks that can satisfy the change (services, use cases, helpers, design-system components).
   - Apply the decision order: **reuse -> extend -> create**.
   - Create a new block only when the pattern is new in the project or existing blocks cannot be safely extended.
3. **Clarification & Confirmation (when needed)**:
   - If requirements are ambiguous, incomplete, or have high-impact trade-offs, ask concise confirmation questions before implementation.
   - This step is optional when the request is already specific enough and low-risk.
   - Do not assume behavior, scope, acceptance criteria, or destructive intent when uncertainty remains.
4. **Branching**: Create a fresh branch from `main` (for Codex sessions prefer `codex/<task-name>`).
5. **Setup Worktree (Full lane or optional Fast lane)**: Create and enter a new Git Worktree.
   ```bash
   git worktree add -b <branch-name> ../<folder-name> main
   cd ../<folder-name>
   ```

## Phase 2: Implementation Loop (Green + Atomic)

Language policy:

- Documentation must be written in **English**.
- Code comments must be written in **English**.


Work inside the selected lane context (worktree for Full lane; branch or worktree for Fast lane).

Repeat the following loop until the task is complete:

1. **Implement a small, coherent slice**: Prefer incremental changes that follow the selected reusable-block strategy (`reuse`, `extend`, or `create`).
2. **Run proportional checks during development**:
   - Fast lane: staged lint/format and targeted tests when relevant.
   - Full lane: run targeted tests and/or `make build` as needed while iterating.
   - Prefer `make preflight` before final push/merge to run the canonical scripted gates (`build + test + lint`).
   - For AI-driven runs where token budget matters, use compact targets (`make preflight-agent`, `make build-agent`, `make test-agent`, `make lint-agent`) and inspect logs under `${MA_AGENT_LOG_DIR:-/tmp/ma-agent}`.
   - Run `make arch-check` when changing architecture boundaries/access control/import rules.
   - Run `make preview-check` when adding/changing SwiftUI views.
   - If tests touch module internals, ensure the test target depends on that module explicitly in `Package.swift`.
3. **If verification fails**: Stop and fix before progressing.
4. **Atomic commit (green state)**:
   - Group changes by intent.
   - Use Conventional Commits.
   - Do not commit knowingly broken code.
5. **Documentation + limitation tracking**:
   - Update DocC when the change introduces new constraints or APIs.
   - If the change introduces a known limitation or intentional trade-off, create or update a GitHub issue via `gh` and use the `known-limitation` label.
   - Do not track limitations in a standalone markdown backlog file.

> Verify continuously, but keep hard gates at push/merge time to optimize cycle time.

## Phase 3: Local Code Review Ritual (Risk-based)

Before the final push/merge, perform a local review using **[code-review](../code-review/SKILL.md)**.

1. **Define the scope**: Review the commit list and files touched.
2. **Review depth by lane**:
   - Fast lane: lightweight checklist review is acceptable.
   - Full lane: semáforo table (🔴/🟡/🟢) is mandatory.
3. **Fix findings**:
   - Must fix **🔴 Critical** and **🟡 Medium**.
   - Fix **🟢 Low** when it clearly improves clarity/safety with low risk.
4. **Hard gate before push/merge**:
   - Fast lane minimum: `make test`
   - Full lane minimum: `make build` + `make test`
   - `make lint` is recommended (mandatory for broad refactors)
   - Preferred single command: `make preflight`
   - Agent compact commands are for low-noise diagnostics and do not replace required merge gates.
5. **Atomic commits for review fixes**: Commit review-driven changes separately from feature work.

## Phase 4: Integration (Push / Merge)

1. **Push the branch** (for PR or collaboration):
   ```bash
   git push -u origin <branch-name>
   ```
2. **Merge into `main`** using the team’s preferred approach (PR or local merge).
   - If merging locally, return to the `main` worktree and merge:
     ```bash
     cd ../main
     git merge <branch-name>
     ```

## Phase 5: Cleanup (Mandatory)

Once the task is complete and verified:

1. **Cleanup Directory**: Remove the worktree via Git.
   ```bash
   git worktree remove ../<folder-name>
   git worktree prune
   ```
2. **Delete local branch** (never delete `main`):
   ```bash
   git branch -D <branch-name>
   ```
3. **Delete remote branch (if it was pushed)**:
   ```bash
   git push origin --delete <branch-name>
   ```

## References

- **[git-workflow](../git-workflow/SKILL.md)**: Detailed commit and branching guidelines.
- **[quality-assurance](../quality-assurance/SKILL.md)**: Standards for testing and build verification.
- **[code-review](../code-review/SKILL.md)**: Mandatory pre-push review ritual and reporting format.
- **[git-worktree](../git-worktree/SKILL.md)**: Worktree operations, pitfalls, and cleanup.
