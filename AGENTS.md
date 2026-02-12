# AGENTS.md - Meeting Assistant Development Guide

This file defines operational standards for AI agents and developers working in this repository.

## Project overview

Meeting Assistant is a macOS app focused on local-first meeting capture, transcription, and AI-powered post-processing. The project follows a modular Swift Package architecture and a CLI-first workflow for reproducible local and CI execution.

Core context:

- Platform: macOS 14+
- UI approach: SwiftUI-first with AppKit integrations where required (`NSStatusItem`, non-activating overlays)
- Architecture style: skill-based guidance + modular Clean Architecture boundaries
- Canonical agent directory: `.agents/` (`.agent` is a compatibility symlink)

## Tool usage policy

- For every reasoning or planning task, use the Sequential Thinking tool to capture each step of the thought process before acting.
- Whenever you need to read from, write to, or otherwise interact with GitHub (issues, PRs, repos), drive those interactions through the GitHub CLI (`gh`).
- For holistic or repository-wide analysis, feel free to leverage deepwiki to collect broader context, but keep it optional when the information is already contained locally.

## ✅ Standard Task SOP (Mandatory)

`AGENTS.md` is the single source of truth for workflow policy. Skills must extend this SOP, not redefine it.

### Risk matrix (required before implementation)

Classify each task before coding:

- **Low risk**:
  - Docs-only / comments-only changes
  - Localization/resource text updates without behavior changes
  - Non-functional refactors confined to one file/module
- **Medium risk**:
  - Feature or bugfix in one subsystem
  - Public API changes inside one package
  - UI behavior/state logic changes
- **High risk**:
  - Audio pipeline, concurrency/actor isolation, persistence, security/permissions
  - Cross-module architecture changes
  - Large deltas (roughly >300 added lines or broad refactors)

If uncertain, choose the higher risk level.

### Execution lanes

1. **Fast lane (Low risk)**:
   - Worktree is recommended; direct branch work is acceptable for small low-risk changes.
   - Implement in small slices.
   - Pre-commit checks: staged lint/format + targeted tests when relevant.
   - Before push/merge: run `make test`.
2. **Full lane (Medium/High risk)**:
   - Worktree is mandatory (never implement in `main/`).
   - Implement in small slices.
   - During development run relevant checks (targeted tests and/or `make build` as needed).
   - Before push/merge (hard gate):
     - `make build`
     - `make test`
     - `make lint` (recommended; mandatory for broad refactors)
3. **Code review ritual (risk-based)**:
   - Full semáforo review (🔴/🟡/🟢) is mandatory for Medium/High.
   - Lightweight checklist review is acceptable for Low.
   - Always fix **🔴 Critical** and **🟡 Medium** findings before merge.
4. **Atomic commits**:
   - Split commits by intent (feature vs refactor vs tests vs cleanup).
   - Use Conventional Commits (see `.agents/skills/git-workflow/SKILL.md`).
   - Do not commit knowingly broken code.
5. **Integration + cleanup**:
   - Push / merge into `main`.
   - Prefer `git worktree remove <path>` then `git worktree prune`.
   - Delete local/remote branch when applicable.

## Optimized workflow checklist

- [ ] Open the Sequential Thinking tool before planning a task so each reasoning step is recorded.
- [ ] Use `gh` for every GitHub interaction (issues, PRs, repos) rather than manual HTTP/UI visits.
- [ ] Consider deepwiki only when local context is insufficient for a holistic, repository-wide perspective.
- [ ] Classify risk (Low/Medium/High) before coding and pick Fast or Full lane accordingly.
- [ ] Use Fast lane for low-risk tasks and Full lane for medium/high-risk tasks.
- [ ] Keep hard gates at push/merge stage (`make test`, plus `make build` for Full lane).
- [ ] Prefer `make preflight` (scripted build + test + lint) before push/merge.
- [ ] Run `make arch-check` only for architecture boundary/access-control changes.
- [ ] Run `make preview-check` when SwiftUI views are added or modified.
- [ ] Use `git worktree remove` + `git worktree prune` for cleanup.
- [ ] Localize user-facing text and respect module/skill responsibilities as outlined in the main SOP and skills index.
- [ ] When UI text is removed, sanitize localization resources by removing now-unused keys from supported locales.

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
make preflight
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
- Pre-merge validation: `make preflight`
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
- Removing UI text requires localization sanitization: delete orphaned keys from `Localizable.strings` files and confirm no source references remain.

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

To keep quality high and cycle time low, use risk-based verification gates and lane selection from the Standard Task SOP above.

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

## Task lifecycle (risk-based)

Use the Standard Task SOP (risk matrix + Fast/Full lanes) as policy.

- **Low risk**: worktree recommended, Full review optional, minimum merge gate is `make test`.
- **Medium/High risk**: worktree mandatory, semáforo review mandatory, merge gate includes `make build` + `make test`.
- Always avoid direct implementation in `main/` for Medium/High tasks.

Preferred worktree workflow:

```bash
git worktree add -b <branch-name> ../<worktree-folder> main
cd ../<worktree-folder>
# ... implement ...
cd ../main
git merge <branch-name>
git worktree remove ../<worktree-folder>
git worktree prune
```

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
