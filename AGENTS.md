# AGENTS.md - Meeting Assistant Development Guide

This file provides the primary operational standards for all AI agents and developers.

## 🚨 MANDATORY: Task Initialization & Lifecycle

Every coding task MUST follow the **Worktree-First** workflow to ensure environment isolation and repository integrity. **This is the first step of any interaction involving code changes.**

1. **New Branch**: Create a new branch based on `main`.
2. **Setup Worktree**: Create a new Git Worktree for the task.
3. **Execution**: Implement all changes and verification in the isolated worktree directory.
4. **Cleanup**: Merge back to `main` and delete the worktree.

For detailed steps and commands, see the **[task-lifecycle](.agents/skills/task-lifecycle/SKILL.md)** skill.

---

## 🏗 Project Architecture

The project uses a **Skill-Based Architecture**. All logic and patterns are documented in tool-agnostic skills.

## 🖥 Platform Target

- Minimum supported version: **macOS 14**
- UI approach: **SwiftUI-first**, with **AppKit** where needed (menu bar `NSStatusItem`, non-activating overlays, etc.).

## 🎛 Design System (UI)

We use a lightweight, SwiftUI-first Design System to keep UI consistent and DRY:

- **Tokens**: `Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/DesignSystem/MeetingAssistantDesignSystem.swift`
- **Components**: `Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/DesignSystem/Components/`

### Rules of thumb

- Prefer semantic colors (`.primary`, `.secondary`, materials) and DS tokens over hardcoded `Color(...)`.
- Prefer DS spacing/radius constants over magic numbers.
- Prefer DS components (cards, groups, callouts) over ad-hoc styling.
- UI strings must be localized via `"key".localized` (never hardcode user-facing strings).

### Public components (v1)

- `MACard`, `MAGroup`, `MAToggleRow`, `MACallout`, `MABadge`, `MAActionButton`, `MAThemePicker`
- Use `MA*` components directly in Settings (legacy `Settings*` aliases were removed).

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

To ensure workspace isolation and maintain a clean `main` branch, all file modifications MUST follow this workflow:

1. **Initialize Task**: Create a new branch and Git Worktree.

   ```bash
   git worktree add -b <branch-name> ../<branch-name> main
   ```

2. **Implement**: Perform all changes within the new worktree folder.
3. **Verify**: Run `make test` and `make build` in the worktree.
4. **Finalize**:
   - Merge to `main`.
   - Cleanup: `rm -rf ../<branch-name> && git worktree prune`.
   - Delete branch: `git branch -D <branch-name>`.

For detailed instructions, see the **[git-workflow skill](.agent/skills/git-workflow/SKILL.md)** and **[git-worktree skill](.agent/skills/git-worktree/SKILL.md)**.

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
| [localization](.agent/skills/localization/) | Bundle.safeModule, String.localized, accessibility |
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

## Localization (L10n)

- All UI keys live in `Packages/MeetingAssistantCore/.../Resources/*/Localizable.strings`.
- Use `"some.key".localized` or `"some.key".localized(with: args...)` everywhere.
- Never call `NSLocalizedString(...)` directly in feature code (only inside the shared helpers).
- Never depend on `.main` / `.module` bundles for UI strings; the helpers resolve the correct bundle via `Bundle.safeModule`.

## Project Structure

- `App/` — Main app target (entry point, Info.plist, entitlements)
- `Packages/MeetingAssistantCore/` — Core library with Models, Services, ViewModels, Views, Tests
- `docs/` — Documentation including ARCHITECTURE.md and BEST_PRACTICES.md
- `.agent/rules/` — Always-on rules for agents
- `.agent/skills/` — Conditional skills for specific contexts
