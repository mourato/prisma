# AGENTS.md - Meeting Assistant Development Guide

This file provides the primary operational standards for all AI agents and developers.

## Mandatory: Task lifecycle (worktree-first)

Every coding task MUST follow the **Worktree-First** workflow to ensure environment isolation and repository integrity. This is the first step of any interaction involving code changes.

1. Create a new branch based on `main`.
2. Create a Git worktree for the task.
3. Implement and verify changes inside the worktree.
4. Merge back to `main` and clean up the worktree.

For detailed steps and commands, see `.agents/skills/task-lifecycle/SKILL.md`.

## Language policy (project-wide)

- All documentation must be written in **English**.
- All code comments must be written in **English**.
- User-facing UI strings must be localized via `"key".localized` (do not hardcode strings).

Rationale: English-only docs/comments reduce duplication and make the project accessible to external contributors.

---

## Project architecture

The project uses a **Skill-Based Architecture**. All logic and patterns are documented in tool-agnostic skills.

> Agent content lives under `.agents/` (canonical). A compatibility symlink `.agent -> .agents` exists for tools that still expect `.agent/`.

### B2 module split (current standard)

`MeetingAssistantCore` is now an aggregation target over specialized modules:

- `MeetingAssistantCoreCommon` — shared models/utilities/resources (`String.localized`, logging, helpers)
- `MeetingAssistantCoreDomain` — entities, protocols, use cases
- `MeetingAssistantCoreInfrastructure` — adapters/integration services (Keychain, networking, providers)
- `MeetingAssistantCoreData` — persistence repositories and storage concerns
- `MeetingAssistantCoreAudio` — audio capture, buffering, worker pipeline
- `MeetingAssistantCoreAI` — transcription/post-processing/rendering services
- `MeetingAssistantCoreUI` — view models, coordinators, SwiftUI/AppKit presentation
- `MeetingAssistantCore` — compatibility export surface for app/test imports

Rules:

- Add imports only for modules actually required by the file.
- Prefer dependency inversion through domain protocols over direct cross-module concrete types.
- When moving types between modules, update access control deliberately (`public` only when required).
- Keep test targets aligned with module ownership when internals are exercised.

## Platform target

- Minimum supported version: macOS 14
- UI approach: SwiftUI-first, with AppKit where needed (menu bar `NSStatusItem`, non-activating overlays, etc.)

## Design system (UI)

We use a lightweight, SwiftUI-first design system to keep UI consistent and DRY:

- Tokens: `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/DesignSystem/MeetingAssistantDesignSystem.swift`
- Components: `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/DesignSystem/Components/`

Rules of thumb:

- Prefer semantic colors (`.primary`, `.secondary`, materials) and DS tokens over hardcoded `Color(...)`.
- Prefer DS spacing/radius constants over magic numbers.
- Prefer DS components (cards, groups, callouts) over ad-hoc styling.
- UI strings must be localized via `"key".localized` (never hardcode user-facing strings).

Public components (v1):

- `MACard`, `MAGroup`, `MAToggleRow`, `MACallout`, `MABadge`, `MAActionButton`, `MAThemePicker`
- Use `MA*` components directly in Settings (legacy `Settings*` aliases were removed)

## Build commands

```bash
make build
make run
make build-release
make dmg
```

### CLI-first workflow

All builds/tests/releases run via CLI for consistency with CI.

Quick start:

```bash
make setup
make
```

Common workflows:

- Development: `make build && make run`
- Testing: `make test`
- Release: `make lint && make test && make build-release && make dmg`
- CI: `make ci-build`

## Lint & format

```bash
./scripts/lint.sh
./scripts/lint-fix.sh
make format
```

Note: formatting is not run implicitly on every build. Run `make format` (or `make lint-fix`) when you want to auto-format.

## Testing

```bash
make test
make test-verbose
./scripts/run-tests.sh --file RecordingViewModelTests
./scripts/run-tests.sh --test testInitialState
./scripts/run-tests.sh --verbose
make ci-test
```

## Worktree-first development (mandatory)

From the `main/` worktree, start every task like this:

```bash
git worktree add -b <branch-name> ../<worktree-folder> main
cd ../<worktree-folder>
```

Verify inside the worktree:

- `make test`
- `make build`

Finalize:

- Merge to `main`
- Remove the worktree folder
- `git worktree prune`
- Delete the temporary branch

For detailed instructions, see `.agents/skills/git-workflow/SKILL.md` and `.agents/skills/git-worktree/SKILL.md`.

## Rules index

| Document | What it covers |
|----------|----------------|
| `.agents/rules/architecture.md` | MVVM / Clean Architecture patterns |
| `.agents/rules/clean-code.md` | Code quality guidelines |
| `.agents/rules/concurrency.md` | Async/await, actors, thread safety |
| `.agents/rules/data-persistency.md` | Data storage strategies |
| `.agents/rules/error-handling.md` | Error propagation and logging |
| `.agents/rules/external-dependencies.md` | Dependency management |
| `.agents/rules/known-limitations.md` | Documentation requirements |
| `.agents/rules/lifecycle-and-memory.md` | Memory management |
| `.agents/rules/network.md` | URLSession and API patterns |
| `.agents/rules/performance.md` | Optimization guidelines |
| `.agents/rules/security.md` | Security best practices |
| `.agents/rules/swift-style.md` | Swift style conventions |
| `.agents/rules/testing.md` | Testing guidelines |
| `.agents/rules/type-security.md` | Type safety patterns |

## Skills index (conditional)

Skills are loaded when specific contexts are detected. See `.agents/skills/` for full guides.

| Skill | Trigger |
|-------|---------|
| `.agents/skills/audio-realtime/` | AVAudioSourceNode, AudioRecorder, ProcessTap |
| `.agents/skills/debugging-strategies/` | bugs, crash, performance issue |
| `.agents/skills/documentation/` | DocC comments, API documentation |
| `.agents/skills/git-advanced-workflows/` | rebase, bisect, cherry-pick |
| `.agents/skills/git-workflow/` | git commit, branches, PRs |
| `.agents/skills/keychain-security/` | KeychainManager, KeychainProvider, storeSecret |
| `.agents/skills/localization/` | Bundle.safeModule, String.localized, accessibility |
| `.agents/skills/menubar/` | NSStatusItem, NSMenu, NSPopover |
| `.agents/skills/skill-development/` | create skill, develop plugin |
| `.agents/skills/skills-discovery/` | search skills, registry |
| `.agents/skills/swift-package-manager/` | Package.swift, SPM dependencies |
| `.agents/skills/swiftui-patterns/` | SwiftUI views, @State, NavigationStack |
| `.agents/skills/testing-xctest/` | XCTest, @Test, mock, XCTAssert |

## Project structure

- `App/` — Main app target (entry point, Info.plist, entitlements)
- `Packages/MeetingAssistantCore/` — Swift package root
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreCommon/` — shared utilities/resources
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreDomain/` — domain layer
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreInfrastructure/` — infrastructure layer
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreData/` — data layer
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreAudio/` — audio subsystem
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreAI/` — AI/transcription subsystem
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/` — UI/presentation layer
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/` — compatibility exports
- `docs/` — Technical documentation
- `.agents/` — Agent rules and skills (canonical)
