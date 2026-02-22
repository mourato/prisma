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
- When submitting multiline content through `gh` (issue bodies, comments, PR descriptions), prefer `--body-file` with a literal heredoc (`<<'EOF'`) to avoid shell interpolation issues (for example with backticks).
- For holistic or repository-wide analysis, feel free to leverage deepwiki to collect broader context, but keep it optional when the information is already contained locally.

## ✅ Standard Task SOP (Mandatory)

`AGENTS.md` is the single source of truth for workflow policy. Skills must extend this SOP, not redefine it.

### Reusable Blocks First (required before implementation)

Treat the project as a set of reusable building blocks (logic and UI), not one-off solutions.

- Run a quick reusable-block scan before coding:
  - Search for existing services/use cases/helpers/components that already solve the problem.
  - Evaluate repeated or emerging patterns in the requested change.
- Use this decision order:
  - **Reuse** an existing block when it already fits.
  - **Extend** an existing block when the need is adjacent and can remain coherent.
  - **Create** a new block when the pattern is new to the project or existing blocks cannot be safely extended.
- Avoid copy-paste implementations of behavior or UI composition when a reusable block is viable.

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

### Clarification and confirmation (default behavior)

Before implementation, run a quick clarification pass when needed:

- If requirements are ambiguous, incomplete, or have meaningful trade-offs, ask concise confirmation questions before coding.
- Agents are explicitly authorized by default to ask those questions whenever they prevent wrong assumptions or rework.
- This planning/clarification step is optional when the request is already specific enough and low-risk.
- Do not silently assume behavior, scope, acceptance criteria, or destructive intent when uncertainty remains.

### Execution lanes

1. **Fast lane (Low risk)**:
  - Use a feature branch in the current checkout (no separate worktree required).
   - Start with a reusable-block scan (`reuse -> extend -> create`) for both logic and UI.
   - Implement in small slices.
   - Pre-commit checks: staged lint/format + targeted tests when relevant.
   - Before push/merge: run `make test`.
2. **Full lane (Medium/High risk)**:
  - Use an isolated feature branch in the current checkout and keep commits atomic.
   - Start with a reusable-block scan (`reuse -> extend -> create`) for both logic and UI.
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
  - Delete local/remote feature branch when applicable.

## Optimized workflow checklist

- [ ] Open the Sequential Thinking tool before planning a task so each reasoning step is recorded.
- [ ] Before coding, scan for reusable blocks and repeated/new patterns; apply `reuse -> extend -> create`.
- [ ] Use `gh` for every GitHub interaction (issues, PRs, repos) rather than manual HTTP/UI visits.
- [ ] For multiline GitHub content, use `gh ... --body-file <file>` (or heredoc-backed file) instead of inline `--body`.
- [ ] Consider deepwiki only when local context is insufficient for a holistic, repository-wide perspective.
- [ ] Classify risk (Low/Medium/High) before coding and pick Fast or Full lane accordingly.
- [ ] Run a clarification pass when needed; ask concise confirmation questions instead of assuming missing requirements.
- [ ] Use Fast lane for low-risk tasks and Full lane for medium/high-risk tasks.
- [ ] Keep hard gates at push/merge stage (`make test`, plus `make build` for Full lane).
- [ ] Prefer `make preflight` (scripted build + test + lint) before push/merge.
- [ ] For AI-agent runs, ALWAYS use compact targets (`make preflight-agent`, `make build-agent`, `make test-agent`, `make lint-agent`) to reduce context tokens while preserving diagnostics.
- [ ] Run `make arch-check` only for architecture boundary/access-control changes.
- [ ] Run `make preview-check` when SwiftUI views are added or modified.
- [ ] Delete merged local/remote feature branches during cleanup.
- [ ] When a new limitation/trade-off is discovered, create or update a GitHub issue via `gh` with label `known-limitation`.
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

Compact commands for AI agents (machine-readable output + log artifacts):

