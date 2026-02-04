```
---
name: quality-assurance
description: This skill should be used when writing unit tests, mocking dependencies, or verifying task completeness with automated checks.
---

# Quality Assurance Standards

## Overview

Requirements for maintaining high stability and confidence through rigorous testing and verification.

## 1. Testing Methodology

- **Unit Isolation**: Isolate unit tests by mocking all external dependencies (Networking, Storage, Hardware).
- **Coverage**: Maintain high coverage for critical business logic in the Core and Domain layers.
- **Performance Baselines**: Use `XCTMetric` to measure and establish baselines for time-sensitive paths (e.g., audio buffer processing).

## 2. Mocking & Mocks

- **Protocol-First**: Design protocols for all services to allow for easy mocking.
- **Verification**: Use mocks to verify side effects and correct property interactions.
- **Reset**: Implement `reset()` methods on actors or managers to ensure isolation between tests.

## 3. Verification & CI

- **Build Pre-Check**: **MANDATORY**: Run `make build` and `make test` before any commit.
- **Automated Checks**: Ensure linting (`make lint`) passes without warnings.
- **Manual Verification**: Document manual verification steps in walkthroughs for UI-heavy or hardware-dependent features.

> **Conditional Skill** - Triggered when working with code quality tools

## Overview

This skill covers automated code quality enforcement through static analysis, formatting, and CI/CD integration to maintain consistency and prevent common errors.

## When to Use

Activate this skill when detecting:
- `SwiftLint`
- `SwiftFormat`
- `pre-commit` hooks
- `Danger` or `danger-swift`
- `.swiftlint.yml`
- `.swiftformat`
- Build phases for linting
- GitHub Actions quality checks

---

## Why Automation?

**Goal**: Remove cognitive load from code reviews by automating style discussions and common error detection.

**Benefits**:
1. **Consistency**: All code follows the same style
2. **Early Detection**: Catch errors before they reach PR
3. **Speed**: Reviewers focus on logic and architecture, not formatting
4. **Learning**: Developers learn best practices through automated feedback

---

## Linting & Formatting

### SwiftLint

**Purpose**: Static analysis and style rule enforcement.

**Configuration**: `.swiftlint.yml` at project root

```yaml
# Example configuration
disabled_rules:
  - trailing_whitespace
opt_in_rules:
  - empty_count
  - closure_spacing
excluded:
  - Pods
  - .build
line_length: 120
```

**Manual Check**:
```bash
swiftlint lint
```

**Auto-fix**:
```bash
swiftlint lint --fix
```

### SwiftFormat

**Purpose**: Automatic code formatting.

**Configuration**: `.swiftformat` at project root

```
--indent 4
--maxwidth 120
--wraparguments before-first
--wrapcollections before-first
```

**Manual Format**:
```bash
swiftformat .
```

**Check Only** (no changes):
```bash
swiftformat . --lint
```

---

## Pre-Commit Hooks

**Purpose**: Run quality checks automatically before code is committed.

### Setup

1. Install hooks script:
   ```bash
   ./scripts/setup-hooks.sh
   ```

2. Hooks will run automatically on `git commit`

3. **To bypass** (emergencies only):
   ```bash
   git commit --no-verify
   ```

### What Gets Checked

- SwiftLint errors
- SwiftFormat violations
- Build validity (optional)
- Test status (optional)

### Hook Script Example

```bash
#!/bin/sh
# .git/hooks/pre-commit

# Run SwiftLint
if which swiftlint >/dev/null; then
  swiftlint lint --strict
  if [ $? -ne 0 ]; then
    echo "SwiftLint failed. Fix errors before committing."
    exit 1
  fi
fi

# Run SwiftFormat check
if which swiftformat >/dev/null; then
  swiftformat . --lint
  if [ $? -ne 0 ]; then
    echo "SwiftFormat check failed. Run 'swiftformat .' to fix."
    exit 1
  fi
fi

exit 0
```

---

## Build Phases Integration

### Add Linting to Xcode Build

1. Open Xcode project
2. Select target → **Build Phases**
3. Add "Run Script Phase"
4. Add script:

```bash
if which swiftlint >/dev/null; then
  swiftlint
