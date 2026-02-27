# Skills Index

Comprehensive index of all available agent skills for Meeting Assistant. For routing logic and guidance on selecting the right skill, see [Skill Routing Guide](./.agents/docs/skill-routing.md).

## Complete Skills Table

| Skill | Location | Triggers / When to Use |
|-------|----------|------------------------|
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
| `localization` | `.agents/skills/localization/` | Localize UI text, update Localizable.strings, improve VoiceOver labels, add accessibility localization |
| `macos-development` | `.agents/skills/macos-development/` | Implement macOS features, integrate SwiftUI with AppKit, fix macOS lifecycle issues, platform-specific patterns |
| `menubar` | `.agents/skills/menubar/` | Build menu-bar behavior, configure NSStatusItem, implement popover, manage non-activating overlays |
| `native-app-designer` | `.agents/skills/native-app-designer/` | **Primary for UI/UX**: Design/redesign macOS/iOS interface, improve UX, analyze UI quality, define visual/motion direction |
| `networking` | `.agents/skills/networking/` | Build API client, model request/response, configure URLSession, improve network resiliency/security |
| `performance` | `.agents/skills/performance/` | Optimize CPU/memory/startup, profile with Instruments, improve app-wide performance (outside SwiftUI rendering) |
| `preview-coverage` | `.agents/skills/preview-coverage/` | Add SwiftUI previews, verify preview state coverage, ensure all views have #Preview |
| `project-standards` | `.agents/skills/project-standards/` | Update AGENTS.md, document project policy, track known limitations, align repository standards |
| `quality-assurance` | `.agents/skills/quality-assurance/` | Write tests, create mocks, define verification gates, run quality checks before merge |
| `security` | `.agents/skills/security/` | Improve security posture, validate untrusted input, protect sensitive data, apply platform security controls |
| `skill-development` | `.agents/skills/skill-development/` | Create a skill, refactor SKILL.md, improve skill trigger descriptions, modularize skill resources |
| `skills-discovery` | `.agents/skills/skills-discovery/` | Find skills, search the skills registry, install/manage installed skills |
| `swift-concurrency-expert` | `.agents/skills/swift-concurrency-expert/` | **PRIMARY for concurrency issues**: Fix Swift concurrency errors, resolve actor isolation, remediate Sendable diagnostics, upgrade Swift 6.2 |
| `swift-conventions` | `.agents/skills/swift-conventions/` | Apply Swift style conventions, improve type safety, refactor API naming, organize Swift modules |
| `swift-package-manager` | `.agents/skills/swift-package-manager/` | Edit Package.swift, manage SPM dependencies, fix package resolution, troubleshoot SwiftPM |
| `swiftui-animation` | `.agents/skills/swiftui-animation/` | Implement SwiftUI transitions, create advanced animations, use matched geometry, apply shader-based effects |
| `swiftui-patterns` | `.agents/skills/swiftui-patterns/` | Build SwiftUI views, improve state management, refactor SwiftUI layouts, use design system components |
| `swiftui-performance-audit` | `.agents/skills/swiftui-performance-audit/` | **PRIMARY for UI performance**: Fix janky SwiftUI scrolling, reduce excessive view updates, diagnose layout thrash, audit runtime performance |
| `task-lifecycle` | `.agents/skills/task-lifecycle/` | Run task lifecycle, classify risk lane, prepare implementation workflow, enforce pre-merge gates |

---

## Skill Selection Quick Reference

### By Problem Type

**UI/UX and Interfaces**
- First: `native-app-designer`
- Then: `swiftui-patterns` → `swiftui-animation` → `swiftui-performance-audit`

**Performance Issues**
- SwiftUI rendering: `swiftui-performance-audit`
- System-level (CPU/memory/energy): `performance`
- Audio capture/processing: `audio-realtime`

**Concurrency and Safety**
- Swift 6.2 compiler errors: `swift-concurrency-expert`
- Conceptual guidance: `concurrency`

**Code Quality**
- Readability/refactoring: `code-quality`
- Testing/mocks: `quality-assurance` or `testing` (if XCTest-specific)
- Code review: `code-review`

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
- Area-specific: escalate to relevant skill (audio-realtime, concurrency, etc.)

**Git and Version Control**
- Standard operations: `git-workflow`
- Advanced (rebase, bisect): `git-advanced-workflows`
- Worktrees: `git-worktree`

**Documentation and Localization**
- API docs/DocC: `documentation`
- UI localization/VoiceOver: `localization`

**Platform-Specific (macOS)**
- General macOS/Swift guidance: `macos-development`
- Menu bar UI: `menubar`

**Dependencies and Build**
- SPM/Package.swift: `swift-package-manager`
- Build workflow/routing: `build-macos-apps`

**Project Maintenance**
- Repository standards: `project-standards`
- Skill development: `skill-development`

---

## Skill Dependencies

Some skills reference or build on others:

- `swiftui-patterns` → `native-app-designer` (UX direction first)
- `swiftui-animation` → `swiftui-patterns` (composition before animation)
- `swiftui-performance-audit` → `swiftui-patterns` (diagnose then refactor)
- `swift-concurrency-expert` → `concurrency` (fixes build on concepts)
- `security` → `keychain-security` (general → specific for secrets)
- `data-persistence` → `security` (if sensitive data involved)
- `quality-assurance` → `testing-xctest` (general QA → XCTest specifics)
- `code-review` → other skills (review may escalate to specific domain)

---

## Notes

- Skills are referenced by folder name (e.g., `macos-development` → `.agents/skills/macos-development/SKILL.md`)
- See [Skill Routing Guide](./.agents/docs/skill-routing.md) for decision logic and flow
- Each skill file (SKILL.md) contains detailed guidance, examples, and implementation patterns
- Not all skills apply to every task—consult selectively based on problem type
