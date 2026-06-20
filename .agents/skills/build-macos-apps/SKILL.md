---
name: build-macos-apps
description: This skill should be used when the user asks to "build a macOS app", "add a macOS feature", "debug a macOS app", or "ship/release the macOS app" and needs workflow routing.
---

# Build macOS Apps (Router Skill)

## Role

Use this skill as an intake router only.

- Route user intent to the right canonical skill quickly.
- Delegate implementation rules to `../macos-development/SKILL.md`.
- Delegate UI/UX direction to `../native-app-designer/SKILL.md`.
- Delegate lifecycle and verification policy to `../task-lifecycle/SKILL.md` and `../quality-assurance/SKILL.md`.

## Scope Boundary

Use this skill for intake and routing only. Do not add duplicated implementation workflows or reference trees here.

- Architecture, platform lifecycle, and AppKit/SwiftUI implementation -> `macos-development`
- Human Interface Guidelines and native interaction quality -> `macos-design-guidelines`
- UI/UX direction and experience quality baseline -> `native-app-designer`
- Risk classification and merge lifecycle -> `task-lifecycle`
- Verification commands and scope checks -> `quality-assurance`
- Swift concurrency remediation -> `swift-concurrency-expert`
- SwiftUI runtime performance -> `swiftui-performance-audit`
- Advanced motion/animation work -> `swiftui-animation`
- XCTest implementation details -> `testing-xctest`
- Accessibility audit and keyboard/focus review -> `accessibility-audit`

## When to Use

Use this skill when the request is broad and macOS-oriented, and the first job is to route quickly to the right owner rather than provide deep implementation guidance.

## Intake

Ask the user what they need:

1. Build a new app
2. Debug an existing app
3. Add a feature
4. Write or run tests
5. Optimize performance
6. Ship or release
7. Something else

## Routing Table

| User intent | Route to |
|---|---|
| Broad macOS feature work | `../macos-development/SKILL.md` + `../task-lifecycle/SKILL.md` |
| Bug, crash, regression | `../debugging-strategies/SKILL.md`, then the narrowed subsystem owner |
| Feature implementation | `../macos-development/SKILL.md` + `../task-lifecycle/SKILL.md` |
| Test creation/execution | `../testing-xctest/SKILL.md` + `../quality-assurance/SKILL.md` |
| Performance optimization | `../swiftui-performance-audit/SKILL.md`, `../performance/SKILL.md`, or `../audio-realtime/SKILL.md` based on the bottleneck |
| Distribution/release | `../macos-development/SKILL.md` + `../quality-assurance/SKILL.md` |
| Unclear | Ask one clarification question, then route |

## Canonical References

- Implementation references live under `../macos-development/references/`.
- Routing, risk, and merge policy live in `../task-lifecycle/SKILL.md`.
- Verification commands live in `../quality-assurance/SKILL.md`.
- External skills are optional. Do not route to an external skill unless it is already installed locally or the user explicitly asks to discover/install one via `../skills-discovery/SKILL.md`.
- If a topic already has a specialist owner, route there instead of adding more guidance here.

## Verification Handoff

- Use `../task-lifecycle/SKILL.md` when the request needs lane selection or lifecycle sequencing.
- Use `../quality-assurance/SKILL.md` when the request needs concrete validation commands.
- Use `../code-review/SKILL.md` when the request is a review rather than an implementation task.

## Related Skills

- `../macos-development/SKILL.md`
- `../macos-design-guidelines/SKILL.md`
- `../native-app-designer/SKILL.md`
- `../task-lifecycle/SKILL.md`
- `../quality-assurance/SKILL.md`
- `../testing-xctest/SKILL.md`
- `../accessibility-audit/SKILL.md`
