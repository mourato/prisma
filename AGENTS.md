# AGENTS.md - Meeting Assistant Development Guide

This file defines operational standards for AI agents and developers working in this repository.

## Project overview

Meeting Assistant is a macOS app focused on local-first meeting capture, transcription, and AI-powered post-processing. The project follows a modular Swift Package architecture and a CLI-first workflow for reproducible local and CI execution.

Core context:

- Platform: macOS 14+
- UI approach: SwiftUI-first with AppKit integrations where required (`NSStatusItem`, non-activating overlays)
- Architecture style: skill-based guidance + modular Clean Architecture boundaries
- Canonical agent directory: `.agents/` (`.agent` is a compatibility symlink)

## ✅ Standard Task SOP (Mandatory)

This is the **single, standardized** flow for every task in this repository:

1. **Create branch + worktree** (never work directly on `main`):
   - `git worktree add -b <branch-name> ../<folder-name> main`
   - `cd ../<folder-name>`
2. **Implement in small slices**.
3. **Verification gate (before ANY commit)**:
   - `make build`
   - `make test`
   - (recommended) `make lint`
   - If anything fails: stop and fix until green.
4. **Atomic commits (green state)**:
   - Split commits by intent (feature vs refactor vs tests vs cleanup).
   - Every commit must compile and test.
   - Use Conventional Commits (see `.agents/skills/git-workflow/SKILL.md`).
5. **Local code review ritual (before final push/merge)**:
   - Follow `.agents/skills/code-review/SKILL.md` and generate the 🔴/🟡/🟢 report.
   - Fix **🔴 Critical** and **🟡 Medium** findings (🟢 optional).
6. **Re-verify + atomic commits for review fixes**:
   - `make build && make test` (and `make lint` when applicable).
7. **Push / merge** the task branch into `main`.
8. **Cleanup**:
   - Remove worktree + prune.
   - Delete the branch locally and remotely (if pushed).

---

### Module split (B2 standard)

`MeetingAssistantCore` is an aggregation target over specialized modules:

- `MeetingAssistantCoreCommon` — shared models/utilities/resources (`String.localized`, logging, helpers)
- `MeetingAssistantCoreDomain` — entities, protocols, use cases
- `MeetingAssistantCoreInfrastructure` — adapters/integration services (Keychain, networking, providers)
- `MeetingAssistantCoreData` — persistence repositories and storage concerns
- `MeetingAssistantCoreAudio` — audio capture, buffering, worker pipeline
- `MeetingAssistantCoreAI` — transcription/post-processing/rendering services
- `MeetingAssistantCoreUI` — view models, coordinators, SwiftUI/AppKit presentation
- `MeetingAssistantCore` — compatibility export surface for app/test imports

## Build and test commands

Primary build/release commands:

```bash
make build
make run
make build-release
make dmg
```

Quick start:

```bash
make setup
make
```

Common workflows:

- Development: `make build && make run`
- Testing: `make test`
- Release: `make lint && make test && make build-release && make dmg`
- CI-style local check: `make ci-build` (includes `make arch-check`)

Lint and formatting:

```bash
./scripts/lint.sh
./scripts/lint-fix.sh
make arch-check
make preview-check
make format
```

Formatting is not implicit on every build; run `make format` (or `make lint-fix`) when needed.

## Code style guidelines

Language and localization policy:

- All documentation must be written in English.
- All code comments must be written in English.
- User-facing strings must be localized via `"key".localized` (never hardcode UI strings).

General style and architecture rules:

- Import only modules required by each file.
- Prefer dependency inversion through domain protocols over direct cross-module concrete dependencies.
- When moving types between modules, review access control deliberately (`public` only when required).
- Keep tests aligned with module ownership when internals are exercised.

UI design-system rules:

- Prefer semantic colors (`.primary`, `.secondary`, materials) and design-system tokens over hardcoded `Color(...)`.
- Prefer design-system spacing/radius tokens over magic numbers.
- Prefer design-system components over ad-hoc container styling.
- Use `MA*` components directly in Settings (`MACard`, `MAGroup`, `MAToggleRow`, `MACallout`, `MABadge`, `MAActionButton`, `MAThemePicker`).
- Every SwiftUI `struct ...: View` under `MeetingAssistantCoreUI` must include at least one `#Preview`.
- For stateful UI, prefer multiple previews covering key states (e.g., loading/success/error).
- For views with startup side effects, gate them in preview mode via `PreviewRuntime.isRunning`.

Design-system references:

- Tokens: `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/DesignSystem/MeetingAssistantDesignSystem.swift`
- Components: `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/DesignSystem/Components/`
- Preview guidelines: `docs/PREVIEW_GUIDELINES.md`
- Preview check script: `scripts/preview-check.sh`

## Testing instructions

Use CLI-driven tests for consistency with CI:

```bash
make test
make test-verbose
./scripts/run-tests.sh --file RecordingViewModelTests
./scripts/run-tests.sh --test testInitialState
./scripts/run-tests.sh --verbose
make ci-test
```

Minimum verification before merging:

- `make test`
- `make build`

To ensure workspace isolation and maintain a clean `main` branch, all file modifications MUST follow Worktree-first + green gates + atomic commits.

For the full standardized flow, follow the **Standard Task SOP** above and the skills:
- `.agents/skills/task-lifecycle/SKILL.md`
- `.agents/skills/git-workflow/SKILL.md`
- `.agents/skills/code-review/SKILL.md`
- `.agents/skills/git-worktree/SKILL.md`

## Security considerations

- Never hardcode secrets, API keys, or tokens in source code, test fixtures, scripts, or docs.
- Use Keychain-backed secret handling patterns and providers when credentials are required.
- Apply least-privilege thinking for entitlements, capabilities, and integrations.
- Validate and sanitize external input at module boundaries (network payloads, file content, provider responses).
- Avoid logging sensitive data (keys, tokens, full transcripts, personal identifiers).
- Follow `.agents/rules/security.md` and `.agents/skills/keychain-security/` for concrete implementation guidance.

## Task lifecycle (mandatory, worktree-first)

Every coding task must run in an isolated Git worktree.

Start from the `main/` worktree:

```bash
git worktree add -b <branch-name> ../<worktree-folder> main
cd ../<worktree-folder>
```

Workflow:

1. Create a branch from `main`.
2. Create and switch to a worktree for that branch.
3. Implement and verify changes inside the worktree.
4. Merge back to `main`.
5. Remove the temporary worktree and branch.
6. Run `git worktree prune`.

Detailed procedures:

- `.agents/skills/task-lifecycle/SKILL.md`
- `.agents/skills/git-workflow/SKILL.md`
- `.agents/skills/git-worktree/SKILL.md`

## Project structure

- `App/` — main app target (entry point, Info.plist, entitlements)
- `Packages/MeetingAssistantCore/` — Swift package root
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreCommon/` — shared utilities/resources
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreDomain/` — domain layer
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreInfrastructure/` — infrastructure layer
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreData/` — data layer
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreAudio/` — audio subsystem
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreAI/` — AI/transcription subsystem
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/` — UI/presentation layer
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/` — compatibility exports
- `docs/` — technical documentation
- `.agents/` — agent rules and skills (canonical)

## Extended references

Rules index:

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

Skills index (loaded conditionally):

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
| `.agents/skills/preview-coverage/` | SwiftUI preview requirements, preview state coverage |
| `.agents/skills/swift-package-manager/` | Package.swift, SPM dependencies |
| `.agents/skills/swiftui-patterns/` | SwiftUI views, @State, NavigationStack |
| `.agents/skills/testing-xctest/` | XCTest, @Test, mock, XCTAssert |
