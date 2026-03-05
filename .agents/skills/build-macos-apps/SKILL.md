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

## 2026-03 Progression Update

### Evidence-Driven Priority

Recent release automation churn (commits `51c53eb`, `37bcb34`, `d82fb9d`, `09bb449`, `c120858`) indicates the release path is still fragile.

### Release Triage Drill (apply on each release-task request)

1. Verify workflow gate logic in `.github/workflows/sparkle-release.yml`.
2. Reproduce gate locally with explicit `xcodebuild` command parity to CI.
3. Ensure failure artifacts are exported when gate fails.
4. Record one short "failure signature -> fix action" note in PR description.

### Routing Note

When a task is specifically about failing GitHub Actions checks, route to `gh-fix-ci` first, then return to this skill for macOS release workflow wiring.

## Related Skills

- `../macos-development/SKILL.md`
- `../native-app-designer/SKILL.md`
- `../quality-assurance/SKILL.md`
- `../swift-concurrency-expert/SKILL.md`
- `../swiftui-performance-audit/SKILL.md`
- `../swiftui-animation/SKILL.md`


## 2026-03-05 Progression Drill

### New Evidence

- `2da490b` introduced build/publish split; `3c1477a` later needed explicit tag checkout before parity.
- `d19fbab`, `6e8d327`, and `be3e56f` fixed artifact path and permission drift after download.
- `44db00e` and `f3d928f` fixed appcast key path and version metadata parity errors.

### Skill Deepening Focus

1. Add a mandatory release handoff checklist: checkout ref, artifact paths, executable permissions, appcast key path, version parity.
2. On every release workflow task, require one local parity run via `scripts/ci-release-parity.sh` before proposing merge.
3. Capture "first failing step + root mismatch" in PR notes to reduce repeated CI-only debugging loops.
4. Route CI-check triage to `gh-fix-ci` first when failure originates in GitHub Actions logs, then return here for workflow wiring changes.
