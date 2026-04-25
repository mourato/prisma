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
- Keep release and CI triage notes here only when they affect routing.

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
| New app, bootstrap, scaffold | `../macos-development/workflows/build-new-app.md` |
| Bug, crash, regression | `../macos-development/workflows/debug-app.md` + `../debugging-strategies/SKILL.md` |
| Feature implementation | `../macos-development/workflows/add-feature.md` |
| Test creation/execution | `../testing-xctest/SKILL.md` + `../quality-assurance/SKILL.md` |
| Performance optimization | `../macos-development/workflows/optimize-performance.md` |
| Distribution/release | `../macos-development/workflows/ship-app.md` |
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

## Release Command Surface (Current)

- Use `make dmg` as the single DMG entrypoint.
- `make dmg` auto-detects self-signed mode only when `MA_RELEASE_CODE_SIGN_IDENTITY` exists in keychain.
- Force mode when needed:
  - `MA_RELEASE_SIGNING_MODE=adhoc make dmg`
  - `MA_RELEASE_SIGNING_MODE=self-signed make dmg`
- Bootstrap local identity with `make setup-self-signed-cert`.

## 2026-03 Progression Update

### Evidence-Driven Priority

Recent release automation churn (commits `51c53eb`, `37bcb34`, `d82fb9d`, `09bb449`, `c120858`) indicates the release path is still fragile.

### Release Triage Drill (apply on each release-task request)

1. Verify workflow gate logic in `.github/workflows/sparkle-release.yml`.
2. Reproduce gate locally with explicit `xcodebuild` command parity to CI.
3. Ensure failure artifacts are exported when gate fails.
4. Record one short "failure signature -> fix action" note in PR description.

### Routing Note

When a task is specifically about failing GitHub Actions checks, inspect the workflow directly with `gh run view --log-failed` and pair the investigation with `../debugging-strategies/SKILL.md`, then return here for macOS release workflow wiring.

## 2026-03-05 Progression Drill

### New Evidence

- `2da490b` introduced build/publish split; `3c1477a` later needed explicit tag checkout before parity.
- `d19fbab`, `6e8d327`, and `be3e56f` fixed artifact path and permission drift after download.
- `44db00e` and `f3d928f` fixed appcast key path and version metadata parity errors.

### Skill Deepening Focus

1. Add a mandatory release handoff checklist: checkout ref, artifact paths, executable permissions, appcast key path, version parity.
2. On every release workflow task, require one local parity run via `scripts/ci-release-parity.sh` before proposing merge.
3. Capture "first failing step + root mismatch" in PR notes to reduce repeated CI-only debugging loops.
4. Triage CI-check failures with `gh run view --log-failed` plus `../debugging-strategies/SKILL.md`, then return here for workflow wiring changes.

## 2026-03-06 Progression Drill

### New Evidence

- `0bf9269` consolidated DMG entrypoints under `make dmg` and introduced self-signed auto-detection.
- `773ceb7` adjusted signing identity detection stability in `scripts/config/release_signing.sh` and setup flow.
- `0302327` and `6cbde40` show parity-script hardening was still required for appcast signature enforcement.

### Skill Deepening Focus

1. For every signing/release task, run a two-mode preflight: default auto-detect path and forced override path (`MA_RELEASE_SIGNING_MODE=adhoc|self-signed`).
2. Require a deterministic checklist item in task notes: keychain identity discovery result, selected signing mode, and final `make dmg` path taken.
3. Treat any parity-script diff (`scripts/ci-release-parity.sh`) as release-surface change and require explicit mapping to expected Sparkle/appcast behavior.
4. If signing failures are runner- or env-sensitive, inspect GitHub Actions logs with `gh run view --log-failed` first, then return here only for workflow/command-surface corrections.

## Related Skills

- `../macos-development/SKILL.md`
- `../macos-design-guidelines/SKILL.md`
- `../native-app-designer/SKILL.md`
- `../task-lifecycle/SKILL.md`
- `../quality-assurance/SKILL.md`
- `../testing-xctest/SKILL.md`
- `../accessibility-audit/SKILL.md`
