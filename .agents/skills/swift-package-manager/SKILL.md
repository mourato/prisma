---
name: swift-package-manager
description: Dependency management using Swift Package Manager (SPM). Covers package definition, dependency versioning, and local package maintenance. Use when managing external libraries.
---

# Dependency Management (SPM)

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
- `make spm-proj` Xcode project generation
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

## Xcode Project Generation

> **Motivation**: For developers without prior Swift experience, using an `.xcodeproj` file is the most visual and friendly way to navigate code, run the application, and use visual tools like SwiftUI Previews.

### Why Generate Xcode Project?

This project uses **Swift Package Manager (SPM)** as the source of truth. Folder structure and dependencies are defined in `Package.swift`.

For day-to-day development, we generate a disposable `.xcodeproj` file. This allows:
1. Visual file navigation
2. Auto-complete and visual refactoring
3. **SwiftUI Previews** usage (visual hot reload)
4. Visual debugging with breakpoints

### How to Generate the Project

Whenever you add files or change dependencies:

```bash
make spm-proj
```

This will create (or update) the file `Packages/MeetingAssistantCore/MeetingAssistantCore.xcodeproj`.

### How to Open and Use

1. After generating, open the project:
   ```bash
   open Packages/MeetingAssistantCore/MeetingAssistantCore.xcodeproj
   ```

2. **To Run Previews (Hot Reload)**:
   - Open any View file (e.g., `MeetingView.swift`)
   - On the right side, you'll see the "Canvas"
   - If paused, click the "Refresh" icon or press `Cmd + Option + P`
   - Any code changes reflect almost instantly in the Preview

### Troubleshooting

**Project doesn't compile after generation:**
- Try cleaning the build: `Product > Clean Build Folder` (Cmd + Shift + K)
- If it persists, delete the generated project and regenerate:
  ```bash
  rm -rf Packages/MeetingAssistantCore/MeetingAssistantCore.xcodeproj
  make spm-proj
  ```

**Previews don't work:**
- Make sure you're running on simulator or Mac (Designed for iPad)
- Verify the correct scheme is selected
- Try closing and reopening the Canvas

---

## Useful Commands

```bash
# Check dependencies
swift package show-dependencies

# Update to latest versions
swift package update

# Generate Xcode project
swift package generate-xcodeproj

# Clean build cache
swift package clean

# Resolve dependencies
swift package resolve
```

## References

- [Package.swift](Packages/MeetingAssistantCore/Package.swift)
- [Swift Package Manager Documentation](https://developer.apple.com/documentation/swift_packages)

