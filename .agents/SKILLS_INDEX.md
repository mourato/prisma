# Skills Index

Comprehensive index of all available agent skills for Prisma. For routing logic and guidance on selecting the right skill, see [Skill Routing Guide](./docs/skill-routing.md).

## Complete Skills Table

| Skill | Location | Triggers / When to Use |
|-------|----------|------------------------|
| `accessibility-audit` | `.agents/skills/accessibility-audit/` | Audit VoiceOver, keyboard navigation, focus order, reduced motion, overlays, and other accessibility-sensitive UI behavior |
| `architecture` | `.agents/skills/architecture/` | Design module boundaries, apply Clean Architecture, refactor architecture, define dependency injection |
| `audio-realtime` | `.agents/skills/audio-realtime/` | AVAudioSourceNode, AudioRecorder, ProcessTap, audio glitches, underruns, low-latency optimization |
| `build-macos-apps` | `.agents/skills/build-macos-apps/` | Request intake and workflow routing for macOS app tasks (select Fast vs Full lane quickly) |
| `code-quality` | `.agents/skills/code-quality/` | Improve code readability, rename for clarity, refactor duplicated logic, apply clean code conventions |
| `code-review` | `.agents/skills/code-review/` | Review changes, do semáforo review (🔴/🟡/🟢), audit PRs, find risks before merge |
| `concurrency` | `.agents/skills/concurrency/` | Conceptual guidance on async/await, actors, thread-safety patterns (NOT Swift 6.2 compiler fixes) |
| `data-persistence` | `.agents/skills/data-persistence/` | Store/load data, design repositories, plan migrations, implement synchronization |
| `debugging-strategies` | `.agents/skills/debugging-strategies/` | Debug bugs, investigate crashes, analyze flaky behavior, trace unknown root causes |
| `documentation` | `.agents/skills/documentation/` | Write/update documentation, add DocC comments, improve MARK organization, research API docs |
| `error-handling` | `.agents/skills/error-handling/` | Design error types, improve error propagation, add recovery paths, standardize error logging |
| `git-advanced-workflows` | `.agents/skills/git-advanced-workflows/` | Rebase, cherry-pick, run git bisect, use reflog, recover complex git history |
| `git-workflow` | `.agents/skills/git-workflow/` | Standard Git flow: create branch, commit changes, prepare PR, merge safely |
| `git-worktree` | `.agents/skills/git-worktree/` | Use git worktree, migrate away from worktrees, handle legacy worktree setup |
| `intelligence-kernel` | `.agents/skills/intelligence-kernel/` | Canonical summary schema, intelligence kernel modes, trust flags, summary benchmark gates |
| `keychain-security` | `.agents/skills/keychain-security/` | Store secret in Keychain, retrieve API keys securely, delete credential, harden KeychainManager usage |
| `localization` | `.agents/skills/localization/` | Localize UI text, update Localizable.strings, improve accessible copy, remove orphaned locale keys |
| `macos-design-guidelines` | `.agents/skills/macos-design-guidelines/` | Apply macOS Human Interface Guidelines for desktop UI, menus, shortcuts, windows, and native interaction patterns |
| `macos-development` | `.agents/skills/macos-development/` | Implement macOS features, integrate SwiftUI with AppKit, fix macOS lifecycle issues, platform-specific patterns |
| `menubar` | `.agents/skills/menubar/` | Build menu-bar behavior, configure NSStatusItem, implement popover, manage non-activating overlays |
| `native-app-designer` | `.agents/skills/native-app-designer/` | Primary for UI/UX: design or redesign macOS/iOS interfaces, improve UX, analyze UI quality, define visual and motion direction |
| `networking` | `.agents/skills/networking/` | Build API client, model request/response, configure URLSession, improve network resiliency/security |
| `observability-diagnostics` | `.agents/skills/observability-diagnostics/` | Standardize logging, telemetry, redaction, diagnostic signatures, and metric correlation |
| `performance` | `.agents/skills/performance/` | Optimize CPU/memory/startup, profile with Instruments, improve app-wide performance (outside SwiftUI rendering) |
| `preview-coverage` | `.agents/skills/preview-coverage/` | Add SwiftUI previews, verify preview state coverage, ensure all views have #Preview |
| `project-standards` | `.agents/skills/project-standards/` | Update AGENTS.md, document project policy, track known limitations, align repository standards |
| `quality-assurance` | `.agents/skills/quality-assurance/` | Define verification gates, select validation commands, and run quality checks before merge |
| `security` | `.agents/skills/security/` | Improve security posture, validate untrusted input, protect sensitive data, apply platform security controls |
| `skill-development` | `.agents/skills/skill-development/` | Create a skill, refactor SKILL.md, improve skill trigger descriptions, modularize skill resources |
| `skills-discovery` | `.agents/skills/skills-discovery/` | Find skills, search the skills registry, install/manage installed skills |
| `swift-concurrency-expert` | `.agents/skills/swift-concurrency-expert/` | Primary for concurrency issues: fix Swift concurrency errors, resolve actor isolation, remediate Sendable diagnostics, upgrade Swift 6.2 |
| `swift-conventions` | `.agents/skills/swift-conventions/` | Apply Swift style conventions, improve type safety, refactor API naming, organize Swift modules |
| `swift-package-manager` | `.agents/skills/swift-package-manager/` | Edit Package.swift, manage SPM dependencies, fix package resolution, troubleshoot SwiftPM |
| `swiftui-animation` | `.agents/skills/swiftui-animation/` | Implement SwiftUI transitions, create advanced animations, use matched geometry, apply shader-based effects |
| `swiftui-patterns` | `.agents/skills/swiftui-patterns/` | Build SwiftUI views, improve state management, refactor SwiftUI layouts, use design system components |
| `swiftui-performance-audit` | `.agents/skills/swiftui-performance-audit/` | Primary for UI performance: fix janky SwiftUI scrolling, reduce excessive view updates, diagnose layout thrash, audit runtime performance |
| `task-lifecycle` | `.agents/skills/task-lifecycle/` | Run task lifecycle, classify risk lane, prepare implementation workflow, enforce pre-merge gates |
| `testing-xctest` | `.agents/skills/testing-xctest/` | Write XCTest code, structure async and `@MainActor` tests, build mocks/fakes/spies, and keep test suites maintainable |

