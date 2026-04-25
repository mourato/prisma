---
name: swift-package-manager
description: This skill should be used when the user asks to "edit Package.swift", "manage SPM dependencies", "fix package resolution", or "troubleshoot Swift Package Manager".
---

# Dependency Management (SPM)

## Role

Use this skill as the canonical owner for Swift Package Manager guidance in Prisma.

- Own `Package.swift`, package dependency policy, and package-resolution troubleshooting guidance.
- Keep package guidance aligned with the checked-in Xcode project/workspace workflow.
- Delegate broader macOS implementation concerns to the platform owner.

## Scope Boundary

- Use this skill for package declarations, dependency updates, lock files, and Swift Package commands.
- Use `../macos-development/SKILL.md` for platform implementation guidance outside package management.

## Overview

Guidelines for using Swift Package Manager to manage internal and external codebase dependencies.

## 1. Philosophy

- **Minimize Dependencies**: Each external package adds maintenance risk and build time. Audit carefully before adding.
- **Standard Tool**: Use SPM as the exclusive dependency manager for the project.

## 2. Versioning

- **Explicit Versions**: Avoid using wildcard versions or branches. Use semantic versioning requirements like `.upToNextMajor`.
- **Auditing**: Periodically check for dependency updates and security vulnerabilities.

## 3. Local Packages

- **Modularity**: Break down core logic into local SPM packages (e.g., `MeetingAssistantCore`) to improve build times and separation of concerns.
- **Search Paths**: Ensure local package references in `Package.swift` are relative and correctly managed.

## When to Use

Activate this skill when working with:
- `Package.swift` configuration
- Package dependency declarations
- `swift package` commands
- `Package.resolved` lock file
- SPM dependency updates

## Key Concepts

### Dependency Management

Configure dependencies in `Package.swift`:

```swift
// Package.swift
let package = Package(
    name: "MeetingAssistantCore",
    platforms: [
        .macOS(.v12),
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "MeetingAssistantCore",
            targets: ["MeetingAssistantCore"]
        )
    ],
    dependencies: [
        // Fixed version for stability
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        
        // Branch for internal development
        .package(url: "https://github.com/team/internal-utils.git", branch: "main"),
        
        // Specific revision for reproducibility
        .package(url: "https://github.com/alice/ocr.git", revision: "abc123def")
    ],
    targets: [
        .target(
            name: "MeetingAssistantCore",
            dependencies: [
                .product(name: "Logging", package: "swift-log")
            ]
        )
    ]
)
```

### Reproducible Builds

Commit `Package.resolved` for reproducible builds:

```bash
# Lock dependencies to specific versions
git add Package.resolved
git commit -m "deps: lock swift-log to 1.4.2"
```

---

## Xcode Integration

This repository uses Swift Package Manager for package structure, but the app is developed and built through the checked-in root Xcode project and workspace.

- Use `MeetingAssistant.xcodeproj` / `MeetingAssistant.xcworkspace` for app navigation, debugging, and previews.
- Treat `Package.swift` as the source of truth for package targets and dependencies.
- Do not document or rely on `swift package generate-xcodeproj` or any generated Xcode-project workflow in this repository.

---

## Useful Commands

```bash
# Check dependencies
swift package show-dependencies

# Update to latest versions
swift package update

# Clean build cache
swift package clean

# Resolve dependencies
swift package resolve
```

## References

- [Package.swift](Packages/MeetingAssistantCore/Package.swift)
- [Swift Package Manager Documentation](https://developer.apple.com/documentation/swift_packages)

## Related Skills

- `../macos-development/SKILL.md`

