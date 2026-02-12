---
name: quality-assurance
description: This skill should be used when writing unit tests, mocking dependencies, or verifying task completeness with automated checks.
---

# Quality Assurance Standards

## Overview

This skill defines verification practices that keep quality high while preserving development speed.

Core policy alignment:

- Use the risk matrix and Fast/Full lanes from `AGENTS.md`.
- Keep hard gates at push/merge, not on every local edit.
- Codacy is deprecated in this repository; rely on local scripts and CI.

## Verification by Lane

### Fast lane (Low risk)

Use for docs/comments-only updates, localization/resource text updates, and constrained non-functional refactors.

Minimum expectation:

- Run staged lint/format checks (or equivalent lightweight checks).
- Run targeted tests when the change could affect behavior.
- Before push/merge, run `make test`.

### Full lane (Medium/High risk)

Use for behavior changes, API changes, subsystem changes, concurrency/security/persistence/audio, and large/cross-module deltas.

Minimum expectation:

- During development, run relevant targeted checks continuously.
- Before push/merge (hard gate):
  - `make build`
  - `make test`
  - `make lint` (recommended; mandatory for broad refactors)

## Scope-driven additional checks

Run these only when relevant to the changed scope:

- `make arch-check` for architecture boundary/access-control/import-rule changes.
- `make preview-check` when adding/changing SwiftUI views.
- `make test-verbose` or targeted `./scripts/run-tests.sh ...` commands when debugging flaky or scope-specific tests.

## Practical command set

```bash
# Core
make build
make test
make lint

# Optional, scope-based
make arch-check
make preview-check

# Targeted test workflows
./scripts/run-tests.sh --file <TestFile>
./scripts/run-tests.sh --test <testName>
./scripts/run-tests.sh --verbose
```

## Hooks and automation

- Install Git hooks with `./scripts/setup-hooks.sh`.
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