```bash
make build-agent
make test-agent
make lint-agent
make preflight-agent
```

Canonical direct `xcodebuild` usage (when Make targets are not suitable):

```bash
./scripts/xcodebuild-safe.sh
# equivalent explicit form:
# xcodebuild -project MeetingAssistant.xcodeproj -scheme MeetingAssistant -configuration Debug -destination 'platform=macOS' build
```

Avoid bare `xcodebuild build` in this repository; it can trigger unstable SwiftPM transitive-module resolution.

Agent artifacts and summaries:

- Log directory defaults to `/tmp/ma-agent` (override with `MA_AGENT_LOG_DIR`).
- Scripts emit deterministic summary lines (`AGENT_STEP`, `AGENT_STATUS`, `AGENT_DURATION_SEC`, `AGENT_LOG`, `AGENT_ERROR_COUNT`, `AGENT_SUMMARY`, `AGENT_RESULT_JSON`).
- On failures, scripts print compact excerpts and tail logs while keeping full logs on disk.

Quick start:

```bash
make setup
make
```

Common workflows:

- Development: `make build && make run`
- Pre-merge validation: `make preflight`
- Agent-focused pre-merge validation: `make preflight-agent`
- Testing: `make test`
- Agent-focused testing: `make test-agent`
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
- Prefer reusable logic blocks (services/use cases/helpers) over duplicating behavior across features.
- When implementing a new behavior, first evaluate reuse/expansion of existing blocks before creating new ones.
- When moving types between modules, review access control deliberately (`public` only when required).
- Keep tests aligned with module ownership when internals are exercised.

UI design-system rules:

- Prefer semantic colors (`.primary`, `.secondary`, materials) and design-system tokens over hardcoded `Color(...)`.
- Prefer design-system spacing/radius tokens over magic numbers.
- Prefer design-system components over ad-hoc container styling.
- Use `Stepper` only for small bounded option sets (around 6 steps/items or fewer).
- For bounded sets larger than ~6 options, prefer a `Picker` (usually `.menu` in Settings).
- When values are not a small finite set (or can vary freely), prefer `TextField` input with appropriate validation (for numeric values, numeric-only validation).
- Use `MA*` components directly in Settings (`MACard`, `MAGroup`, `MAToggleRow`, `MACallout`, `MABadge`, `MAActionButton`, `MAThemePicker`).
- Reuse or extend existing `MA*` components before creating new custom containers or repeated style wrappers.
- Destructive actions (`remove`, `delete`, `clear` when irreversible) must use red styling (`.destructive` role and/or `MeetingAssistantDesignSystem.Colors.error` in custom button styles).
- Non-destructive reset controls (for example, clearing a shortcut input) must remain neutral.
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
make test-agent
make test-verbose
./scripts/run-tests.sh --file RecordingViewModelTests
./scripts/run-tests.sh --test testInitialState
./scripts/run-tests.sh --verbose
./scripts/run-tests.sh --agent
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

## Security considerations

- Never hardcode secrets, API keys, or tokens in source code, test fixtures, scripts, or docs.
- Use Keychain-backed secret handling patterns and providers when credentials are required.
- Apply least-privilege thinking for entitlements, capabilities, and integrations.
- Validate and sanitize external input at module boundaries (network payloads, file content, provider responses).
- Avoid logging sensitive data (keys, tokens, full transcripts, personal identifiers).
- Follow `.agents/rules/security.md` and `.agents/skills/keychain-security/` for concrete implementation guidance.

## Task lifecycle (risk-based)

Use the Standard Task SOP (risk matrix + Fast/Full lanes) as policy.

- **Low risk**: branch in the current checkout, Full review optional, minimum merge gate is `make test`.
- **Medium/High risk**: branch in the current checkout, semáforo review mandatory, merge gate includes `make build` + `make test`.

Preferred branch workflow:

