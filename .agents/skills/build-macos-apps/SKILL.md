---
name: build-macos-apps
description: This skill should be used when the user asks to "build a macOS app", "add a macOS feature", "debug a macOS app", or "ship/release the macOS app" and needs workflow routing.
---

# Build macOS Apps (Router Skill)

## Role

Use this skill as an orchestrator only.

- Route user intent to the right workflow quickly.
- Delegate implementation rules to `../macos-development/SKILL.md`.
- Delegate UI/UX direction to `../native-app-designer/SKILL.md`.
- Delegate verification policy to `../quality-assurance/SKILL.md`.
- Delegate specialist domains to their dedicated skills.

## Scope Boundary

Use this skill for intake and routing. Do not duplicate deep implementation guidance here.

- Architecture, platform lifecycle, and AppKit/SwiftUI implementation -> `macos-development`
- UI/UX direction and experience quality baseline -> `native-app-designer`
- Test strategy and merge gates -> `quality-assurance`
- Swift concurrency remediation -> `swift-concurrency-expert`
- SwiftUI runtime performance -> `swiftui-performance-audit`
- Advanced motion/animation work -> `swiftui-animation`

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
| New app, bootstrap, scaffold | `workflows/build-new-app.md` |
| Bug, crash, regression | `workflows/debug-app.md` |
| Feature implementation | `workflows/add-feature.md` |
| Test creation/execution | `workflows/write-tests.md` |
| Performance optimization | `workflows/optimize-performance.md` |
| Distribution/release | `workflows/ship-app.md` |
| Unclear | Ask one clarification question, then route |

## Workflow Execution Rules

1. Pick exactly one primary workflow.
2. Load supporting references only when needed from `references/`.
3. Keep implementation details in specialized skills instead of adding them here.
4. Before final push/merge, apply quality gates via `quality-assurance`.

## Verification Baseline

Use repository commands:

```bash
make build-test
make preflight-agent
```

For Medium/High risk merge gates, keep canonical checks:

```bash
make build-test
```

## Related Skills

- `../macos-development/SKILL.md`
- `../native-app-designer/SKILL.md`
- `../quality-assurance/SKILL.md`
- `../swift-concurrency-expert/SKILL.md`
- `../swiftui-performance-audit/SKILL.md`
- `../swiftui-animation/SKILL.md`
