---
name: macos-development
description: Build professional native macOS apps in Swift with SwiftUI and AppKit. Applies modern Swift 6+ best practices, concurrency patterns, and full lifecycle management (build, debug, test, optimize, ship). CLI-only workflow.
---

<essential_principles>
## How We Work

**The user is the product owner. Claude is the developer.**

The user does not write code. The user does not read code. The user describes what they want and judges whether the result is acceptable. Claude implements, verifies, and reports outcomes.

### 1. Prove, Don't Promise
Never say "this should work." Prove it:
```bash
xcodebuild build 2>&1 | xcsift  # Build passes
xcodebuild test                  # Tests pass
open .../App.app                 # App launches
```

### 2. Tests for Correctness, Eyes for Quality
| Question | How to Answer |
|----------|---------------|
| Does the logic work? | Write test, see it pass |
| Does it look right? | Launch app, user looks at it |
| Does it feel right? | User uses it |
| Does it crash? | Test + launch |
| Is it fast enough? | Profiler |

### 3. Report Outcomes, Not Code
**Bad:** "I refactored DataService to use async/await with weak self capture"
**Good:** "Fixed the memory leak. `leaks` now shows 0 leaks. App tested stable for 5 minutes."

### 4. Small Steps, Always Verified
```
Change → Verify → Report → Next change
```
Each change is verified before the next.

### 5. Swift 6 Concurrency First
- Actors protect mutable shared state.
- `@MainActor` for UI-related code.
- Check task cancellation in long-running operations.
- Avoid `DispatchSemaphore` with async/await.
</essential_principles>

<core_guidelines>
## Swift Best Practices

### Fundamental Principles
1. **Clarity at point of use** is paramount.
2. **Clarity over brevity**.
3. **Name by role, not type**.
4. **Async ≠ background** - explicitly move work to background if needed.

### Essential Patterns
#### Async/Await
```swift
func fetchData() async -> (String, Int) {
    async let stringData = fetchString()
    async let intData = fetchInt()
    return await (stringData, intData)
}
```

#### MainActor for UI
```swift
@MainActor
class ContentViewModel: ObservableObject {
    @Published var images: [UIImage] = []
    func fetchData() async throws {
        self.images = try await fetchImages()
    }
}
```
</core_guidelines>

<intake>
**Ask the user:**
What would you like to do?
1. Build a new app
2. Debug an existing app
3. Add a feature
4. Write/run tests
5. Optimize performance
6. Ship/release
7. Something else
</intake>

<routing>
| Response | Workflow |
|----------|----------|
| 1, "new", "create", "build", "start" | `workflows/build-new-app.md` |
| 2, "broken", "fix", "debug", "crash", "bug" | `workflows/debug-app.md` |
| 3, "add", "feature", "implement", "change" | `workflows/add-feature.md` |
| 4, "test", "tests", "TDD", "coverage" | `workflows/write-tests.md` |
| 5, "slow", "optimize", "performance", "fast" | `workflows/optimize-performance.md` |
| 6, "ship", "release", "notarize", "App Store" | `workflows/ship-app.md` |
</routing>

<verification_loop>
## After Every Change
```bash
# 1. Does it build?
xcodebuild -scheme AppName build 2>&1 | xcsift

# 2. Do tests pass?
xcodebuild -scheme AppName test

# 3. Does it launch? (if UI changed)
open ./build/Build/Products/Debug/AppName.app
```
</verification_loop>

<related_skills>
## Related Skills

For domain-specific guidance, see:
- **[swiftui-patterns](../swiftui-patterns/SKILL.md)** - SwiftUI state management and view patterns
- **[menubar](../menubar/SKILL.md)** - NSStatusItem and menu bar app patterns
- **[audio-realtime](../audio-realtime/SKILL.md)** - Real-time audio processing constraints
- **[localization](../localization/SKILL.md)** - i18n and accessibility patterns
- **[swift-package-manager](../swift-package-manager/SKILL.md)** - SPM and Xcode project generation
</related_skills>

<reference_index>
## Domain Knowledge (in `references/`)
**Architecture:** app-architecture, swiftui-patterns, concurrency
**Swift:** swift6-features, api-design, availability-patterns
**System:** system-apis, app-extensions, data-persistence, networking
**Development:** project-scaffolding, cli-workflow, testing-tdd, testing-debugging
**Polish:** design-system, macos-polish, security-code-signing
</reference_index>

