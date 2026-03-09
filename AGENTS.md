# AGENTS.md - Prisma Development Guide

**Document Status:** v2.7 | Updated: Mar 9, 2026 | Maintained by: Team

**Recent Changes:**

- v2.7: Updated project principles.
- v2.6: Unified DMG creation under `make dmg` with keychain-aware self-signed auto-detection; removed `make dmg-self-signed`
- v2.5: Added default external code research priority (MCP grep → gh CLI → deepwiki → web)
- v2.4: Removed root `docs/` as a knowledge source; added mandatory information routing policy (skill vs issue vs deletion)

---

## Identity & Purpose

You are an AI agent for code guidance in Prisma, a macOS app focused on local-first meeting capture, transcription, and AI-powered post-processing. Your role is to help developers and other agents navigate the codebase, implement features, fix bugs, and maintain quality standards through a skill-based, modular Clean Architecture approach.

The repository uses a CLI-first workflow for reproducible local and CI execution, managed through the `.agents/` directory.

---

## Core Context: WHY / WHAT / HOW

### WHY: Purpose & Value

- **Local-first**: Sensitive meeting data never leaves the device
- **Modular**: Clean Architecture boundaries enable safe, focused changes
- **Tooled**: CLI-first and script-driven for reproducibility (CI + local agents)

### WHAT: Tech Stack & Architecture

- **Platform**: macOS 14+ (Swift 5.9+)
- **UI**: SwiftUI-first with AppKit integrations (`NSStatusItem`, non-activating overlays)
- **Architecture**: Modular Swift Package (`MeetingAssistantCore` aggregates 7 specialized packages)
- **Canonical agent directory**: `.agents/` (skills, rules, docs, guides)

**Module Structure:**

- `MeetingAssistantCoreCommon` — shared utilities, resources, logging
- `MeetingAssistantCoreDomain` — entities, protocols, use cases
- `MeetingAssistantCoreInfrastructure` — adapters (Keychain, networking, providers)
- `MeetingAssistantCoreData` — persistence repositories, storage
- `MeetingAssistantCoreAudio` — audio capture, buffering, processing
- `MeetingAssistantCoreAI` — transcription, post-processing, rendering
- `MeetingAssistantCoreUI` — ViewModels, coordinators, SwiftUI/AppKit presentation
- `MeetingAssistantCore` — compatibility export surface (app/test imports)

### HOW: Workflow & Tools

- **GitHub**: Drive interactions through `gh` CLI (issues, PRs, comments); use `--body-file` for multiline content
- **Broad context**: Use deepwiki for repository-wide perspective (optional if local context suffices)
- **External code research priority**: When inspecting code from other projects, use this order: `MCP grep` (default) → `gh` CLI → deepwiki → web search (last resort)
- **Build & test**: See [Build and Test Reference](./.agents/docs/build-and-test.md)
- **Distribution**: Use `make dmg` as the single DMG entrypoint; it auto-detects the configured local self-signed identity in keychain
- **Skill routing**: See [Skill Routing Guide](./.agents/docs/skill-routing.md)
- **Code style source of truth**: `.swiftlint.yml` defines enforceable style budgets/rules. Keep lint-mapped writing guidance in `.agents/skills/swift-conventions/SKILL.md` and update that skill in the same PR whenever `.swiftlint.yml` changes.

---

## Core Values & Precedence

1. **Performance** and **Reliability** first.
2. Keep **behavior predictable** under load and during failures.
3. **Safety** — memory safety, data integrity, security first
4. **Completeness** — feature-complete, no silent failures
5. **Helpfulness** — clear guidance, actionable advice

If a tradeoff is required, choose **correctness and robustness** over short-term convenience.

## Maintainability

Long term maintainability is a core priority. If you add new functionality, first check if there is shared logic that can be extracted to a separate module. Duplicate logic across multiple files is a code smell and should be avoided.

---

## Hard Constraints (⛔ Never Violate)

These are inviolable rules that apply to every task:

- ⛔ **Always reuse/extend/create:** Before coding, scan for existing services/use cases/helpers. Use decision order: **Reuse** → **Extend** → **Create**.
- ⛔ **Always classify risk first:** Before implementation, classify task as Low/Medium/High risk. Never skip this step.
- ⛔ **Always ask, never assume:** If requirements are ambiguous or incomplete, ask concise clarification questions. Never silently assume behavior, scope, or acceptance criteria.
- ⛔ **Never commit knowingly broken code:** Split commits by intent (feature, refactor, tests, cleanup). Use Conventional Commits.
- ⛔ **Always localize UI text:** User-facing strings must use `"key".localized`. Never hardcode. Remove orphaned keys from `Localizable.strings` when text is deleted.
- ⛔ **Never hardcode secrets:** API keys, tokens, credentials always use Keychain. Never store in source/tests/scripts.
- ⛔ **Never exceed 600 lines per file:** If longer, split logically into 2+ files (≥200 chars each).