else
  echo "warning: SwiftLint not installed, download from https://github.com/realm/SwiftLint"
fi
```

**Important**: If build fails due to lint, **fix the code, don't remove the script**.

---

## Pull Request Checks (Danger Swift)

**Purpose**: Automated PR feedback on GitHub Actions.

### What Danger Checks

- PR size (warns if > 400 lines)
- PR description presence
- Compiler warnings
- Test results
- SwiftLint violations

### Configuration

**Dangerfile.swift**:
```swift
import Danger

let danger = Danger()

// Check PR size
if danger.github.pullRequest.additions > 400 {
    warn("PR has more than 400 additions. Consider splitting.")
}

// Check description
if danger.github.pullRequest.body?.isEmpty ?? true {
    fail("Please add a description to the PR.")
}

// Check for SwiftLint violations
SwiftLint.lint(inline: true)
```

### GitHub Actions Workflow

**.github/workflows/danger.yml**:
```yaml
name: Danger
on: [pull_request]

jobs:
  danger:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run Danger
        uses: danger/swift@3.0.0
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

---

## External Quality Gates

### Codacy

**Purpose**: Cloud-based code quality analysis for pull requests.

**Common Warnings**:
- Vertical alignment of function parameters
- Code complexity metrics
- Duplicate code detection
- Security vulnerabilities
- Code style inconsistencies

**Resolution Workflow**:
1. Check Codacy report in PR comments/checks
2. Address warnings locally with SwiftFormat/SwiftLint first
3. If Codacy-specific (not caught by local tools), adjust manually
4. Re-run CI to validate fixes

**Configuration**: 
- Codacy rules are managed via web dashboard at [codacy.com](https://www.codacy.com)
- Local `.codacy.yml` can override specific rules (if present in project)

**When to Override**: 
Codacy warnings can be ignored/suppressed if:
- Already handled by SwiftLint/SwiftFormat with different enforcement
- False positive (document reasoning in PR comment)
- Style choice justified by team consensus and documented

**Example Fix**:
```swift
// ❌ Codacy Warning: "Vertical alignment of parameters"
func processAudio(
  format: AVAudioFormat,
     sampleRate: Double,
  channels: Int
) { }

// ✅ Fixed: Consistent alignment
func processAudio(
    format: AVAudioFormat,
    sampleRate: Double,
    channels: Int
) { }
```

**Priority**: 
- 🔴 **Critical/Security**: Must fix before merge
- 🟡 **Code Quality**: Should fix unless justified
- 🔵 **Style**: Can be overridden with team consensus

---

## Setup for New Developers

When cloning the repository:

```bash
# Install tools
brew install swiftlint swiftformat

# Install pre-commit hooks
./scripts/setup-hooks.sh

# Verify installation
swiftlint version
swiftformat --version
```

---

## Common Workflows

### Before Commit

```bash
# Check locally
swiftlint lint
swiftformat . --lint

# Auto-fix if needed
swiftlint lint --fix
swiftformat .

# Then commit
git add .
git commit -m "feat: add feature"
```

### In CI/CD

```bash
# Fail build on warnings
swiftlint lint --strict

# Verify formatting
swiftformat . --lint
```

### Bypassing (Emergency Only)

```bash
# Skip pre-commit hooks
git commit --no-verify

# Disable SwiftLint for specific line
// swiftlint:disable:next force_cast
let value = json["key"] as! String
```

---

## Troubleshooting

### "SwiftLint not found"
```bash
brew install swiftlint
```

### "Pre-commit hook rejected"
- Read the error message carefully
- Run suggested fix command
- Verify with `swiftlint lint` before re-committing

### "Build fails in Xcode due to lint"
- Open **Build Log** to see specific violations
- Fix code issues
- **Never delete the build script**

---

## References

- [SwiftLint Documentation](https://github.com/realm/SwiftLint)
- [SwiftFormat Documentation](https://github.com/nicklockwood/SwiftFormat)
- [Danger Swift](https://danger.systems/swift/)
