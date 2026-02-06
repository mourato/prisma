# AGENTS.md - Meeting Assistant Development Guide

This file provides the primary operational standards for all AI agents and developers.

## 🚨 MANDATORY: Task Initialization & Lifecycle

Every coding task MUST follow the **Worktree-First** workflow to ensure environment isolation and repository integrity. **This is the first step of any interaction involving code changes.**

1. **New Branch**: Create a new branch based on `main`.
2. **Setup Worktree**: Create a new Git Worktree for the task.
3. **Execution**: Implement all changes and verification in the isolated worktree directory.
4. **Cleanup**: Merge back to `main` and delete the worktree.

For detailed steps and commands, see the **[task-lifecycle](.agents/skills/task-lifecycle/SKILL.md)** skill.

## ✅ Standard Task SOP (Mandatory)

This is the **single, standardized** flow for every task in this repository:

1. **Create branch + worktree** (never work directly on `main`):
   - `git worktree add -b <branch-name> ../<folder-name> main`
   - `cd ../<folder-name>`
2. **Implement in small slices**.
3. **Verification gate (before ANY commit)**:
   - `make build`
   - `make test`
   - (recommended) `make lint`
   - If anything fails: stop and fix until green.
4. **Atomic commits (green state)**:
   - Split commits by intent (feature vs refactor vs tests vs cleanup).
   - Every commit must compile and test.
   - Use Conventional Commits (see `.agents/skills/git-workflow/SKILL.md`).
5. **Local code review ritual (before final push/merge)**:
   - Follow `.agents/skills/code-review/SKILL.md` and generate the 🔴/🟡/🟢 report.
   - Fix **🔴 Critical** and **🟡 Medium** findings (🟢 optional).
6. **Re-verify + atomic commits for review fixes**:
   - `make build && make test` (and `make lint` when applicable).
7. **Push / merge** the task branch into `main`.
8. **Cleanup**:
   - Remove worktree + prune.
   - Delete the branch locally and remotely (if pushed).

---

## 🏗 Project Architecture

The project uses a **Skill-Based Architecture**. All logic and patterns are documented in tool-agnostic skills.

## Build Commands

```bash
# Build Debug (CLI-first)
make build

# Build and run Debug version
make run

# Build Release from command line
make build-release

# Create DMG installer
make dmg

# Full development workflow
make setup    # Install dependencies
make lint     # Check code quality
make test     # Run tests
make build    # Build app
make run      # Launch app
```

### CLI-First Workflow

This project uses a CLI-first development approach with xcodebuild. While Xcode IDE is still supported for debugging and UI design, all builds, tests, and releases are performed via command line for consistency and CI/CD compatibility.

**Quick Start:**

```bash
make setup    # One-time setup
make          # Build and verify (default: debug build)
```

**Common Workflows:**

- **Development:** `make build && make run`
- **Testing:** `make test`
- **Release:** `make lint && make test && make build-release && make dmg`
- **CI/CD:** `make ci-build`

## Lint & Format Commands

```bash
# Run linting only
./scripts/lint.sh

# Auto-fix lint and formatting issues
./scripts/lint-fix.sh

# Requirements: SwiftLint and SwiftFormat must be installed
brew install swiftlint swiftformat
```

## Testing

```bash
# Build and run all tests
make test

# Run tests with verbose output
make test-verbose

# Run a single test file
./scripts/run-tests.sh --file RecordingViewModelTests

# Run a specific test
./scripts/run-tests.sh --test testInitialState

# Run tests with verbose output
./scripts/run-tests.sh --verbose

# CI test run (no user interaction)
make ci-test
```

## Worktree-First Development (Mandatory)

To ensure workspace isolation and maintain a clean `main` branch, all file modifications MUST follow Worktree-first + green gates + atomic commits.

