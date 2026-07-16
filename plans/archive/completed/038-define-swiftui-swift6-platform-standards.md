# Plan 038: Define the Swift 6.2 and macOS SwiftUI project standards

> **Executor instructions**: This is a documentation and agent-governance plan. Do not modify Swift source, tests, build settings, or product behavior. Run every verification command and stop on the conditions below.
>
> **Drift check**: `git diff --stat 80ed5788..HEAD -- AGENTS.md .agents/SKILLS_INDEX.md .agents/SKILLS_TAXONOMY.md .agents/docs/skill-routing.md .agents/skills/swiftui-pro .agents/skills/project-standards plans/README.md`

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: LOW
- **Depends on**: none
- **Category**: docs
- **Planned at**: commit `80ed5788`, 2026-07-12
- **Related issue**: none

## Why this matters

Prisma has adopted `swiftui-pro`, but the skill is not registered in the project skill index/taxonomy and `make guidance-check` currently rejects its plugin bundle layout. Project guidance also says Swift 5.9+, `.swift-version` says 6.0, and Xcode targets use Swift 5.0. This plan establishes one macOS-specific standard: macOS 15 minimum, Tahoe/Golden Gate APIs gated by availability, Swift 6.2+ as the language baseline, Observation for new UI state, and explicit concurrency boundaries.

## Current state

- `AGENTS.md:23` says `macOS 15+ (Swift 5.9+)`.
- `.swift-version` contains `6.0`.
- `.agents/skills/swiftui-pro/SKILL.md:29-34` is written with iOS-oriented defaults and lacks the repository-required `Role`, `Scope Boundary`, and `When to Use` sections.
- `make guidance-check` reports missing index/taxonomy entries, forbidden `.claude-plugin`, and unexpected nested `agents`/`skills` paths.
- Existing macOS guidance already owns native settings, AppKit bridging, previews, and lifecycle. Do not create a second general UI skill.

## Commands you will need

| Purpose | Command | Expected result |
|---|---|---|
| Guidance validation | `make guidance-check` | exit 0 |
| Reference scan | `rg -n "swiftui-pro|Swift 6\.2|macOS 26|macOS 27|Observable|strict concurrency" AGENTS.md .agents` | only intentional canonical references remain |
| Diff hygiene | `git diff --check` | exit 0 |

## Scope

**In scope**:

- `AGENTS.md`
- `.agents/SKILLS_INDEX.md`
- `.agents/SKILLS_TAXONOMY.md`
- `.agents/docs/skill-routing.md`
- `.agents/skills/swiftui-pro/SKILL.md`
- `.agents/skills/swiftui-pro/references/` only when needed to adapt macOS terminology
- `.agents/skills/swiftui-pro/.claude-plugin/`, `agents/`, and duplicated `skills/` bundle paths, if required by the validator
- `plans/README.md`

**Out of scope**:

- All Swift source, tests, localization, Xcode project settings, Package.swift, Makefile, and scripts.
- Deleting or merging `macos-app-engineering`, `accessibility-audit`, `swift-concurrency-expert`, `swift-conventions`, or `thermo-nuclear-code-quality-review`.
- Treating macOS 27 preview APIs as stable project requirements.

## Steps

### Step 1: Normalize skill structure and ownership

Make the root `swiftui-pro` skill conform to Prisma's required skill schema. Keep one canonical skill entry, remove only duplicate plugin-package material rejected by `make guidance-check`, and register the skill in both indexes. Route ordinary macOS UI implementation through `macos-app-engineering`; use `swiftui-pro` for focused SwiftUI review and `swift-concurrency-expert` for concurrency remediation.

**Verify**: `make guidance-check` -> exit 0 or report the exact remaining validator mismatch.

### Step 2: Define the project platform policy

Update guidance with these rules:

- minimum deployment target remains macOS 15 unless a product decision changes it;
- Swift language mode target is Swift 6.2 or later;
- macOS 26 APIs require `#available` guards;
- macOS 27 APIs remain preview-only until the SDK is released;
- new UI state prefers `@Observable`, `@State`, `@Bindable`, and `@Environment`;
- new code avoids `DispatchQueue` for async coordination, uses `Task.sleep(for:)`, and requires justification for `Task.detached`;
- AppKit remains allowed for status items, panels, lifecycle, and capabilities SwiftUI cannot express.

**Verify**: `rg -n "Swift 5\.9|Swift 6\.0|Swift 6\.2|macOS 27|DispatchQueue|Task\.detached" AGENTS.md .agents` -> the new policy is unambiguous and no conflicting owner remains.

### Step 3: Record review and completion evidence

Run the guidance validator and diff check. Update the ledger row. No code review is required because this plan changes only documentation, skill metadata, and governance files.

**Verify**: `make guidance-check && git diff --check` -> both exit 0.

## Done criteria

- [ ] `swiftui-pro` is present exactly once in the canonical skill index and taxonomy.
- [ ] `make guidance-check` exits 0.
- [ ] The project policy names macOS 15, macOS 26 availability, macOS 27 preview status, and Swift 6.2+ explicitly.
- [ ] The skill's iOS-specific wording is scoped so it does not override macOS project conventions.
- [ ] No Swift source, test, build, or runtime files changed.
- [ ] `plans/README.md` status row updated.

## STOP conditions

- The validator requires a skill layout that cannot be represented without changing source or build files.
- The proposed policy would require raising the minimum macOS target to 26 without an explicit product decision.
- Any existing skill ownership becomes ambiguous; stop and document the conflict instead of creating another broad UI skill.

## Maintenance notes

This plan is the documentation prerequisite for Plan 039. Future API additions should update the canonical owner skill and the routing/index files in the same change, then run `make guidance-check`.
