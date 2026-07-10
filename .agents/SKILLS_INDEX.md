# Skills Index

Comprehensive index of all available agent skills for Prisma. For routing logic and guidance on selecting the right skill, see [Skill Routing Guide](./docs/skill-routing.md).

## Complete Skills Table

| Skill | Location | Triggers / When to Use |
|-------|----------|------------------------|
| `accessibility-audit` | `.agents/skills/accessibility-audit/` | Audit VoiceOver, keyboard navigation, focus order, reduced motion, overlays, and other accessibility-sensitive UI behavior |
| `benchmarking` | `.agents/skills/benchmarking/` | Triggered by mentions of VoiceInk, FluidVoice, TypeWhisper, or "referência/inspiração". Provides canonical paths and clone policy for reference projects |
| `architecture` | `.agents/skills/architecture/` | Design module boundaries, apply Clean Architecture, refactor architecture, define dependency injection |
| `audio-realtime` | `.agents/skills/audio-realtime/` | AVAudioSourceNode, AudioRecorder, ProcessTap, audio glitches, underruns, low-latency optimization |
| `code-quality` | `.agents/skills/code-quality/` | Improve code readability, rename for clarity, refactor duplicated logic, apply clean code conventions |
| `data-persistence` | `.agents/skills/data-persistence/` | Store/load data, design repositories, plan migrations, implement synchronization |
| `debugging-strategies` | `.agents/skills/debugging-strategies/` | Debug bugs, investigate crashes, analyze flaky behavior, trace unknown root causes |
| `documentation` | `.agents/skills/documentation/` | Write/update documentation, add DocC comments, improve MARK organization, research API docs |
| `git-workflow` | `.agents/skills/git-workflow/` | Standard Git flow: create branch, commit changes, prepare PR, merge safely |
| `improve` | `.agents/skills/improve/` | Audit a codebase, find improvement opportunities, suggest roadmap direction, or write implementation plans for another agent |
| `intelligence-kernel` | `.agents/skills/intelligence-kernel/` | Canonical summary schema, intelligence kernel modes, trust flags, summary benchmark gates |
| `keychain-security` | `.agents/skills/keychain-security/` | Store secret in Keychain, retrieve API keys securely, delete credential, harden KeychainManager usage |
| `localization` | `.agents/skills/localization/` | Localize UI text, update Localizable.strings, improve accessible copy, remove orphaned locale keys |
| `macos-app-engineering` | `.agents/skills/macos-app-engineering/` | macOS UI/app implementation, SwiftUI views, AppKit bridging, Settings UI, design-system components, preview coverage, and platform lifecycle |
| `menubar` | `.agents/skills/menubar/` | Build menu-bar behavior, configure NSStatusItem, implement popover, manage non-activating overlays |
| `observability-diagnostics` | `.agents/skills/observability-diagnostics/` | Standardize logging, telemetry, redaction, diagnostic signatures, and metric correlation |
| `project-standards` | `.agents/skills/project-standards/` | Update AGENTS.md, document project policy, track known limitations, align repository standards |
| `quality-assurance` | `.agents/skills/quality-assurance/` | Define verification gates, select validation commands, and run quality checks before merge |
| `swift-concurrency-expert` | `.agents/skills/swift-concurrency-expert/` | Primary for concurrency issues: fix Swift concurrency errors, resolve actor isolation, remediate Sendable diagnostics, upgrade Swift 6.2 |
| `swift-conventions` | `.agents/skills/swift-conventions/` | Apply Swift style conventions, improve type safety, refactor API naming, organize Swift modules |
| `task-lifecycle` | `.agents/skills/task-lifecycle/` | Run task lifecycle, classify risk lane, prepare implementation workflow, enforce pre-merge gates |
| `testing-xctest` | `.agents/skills/testing-xctest/` | Write XCTest code, structure async and `@MainActor` tests, build mocks/fakes/spies, and keep test suites maintainable |
| `thermo-nuclear-code-quality-review` | `.agents/skills/thermo-nuclear-code-quality-review/` | Default code review skill: review changes, audit PRs, find risks before merge, produce semaforo findings, and run strict maintainability analysis |

---

## Skill Selection Quick Reference

### By Problem Type

**UI/UX and Interfaces**
- First: `macos-app-engineering`
- Escalate to `accessibility-audit`, `localization`, `menubar`, `debugging-strategies`, or `swift-concurrency-expert` when the task is specifically in that specialist scope

**Performance Issues**
- SwiftUI rendering: `macos-app-engineering` for view structure, then `debugging-strategies` if root cause is unclear
- Audio capture/processing: `audio-realtime`
- Logging and telemetry quality: `observability-diagnostics`

**Concurrency and Safety**
- Swift 6.2 compiler errors: `swift-concurrency-expert`

**Code Quality**
- Readability/refactoring: `code-quality`
- Testing/mocks and test code structure: `testing-xctest`
- Merge gates and verification policy: `quality-assurance`
- Code review: `thermo-nuclear-code-quality-review`
- Architecture boundaries: `architecture`

**Security**
- Secret management: `keychain-security`

**Data and Storage**
- Persistence design: `data-persistence`
- Migrations: `data-persistence`

**Intelligence and Post-Processing**
- Kernel mode routing, canonical summary, benchmark gates: `intelligence-kernel`

**Debugging**
- Crashes/flaky tests: `debugging-strategies`
- Area-specific diagnostics: `observability-diagnostics`

**Documentation and Localization**
- API docs/DocC: `documentation`
- UI localization and accessible copy: `localization`
- Accessibility audit and keyboard/focus review: `accessibility-audit`

**Platform-Specific (macOS)**
- General macOS UI/app guidance: `macos-app-engineering`
- Menu bar UI: `menubar`



**Project Maintenance**
- Repository standards: `project-standards`
- Read-only improvement planning: `improve`
- Strict maintainability review: `thermo-nuclear-code-quality-review`
- Reference project registry and clone policy: `benchmarking`

### Engineering Workflow Ownership

- `task-lifecycle`: risk classification, lane selection, lifecycle sequencing
- `quality-assurance`: validation strategy, command mapping, escalation to full gates
- `git-workflow`: branch, commit, PR, and cleanup mechanics
- `thermo-nuclear-code-quality-review`: review findings, severity framing, semaforo output, and strict structural maintainability analysis

---

## Skill Dependencies

- `accessibility-audit` → `localization` (copy and keys stay localizable)
- `macos-app-engineering` → `accessibility-audit` / `localization` / `menubar` (specialist escalation only)
- `quality-assurance` → `testing-xctest` (general QA → XCTest specifics)
- `observability-diagnostics` → `debugging-strategies` (diagnostic data supports investigation)
- `thermo-nuclear-code-quality-review` → `task-lifecycle` / `quality-assurance` / other skills (review may escalate to lane, validation, or subsystem specialists)