```bash
git checkout main
git pull --ff-only
git checkout -b <branch-name>
# ... implement ...
git checkout main
git merge <branch-name>
git branch -d <branch-name>
```

Detailed procedures:

- `.agents/skills/task-lifecycle/SKILL.md`
- `.agents/skills/git-workflow/SKILL.md`

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
| `.agents/rules/lifecycle-and-memory.md` | Memory management |
| `.agents/rules/network.md` | URLSession and API patterns |
| `.agents/rules/performance.md` | Optimization guidelines |
| `.agents/rules/security.md` | Security best practices |
| `.agents/rules/swift-style.md` | Swift style conventions |
| `.agents/rules/testing.md` | Testing guidelines |
| `.agents/rules/type-security.md` | Type safety patterns |

## Skill precedence (macOS/Swift)

Use this order to reduce overlap and noise when multiple skills could apply:

1. `build-macos-apps` — intake/routing only (select workflow quickly)
2. `macos-development` — canonical macOS/Swift implementation guidance
3. `swift-concurrency-expert` — concurrency compliance/remediation (Swift 6.2+)
4. `swiftui-performance-audit` — SwiftUI runtime performance diagnosis and fixes
5. `swiftui-animation` — advanced animation/transition/shader work when explicitly needed

Notes:

- Treat `build-macos-apps` as orchestrator, not canonical technical reference.
- Prefer canonical references under `.agents/skills/macos-development/` when overlap exists.
- Keep verification aligned to repo commands: `make build|test|lint` and `*-agent` variants.

Performance routing notes:

- Use `swiftui-performance-audit` first for SwiftUI runtime issues (janky scrolling, excessive view updates, layout thrash, animation hitches).
- Use `performance` for system/resource profiling outside SwiftUI rendering (CPU, memory, energy, startup, I/O).
- Use `audio-realtime` when the bottleneck is in capture/processing pipelines rather than SwiftUI rendering.
- Prefer `make profile-report` for repeatable trace capture + metric extraction before/after fixes.

Animation routing notes:

- Use `swiftui-animation` for advanced motion behavior (transitions, matched geometry, animation orchestration, shader effects).
- Use `swiftui-patterns` for general view composition/state patterns when animation is not the core problem.
- Use `native-app-designer` only for high-fidelity visual/motion design exploration, not implementation rules.
- Respect motion accessibility: prefer reduced motion paths when `accessibilityDisplayShouldReduceMotion` is enabled.

Concurrency routing notes:

- Use `swift-concurrency-expert` for compiler diagnostics, actor isolation fixes, Sendable remediation, and Swift 6 migration work.
- Use `concurrency` only for foundational/conceptual guidance when no concrete compiler issue is in scope.
- For code changes touching concurrency, prefer running `make test-strict` and optionally `./scripts/preflight.sh --strict-concurrency` before merge.

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
| `.agents/skills/macos-development/` | macOS apps with SwiftUI/AppKit, lifecycle and platform integration |
| `.agents/skills/build-macos-apps/` | request intake and workflow routing for CLI-first macOS app tasks |
| `.agents/skills/skill-development/` | create skill, develop plugin |
| `.agents/skills/skills-discovery/` | search skills, registry |
| `.agents/skills/preview-coverage/` | SwiftUI preview requirements, preview state coverage |
| `.agents/skills/swift-concurrency-expert/` | Swift 6.2 concurrency review/remediation and compiler error fixes |
| `.agents/skills/swift-package-manager/` | Package.swift, SPM dependencies |
| `.agents/skills/swiftui-animation/` | advanced SwiftUI animation, transitions, matched geometry, Metal shaders |
| `.agents/skills/swiftui-performance-audit/` | SwiftUI runtime performance audits and optimization guidance |
| `.agents/skills/swiftui-patterns/` | SwiftUI views, @State, NavigationStack |
| `.agents/skills/testing-xctest/` | XCTest, @Test, mock, XCTAssert |
