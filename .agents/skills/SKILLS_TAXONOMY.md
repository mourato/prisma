# Skills Taxonomy Matrix

This matrix defines ownership, overlap, and action for all skills under `.agents/skills`.

| Skill | Theme | Owner | Scope | Overlap With | Action |
|---|---|---|---|---|---|
| architecture | macOS/Swift Core | Canonical | Clean Architecture, module boundaries, DI | macos-development | Keep; clarify architecture-only scope |
| audio-realtime | Runtime/Performance | Canonical | Low-latency audio pipeline and callback constraints | performance, debugging-strategies | Keep; specialized runtime owner |
| build-macos-apps | macOS/Swift Core | Router | Intake and workflow routing for macOS tasks | macos-development, quality-assurance | Keep; router-only, no deep implementation duplication |
| code-quality | Quality/Engineering Flow | Canonical (generic) | Readability and maintainability principles | swift-conventions | Keep; non-language-specific quality owner |
| code-review | Quality/Engineering Flow | Canonical | Risk-first review ritual and findings format | task-lifecycle, quality-assurance | Keep; review specialist |
| concurrency | Runtime/Performance | Bridge | Conceptual async/actor/thread-safety guidance | swift-concurrency-expert | Keep; bridge only |
| data-persistence | Security/Data | Canonical | Repository/storage/migration strategy | architecture | Keep |
| debugging-strategies | Runtime/Performance | Canonical (method) | Cross-cutting debugging methodology | performance, swiftui-performance-audit | Keep; investigation owner |
| documentation | Quality/Engineering Flow | Canonical | DocC/docs structure and research patterns | project-standards | Keep |
| error-handling | Security/Data | Canonical | Error modeling, propagation, recovery, logging | code-quality | Keep |
| git-advanced-workflows | Git/Collaboration | Canonical (advanced) | Rebase/cherry-pick/bisect/reflog recovery | git-workflow | Keep; advanced owner |
| git-workflow | Git/Collaboration | Canonical (standard) | Branch/commit/PR flow | task-lifecycle | Keep; standard owner |
| git-worktree | Git/Collaboration | Legacy | Optional legacy worktree operations | git-workflow | Keep as optional legacy |
| keychain-security | Security/Data | Canonical (credentials) | Keychain credential persistence and APIs | security, networking | Keep; credential owner |
| localization | Security/Data | Canonical | Localization plus accessibility text practices | swiftui-patterns | Keep |
| macos-development | macOS/Swift Core | Canonical | Implementation guidance for macOS SwiftUI/AppKit | build-macos-apps | Keep; deep implementation owner |
| menubar | SwiftUI/UI/UX | Canonical | NSStatusItem/popover/floating-panel patterns | macos-development | Keep |
| native-app-designer | SwiftUI/UI/UX | Canonical | Visual direction and high-fidelity motion design | swiftui-animation, swiftui-patterns | Keep |
| networking | Security/Data | Canonical (transport) | URLSession, request modeling, resiliency | security, keychain-security | Keep; transport owner |
| performance | Runtime/Performance | Canonical (system) | App-wide CPU/memory/startup optimization | swiftui-performance-audit, debugging-strategies | Keep; non-SwiftUI-rendering owner |
| preview-coverage | SwiftUI/UI/UX | Canonical | SwiftUI preview requirements and coverage | swiftui-patterns | Keep |
| project-standards | Quality/Engineering Flow | Canonical | AGENTS/project policy and known limitations process | documentation | Keep |
| quality-assurance | Quality/Engineering Flow | Canonical | Verification lanes, checks, merge gates | task-lifecycle | Keep |
| security | Security/Data | Canonical (baseline) | Threat model baseline, validation, sensitive data controls | keychain-security, networking | Keep; baseline security owner |
| skill-development | Meta-skills | Canonical | Skill authoring/refactoring/modularization workflow | skills-discovery | Keep; streamlined orchestrator |
| skills-discovery | Meta-skills | Canonical | Discover/install/manage external skills | skill-development | Keep |
| swift-concurrency-expert | Runtime/Performance | Canonical (Swift 6.2) | Concurrency diagnostics and remediation | concurrency | Keep; concrete remediation owner |
| swift-conventions | macOS/Swift Core | Canonical (Swift language) | Swift-specific style/type safety/module conventions | code-quality | Keep; Swift-specific owner |
| swift-package-manager | macOS/Swift Core | Canonical | Package.swift and SPM dependency management | macos-development | Keep |
| swiftui-animation | SwiftUI/UI/UX | Canonical | Advanced SwiftUI motion/transitions/shader effects | native-app-designer | Keep |
| swiftui-patterns | SwiftUI/UI/UX | Canonical | View/state/layout/design-system composition | preview-coverage | Keep |
| swiftui-performance-audit | SwiftUI/UI/UX | Canonical (runtime perf) | SwiftUI rendering/update/layout performance diagnostics | performance, debugging-strategies | Keep |
| task-lifecycle | Quality/Engineering Flow | Canonical (macro flow) | Risk classification and lifecycle phase orchestration | git-workflow, quality-assurance, code-review | Keep; macro orchestrator |
| ui-ux-pro-max | SwiftUI/UI/UX | Deprecated (compat) | Legacy compatibility router for historical references | native-app-designer, swiftui-patterns, swiftui-animation | Keep deprecated; do not extend |

## Grouping Summary

1. macOS/Swift Core: `build-macos-apps`, `macos-development`, `architecture`, `swift-conventions`, `swift-package-manager`
2. SwiftUI/UI/UX: `swiftui-patterns`, `swiftui-animation`, `swiftui-performance-audit`, `preview-coverage`, `native-app-designer`, `menubar`
3. Runtime/Performance: `concurrency`, `swift-concurrency-expert`, `performance`, `debugging-strategies`, `audio-realtime`
4. Quality/Engineering Flow: `quality-assurance`, `code-review`, `code-quality`, `task-lifecycle`, `project-standards`, `documentation`
5. Security/Data: `security`, `keychain-security`, `networking`, `data-persistence`, `error-handling`, `localization`
6. Git/Collaboration: `git-workflow`, `git-advanced-workflows`, `git-worktree`
7. Meta-skills: `skill-development`, `skills-discovery`
