---
name: quality-assurance
description: This skill should be used when writing unit tests, mocking dependencies, or verifying task completeness with automated checks.
---

# Quality Assurance Standards

## Overview

Requirements for maintaining high stability and confidence through rigorous testing and verification.

## External Quality Gates

Codacy integration is not used in this repository. Rely on local tooling and CI
checks for quality gates.
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