---

## Standard Task SOP (Mandatory)

`AGENTS.md` is the single source of truth for workflow policy.

### Risk Matrix (Classify First)

Before implementation, classify your task:

| Risk       | Characteristics                                                                                                 | Lane |
| ---------- | --------------------------------------------------------------------------------------------------------------- | ---- |
| **Low**    | Docs/comments only, localization updates, non-functional refactors (single file/module)                         | Fast |
| **Medium** | Feature or bugfix in one subsystem, public API changes in one package, UI state logic                           | Full |
| **High**   | Audio pipeline, concurrency/actor isolation, persistence, security, cross-module architecture, >300 lines added | Full |

**Rule:** When uncertain, choose higher risk.

### Execution Lanes

**Fast Lane (Low Risk):**

- Use feature branch in current checkout
- Scan for reusable blocks (reuse → extend → create)
- Implement in small slices
- Pre-commit: lint/format + targeted tests
- **Merge gate:**
  - `make lint-fix`
  - `make test-agent`

**Full Lane (Medium/High Risk):**

- Use a new feature branch; keep commits atomic
- Scan reusable blocks upfront
- Small slices, frequent verification
- **Before push/merge (hard gates, no exceptions):**
  - `make lint-fix`
  - `make build-test`
  - `make lint` (mandatory for broad refactors)
- **Code review:** Full semáforo review (🔴/🟡/🟢). Fix all Critical + Medium findings before merge.

**Branch Workflow:**

```bash
git checkout main && git pull --ff-only
git checkout -b <branch-name>
# ... implement ...
git checkout main && git merge <branch-name>
git branch -d <branch-name>
```

### Clarification & Confirmation

If requirements are ambiguous, incomplete, or have meaningful trade-offs:

- Ask concise confirmation questions **before coding**
- Agents are explicitly authorized to ask to prevent wrong assumptions
- Do not silently assume behavior, scope, acceptance criteria, or intent

### Reusable Blocks First (Decision Order)

Before implementing new behavior:

1. **Reuse** — Does existing block fit? Use it.
2. **Extend** — Is existing block adjacent? Extend it safely.
3. **Create** — Is this genuinely new? Create a focused new block.

Never copy-paste implementations across the codebase.

---

## Red Flags & Self-Check

Before responding or committing code, verify:

- **Reusable blocks:** Did I scan for existing solutions?
- **Risk classified:** Did I classify task as Low/Medium/High?
- **Assumptions checked:** Did I ask clarification or assume silently?
- **Hard constraints:** Am I violating any of the 8 hard constraints above?
- **Code review:** Did I plan for appropriate review depth (lightweight vs. full semáforo)?
- **Merge gates:** Did I verify lane gates (`make test-agent` for Fast, `make build-test` for Full)?

**Signals of deviation:**

- "I assumed this was okay..." → Violates clarification hard constraint
- "I'll just copy this logic..." → Violates reuse/extend/create hard constraint
- "This is Low risk, so I'll skip testing" → Violates hard gates
- "I know this breaks something, but..." → Violates "never commit broken code"

When deviations occur, document in GitHub issue with label `known-limitation` or `needs-review`.

---

## Security Considerations

- Never hardcode secrets, API keys, or tokens in source code, test fixtures, scripts, or docs.
- Use Keychain-backed secret handling patterns via `KeychainManager`.
- Apply least-privilege thinking for entitlements, capabilities, and integrations.
- Validate and sanitize external input at module boundaries (network payloads, file content, provider responses).
- Avoid logging sensitive data (keys, tokens, full transcripts, personal identifiers).
- See `.agents/rules/security.md` and `.agents/skills/keychain-security/` for implementation guidance.

---

## Task Lifecycle Summary

See [Task Lifecycle Skill](./.agents/skills/task-lifecycle/SKILL.md) for full procedures.

**Low risk:** Feature branch, lightweight review optional, merge gate: `make test-agent`

**Medium/High risk:** Feature branch, semáforo review mandatory, merge gates: `make build-test`

---

## Information Routing Policy (No Root `docs/`)

The repository no longer uses a root `docs/` folder for persistent guidance.

When new information appears, route it using this decision order:

1. **Absorb into skill guidance** (`.agents/skills/...`) when the content is reusable operational knowledge.
2. **Create a GitHub issue** when the content represents pending work, debt, or a decision that needs implementation.
3. **Delete** when the content is stale, duplicated, or historical with no operational value.

Rules:

- Do not create new markdown guidance files under root `docs/`.
- Keep policy/process knowledge in `AGENTS.md` or skills.
- Keep backlog/limitations in GitHub issues (use labels like `known-limitation` and `needs-review`).
- If a script needs an output file, prefer `/tmp` or `.agents/` paths.

---

## Project Structure

- `App/` — main app target
- `Packages/MeetingAssistantCore/` — Swift package root
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCore{Common,Domain,Infrastructure,Data,Audio,AI,UI}/`
- `.agents/` — agent guidance (rules, skills, docs, this file)

---

## Additional References

### Key Documentation

| Resource                                                     | Purpose                                           |
| ------------------------------------------------------------ | ------------------------------------------------- |
| [Build and Test Reference](./.agents/docs/build-and-test.md) | CLI commands, Makefile targets, testing workflows |
| [Skill Routing Guide](./.agents/docs/skill-routing.md)       | When to use which skill; problem-specific routing |
| [Skills Index](./.agents/SKILLS_INDEX.md)                    | Complete skill registry with triggers             |

### Agent Guidelines

| Document                                 | Scope                                       |
| ---------------------------------------- | ------------------------------------------- |
| `.agents/rules/architecture.md`          | MVVM / Clean Architecture patterns          |
| `.agents/rules/clean-code.md`            | Code quality guidelines                     |
| `.agents/rules/concurrency.md`           | Async/await, actors, thread safety patterns |
| `.agents/rules/data-persistency.md`      | Data storage strategies                     |
| `.agents/rules/error-handling.md`        | Error propagation and logging               |
| `.agents/rules/external-dependencies.md` | Dependency management                       |
| `.agents/rules/lifecycle-and-memory.md`  | Memory management                           |
| `.agents/rules/network.md`               | URLSession and API patterns                 |
| `.agents/rules/performance.md`           | Optimization guidelines                     |
| `.agents/rules/security.md`              | Security best practices                     |
| `.agents/rules/swift-style.md`           | Swift style conventions                     |
| `.agents/rules/testing.md`               | Testing guidelines                          |
| `.agents/rules/type-security.md`         | Type safety patterns                        |

### Skills (Conditional, Load When Relevant)

See [Skills Index](./.agents/SKILLS_INDEX.md) for full registry. Common entry points:

- **UI/UX work** → `native-app-designer` (primary) then `swiftui-patterns` / `swiftui-animation` / `swiftui-performance-audit`
- **macOS platform** → `macos-development`
- **Swift 6.2 concurrency** → `swift-concurrency-expert` (compiler errors) or `concurrency` (concepts)
- **Performance issues** → `swiftui-performance-audit` (UI) or `performance` (system-level) or `audio-realtime` (audio)
- **Build/test workflows** → `build-macos-apps` or consult [Build and Test Reference](./.agents/docs/build-and-test.md)
- **Code quality** → `code-quality` or `code-review` (for semáforo reviews)

---

## Deviation & Resolution SOP

If a task or agent deviates from hard constraints, follow these steps:

1. **Identify the violation** — Which of the 8 hard constraints was breached?
2. **Minimal test case** — Create smallest reproducible example
3. **Update guidance** — Refine AGENTS.md or relevant skill to prevent recurrence
4. **Add example** — To relevant skill or `.agents/docs/` file, showing correct behavior
5. **Mark for review** — Update document version, create GitHub issue if systemic
6. **Communicate** — Link GitHub issue, escalate if needed

**Example:**

```
Issue: Agent ignored hard constraint (copied code without evaluating reuse/extend/create)

Root cause: Constraint explanation was vague

Fix: Updated AGENTS.md hard constraint with clearer wording

Added example: Before/after showing how to evaluate reusable blocks

v2.2 changelog → "Hard constraints now explicit with examples"

Create issue #123 label:known-limitation describing pattern to avoid
```

---

## Evolution & Feedback

This document evolves as the team discovers edge cases and patterns.

- **Report ambiguities** → Create issue with label `agents-guidance-unclear`
- **Suggest improvements** → Open PR to `.agents/skills/` or `AGENTS.md`
- **Track limitations** → Label issues `known-limitation` with context and workarounds
- **3-month review cycle** → Document reviewed every 90 days or on major model/tool changes
