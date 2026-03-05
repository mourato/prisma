---
name: quality-assurance
description: This skill should be used when the user asks to "write tests", "create mocks", "define verification gates", or "run quality checks before merge".
---

# Quality Assurance Standards

## Overview

This skill defines verification practices that keep quality high while preserving development speed.

Core policy alignment:

- Use the risk matrix and Fast/Full lanes from `AGENTS.md`.
- Keep hard gates at push/merge, not on every local edit.
- When running checks via AI agents, prefer compact `*-agent` targets to reduce context volume while preserving failure diagnostics.

## Verification by Lane

### Fast lane (Low risk)

Use for docs/comments-only updates, localization/resource text updates, and constrained non-functional refactors.

Minimum expectation:

- Run staged lint/format checks (or equivalent lightweight checks).
- Run targeted tests when the change could affect behavior.
- Before push/merge, run `make test-agent`.

### Full lane (Medium/High risk)

Use for behavior changes, API changes, subsystem changes, concurrency/security/persistence/audio, and large/cross-module deltas.

Minimum expectation:

- During development, run relevant targeted checks continuously.
- Before push/merge (hard gate):
  - `make build-test`
  - `make lint` (recommended; mandatory for broad refactors)

## Scope-driven additional checks

Run these only when relevant to the changed scope:

- `make arch-check` for architecture boundary/access-control/import-rule changes.
- `make preview-check` when adding/changing SwiftUI views.
- `make test-verbose` or targeted `./scripts/run-tests.sh ...` commands when debugging flaky or scope-specific tests.

## Practical command set

```bash
# Core
make build-test
make lint
make preflight

# Isolated diagnostics
make build-agent
make test-agent

# Optional local parity diagnostics
make build
make test

# Optional, scope-based
make arch-check
make preview-check

# Compact AI-agent mode (machine-readable summary + log artifacts)
make build-test
make lint-agent
make preflight-agent

# Isolated diagnostics
make build-agent
make test-agent

# Targeted test workflows
./scripts/run-tests.sh --file <TestFile>
./scripts/run-tests.sh --test <testName>
./scripts/run-tests.sh --verbose
./scripts/run-tests.sh --agent
```

Compact-mode notes:

- Full logs are written under `${MA_AGENT_LOG_DIR:-/tmp/ma-agent}`.
- Scripts emit deterministic `AGENT_*` summary lines for pass/fail parsing.
- Use compact mode for iteration; keep `make build-test` as merge gate for Medium/High tasks.

## Hooks and automation

- Install Git hooks with:
  - `git config core.hooksPath scripts/hooks`
  - `chmod +x scripts/hooks/pre-commit scripts/hooks/pre-push scripts/hooks/first-commit-version-bump.sh`
  - `find scripts/hooks -maxdepth 1 -type f ! -perm -u+x -print` (must print nothing).
- `pre-commit` is optimized for speed and can run lightweight staged checks.
- `pre-push` enforces `make test` unless explicitly bypassed.

Emergency bypasses should be rare and followed by immediate remediation.

## Troubleshooting

### Tool missing

```bash
brew install swiftlint swiftformat
```

### Hook failures

- Read the hook output and run the suggested fix command.
- Re-run the failed check locally until green.

### Build/Test mismatch

- Prefer `make test` for Xcode parity.
- Use targeted tests to isolate issues before running full suite again.

## References

- `AGENTS.md`
- `Makefile`
- `scripts/lint.sh`
- `scripts/run-tests.sh`

## 2026-03 Policy Alignment Update

### Canonical Merge Gates (AGENTS.md)

Use AGENTS.md as source of truth for lane gates:

- Fast lane (Low risk): `make test-agent`
- Full lane (Medium/High risk): `make build-test`
- `make lint`: mandatory for broad refactors

When legacy hooks or scripts still run `make test`, treat it as an additional local guard, not a replacement for the canonical lane gate above.

### Regression Matrix Priority

For recurring bug classes in this repository, require targeted checks in addition to lane gates:

1. Audio device matrix (internal, shared I/O, USB mic).
2. Global shortcut registration/capture across lifecycle transitions.
3. Onboarding/settings transitions with localization-aware UI states.
4. Migration/retention behavior for persisted data continuity.

## 2026-03-04 Progression Drill

### New Evidence

- Release workflow changed multiple times on 2026-03-03 (`sparkle-release.yml` touched repeatedly).
- Audio sendability fixes and shortcut behavior updates happened in the same window.

### Skill Deepening Focus

1. Keep Fast lane gate as `make test-agent` (not `make test`) for low-risk changes.
2. Add a targeted release-workflow smoke checklist for CI-only paths (gate command parity + artifacts).
3. Expand regression matrix templates to include:
   - Audio sendability-sensitive paths
   - Shortcut Enter/Return behavior across focus states
   - Meeting-QA persistence round trips
4. Record failed-check signatures in PR notes to improve repeated triage speed.

## 2026-03-05 Progression Drill

### New Evidence

- `efe08a7` added local release parity gate + strict Xcode test hardening.
- `ffb3bd5` switched strict Xcode test mode to default.
- `be3e56f`, `44db00e`, and `f3d928f` show repeated release regressions caught only after CI/publish flow execution.

### Skill Deepening Focus

1. Add a CI-release smoke template that always runs `scripts/ci-release-parity.sh` for release-workflow edits.
2. Require explicit reporting of strict-test mode used (`scripts/run-tests-xcode.sh` default strict) in validation notes.
3. For `.github/workflows/sparkle-release.yml` changes, treat validation as Full-lane even if code delta is small.
4. Standardize failure reporting format: failing command, failing stage, and first actionable mismatch.
