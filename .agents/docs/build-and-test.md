# Build and Test Reference

This document provides comprehensive CLI and workflow reference for building, testing, and validating changes in Prisma.

## Primary Build/Test Commands

### Quick start
```bash
make setup
make build
```

### Core workflow commands
```bash
make build              # Debug build
make test               # Run all tests
make preflight          # Build + Test + Lint + Benchmark (full validation)
make preflight-fast     # Lint + Build + Test (skips benchmark, faster feedback)
make run                # Run app in debug mode
make format             # Auto-format with SwiftFormat
make lint               # Run SwiftLint checks
```

### Release and distribution
```bash
make build-release      # Optimized release build
make dmg                # Create DMG installer
```

### Agent-optimized commands (compact output, better for CI/agents)
```bash
make build-agent        # Debug build with agent-friendly diagnostics
make test-agent         # Tests with machine-readable output
make lint-agent         # Lint with compact reporting
make preflight-agent    # Full validation (agent-optimized)
make preflight-agent-fast # Fast validation (agent-optimized)
```

## Preflight Execution Order Policy

**Default (full verification):**
```
build → test → lint → summary-benchmark
```

**With strict linting:**
```bash
STRICT_LINT=1 make preflight
# Order: build → lint(strict) → test → summary-benchmark
```

**Fast mode (local feedback only):**
```bash
make preflight-fast         # lint → build → test (skips benchmark)
make preflight-agent-fast   # Agent-optimized fast mode
```

## Direct xcodebuild (when needed)

Use `xcodebuild-safe.sh` to avoid SwiftPM transitive-module resolution instability:

```bash
./scripts/xcodebuild-safe.sh
# Equivalent explicit form:
# xcodebuild -project MeetingAssistant.xcodeproj \
#   -scheme MeetingAssistant \
#   -configuration Debug \
#   -destination 'platform=macOS' build
```

**⛔ NEVER** use bare `xcodebuild build` in this repo.

## Test Workflows

### Run all tests
```bash
make test
make test-agent          # Agent-focused, compact output
make test-verbose        # Detailed output
```

### Run specific tests
```bash
./scripts/run-tests.sh --file RecordingViewModelTests
./scripts/run-tests.sh --test testInitialState
./scripts/run-tests.sh --verbose
./scripts/run-tests.sh --agent
```

### CI-style local checks
```bash
make ci-test             # XCTest output compatible with CI systems
make ci-build            # Includes arch-check
```

## Linting and Formatting

### Check without fixing
```bash
make lint                # SwiftLint check
./scripts/lint.sh        # Direct lint script
```

### Auto-fix
```bash
make format              # SwiftFormat with auto-fix
./scripts/lint-fix.sh    # Combined lint + format fixes
```

### Specialized checks
```bash
make arch-check          # Architecture boundary/access-control validation
make preview-check       # SwiftUI preview coverage validation
```

## Agent Artifacts and Logging

Agents automatically capture build/test output and diagnostics.

**Log directory:**
- Default: `/tmp/ma-agent/`
- Override: `MA_AGENT_LOG_DIR=/custom/path make build-agent`

**Log contents** (deterministic summary lines):
- `AGENT_STEP` — task milestone
- `AGENT_STATUS` — pass/fail status
- `AGENT_DURATION_SEC` — execution time
- `AGENT_LOG` — path to full log file
- `AGENT_ERROR_COUNT` — number of errors
- `AGENT_SUMMARY` — human-readable summary
- `AGENT_RESULT_JSON` — structured result

On failure, scripts print compact excerpts to terminal while keeping full logs on disk.

## Minimum Verification Gates

**Before push/merge (mandatory):**
- ✓ `make test` — all tests pass
- ✓ `make build` — debug build succeeds

**Recommended before merge:**
- ✓ `make preflight` — full validation
- ✓ `make lint` — code quality checks (mandatory for broad refactors)

**Pre-release:**
- ✓ `make preflight` + full validation
- ✓ `make build-release` + DMG creation
- ✓ Manual smoke test on target macOS versions

## Common Workflows

| Goal | Command |
|------|---------|
| Local development loop | `make build && make run` |
| Before committing | `make test && make lint` |
| Pre-merge validation | `make preflight` |
| Fast local feedback | `make preflight-fast` |
| Agent-based pre-merge | `make preflight-agent` |
| Release preparation | `make lint && make test && make build-release && make dmg` |
| CI-style check | `make ci-build` |
| Profile performance | `make profile-report` |

## Troubleshooting

**"unstable SwiftPM transitive-module resolution" errors:**
- Use `./scripts/xcodebuild-safe.sh` instead of bare `xcodebuild build`
- Clear build cache: `rm -rf build/`

**Tests fail intermittently:**
- Run tests in isolation: `./scripts/run-tests.sh --file SpecificTestFile`
- Check for concurrency/timing issues in test code

**Linter or formatter issues:**
- Verify `.swiftlint.yml` and `.swiftformat` exist and are valid
- Run `make lint-fix` to auto-correct most issues

## References

- SwiftLint config: `.swiftlint.yml`
- SwiftFormat config: `.swiftformat`
- Build scripts: `scripts/` (e.g., `build-release.sh`, `preflight.sh`)
- Makefile targets: `Makefile` (root)