---

## Skill Selection Quick Reference

### By Problem Type

**UI/UX and Interfaces**
- First: `native-app-designer`
- Then: `macos-design-guidelines` → `swiftui-patterns` → `swiftui-animation` → `swiftui-performance-audit`
- Audit accessibility-sensitive UI with `accessibility-audit`

**Performance Issues**
- SwiftUI rendering: `swiftui-performance-audit`
- System-level (CPU/memory/energy): `performance`
- Audio capture/processing: `audio-realtime`
- Logging and telemetry quality: `observability-diagnostics`

**Concurrency and Safety**
- Swift 6.2 compiler errors: `swift-concurrency-expert`
- Conceptual guidance: `concurrency`

**Code Quality**
- Readability/refactoring: `code-quality`
- Testing/mocks and test code structure: `testing-xctest`
- Merge gates and verification policy: `quality-assurance`
- Code review: `code-review`
- Architecture boundaries: `architecture`
- Error propagation and recovery: `error-handling`

**Security**
- Data protection/input validation: `security`
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
- General macOS/Swift guidance: `macos-development`
- Native HIG alignment: `macos-design-guidelines`
- Menu bar UI: `menubar`

**Dependencies and Build**
- SPM/Package.swift: `swift-package-manager`
- Build workflow/routing: `build-macos-apps`

**Project Maintenance**
- Repository standards: `project-standards`
- Skill development: `skill-development`
- External skill discovery: `skills-discovery`

### Engineering Workflow Ownership

- `task-lifecycle`: risk classification, lane selection, lifecycle sequencing
- `quality-assurance`: validation strategy, command mapping, escalation to full gates
- `git-workflow`: branch, commit, PR, and cleanup mechanics
- `code-review`: findings format, severity framing, semáforo review output
- `build-macos-apps`: macOS request intake and routing only

---

## Skill Dependencies

- `accessibility-audit` → `localization` (copy and keys stay localizable)
- `build-macos-apps` → `macos-development` (router → canonical implementation)
- `build-macos-apps` → `task-lifecycle` (router → lifecycle policy)
- `swiftui-patterns` → `native-app-designer` (UX direction first)
- `swiftui-animation` → `swiftui-patterns` (composition before animation)
- `swiftui-performance-audit` → `swiftui-patterns` (diagnose then refactor)
- `swift-concurrency-expert` → `concurrency` (fixes build on concepts)
- `security` → `keychain-security` (general → specific for secrets)
- `data-persistence` → `security` (if sensitive data involved)
- `quality-assurance` → `testing-xctest` (general QA → XCTest specifics)
- `observability-diagnostics` → `debugging-strategies` (diagnostic data supports investigation)
- `code-review` → other skills (review may escalate to specific domain)