For the full standardized flow, follow the **Standard Task SOP** above and the skills:
- `.agents/skills/task-lifecycle/SKILL.md`
- `.agents/skills/git-workflow/SKILL.md`
- `.agents/skills/code-review/SKILL.md`
- `.agents/skills/git-worktree/SKILL.md`

|------|-------------|
| [architecture.md](.agent/rules/architecture.md) | MVVM or Clean Architecture patterns |
| [clean-code.md](.agent/rules/clean-code.md) | Code quality and function guidelines |
| [concurrency.md](.agent/rules/concurrency.md) | Async/await, actors, and thread safety |
| [data-persistency.md](.agent/rules/data-persistency.md) | Data storage strategies |
| [error-handling.md](.agent/rules/error-handling.md) | Error propagation and logging |
| [external-dependencies.md](.agent/rules/external-dependencies.md) | Dependency management |
| [known-limitations.md](.agent/rules/known-limitations.md) | Documentation requirements |
| [lifecycle-and-memory.md](.agent/rules/lifecycle-and-memory.md) | Memory management |
| [network.md](.agent/rules/network.md) | URLSession and API patterns |
| [performance.md](.agent/rules/performance.md) | Optimization guidelines |
| [security.md](.agent/rules/security.md) | Security best practices |
| [swift-style.md](.agent/rules/swift-style.md) | Code style conventions |
| [testing.md](.agent/rules/testing.md) | Testing guidelines |
| [type-security.md](.agent/rules/type-security.md) | Type safety patterns |

## Skills Index (Conditional)

Skills are loaded when specific contexts are detected. See `.agent/skills/` for full guides.

| Skill | Trigger |
|-------|---------|
| [audio-realtime](.agent/skills/audio-realtime/) | AVAudioSourceNode, AudioRecorder, ProcessTap |
| [debugging-strategies](.agent/skills/debugging-strategies/) | bugs, crash, performance issue |
| [documentation](.agent/skills/documentation/) | DocC comments, API documentation |
| [git-advanced-workflows](.agent/skills/git-advanced-workflows/) | rebase, bisect, cherry-pick |
| [git-workflow](.agent/skills/git-workflow/) | git commit, branches, PRs |
| [keychain-security](.agent/skills/keychain-security/) | KeychainManager, KeychainProvider, storeSecret |
| [localization](.agent/skills/localization/) | Bundle.module, NSLocalizedString, accessibility |
| [menubar](.agent/skills/menubar/) | NSStatusItem, NSMenu, NSPopover |
| [skill-development](.agent/skills/skill-development/) | create skill, develop plugin |
| [skills-discovery](.agent/skills/skills-discovery/) | search skills, registry |
| [swift-package-manager](.agent/skills/swift-package-manager/) | Package.swift, SPM dependencies |
| [swiftui-patterns](.agent/skills/swiftui-patterns/) | SwiftUI views, @State, NavigationStack |
| [testing-xctest](.agent/skills/testing-xctest/) | XCTest, @Test, mock, XCTAssert |

## Code Style Summary

### Naming

- Variables/functions: `lowerCamelCase`
- Types: `UpperCamelCase`
- Constants: `kConstantName` or `lowerCamelCase` for local
- Avoid abbreviations except: `id`, `ui`, `ai`, `ok`, `at`, `to`

### Imports

- Order alphabetically (e.g., `CoreML, Foundation, OSLog`)
- Group framework imports before local imports

### Formatting (SwiftFormat)

- 4 spaces indentation
- K&R braces (else on same line)
- Always use trailing commas
- Use `Void` instead of `()`
- Insert explicit `self`
- Semicolons inline
- Wrap arguments before first element

## Project Structure

- `App/` — Main app target (entry point, Info.plist, entitlements)
- `Packages/MeetingAssistantCore/` — Core library with Models, Services, ViewModels, Views, Tests
- `docs/` — Documentation including ARCHITECTURE.md and BEST_PRACTICES.md
- `.agent/rules/` — Always-on rules for agents
- `.agent/skills/` — Conditional skills for specific contexts
