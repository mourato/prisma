# Skill Routing Guide

When working on Meeting Assistant, multiple skills may be relevant to your task. This guide provides routing logic to select the most appropriate skill and reduce noise and instruction overlap.

## General Routing Priority

When uncertain which skill to use, apply this priority order:

1. **`build-macos-apps`** — Request intake and workflow routing (fast lane selector)
2. **`macos-development`** — Canonical macOS/Swift implementation guidance (go-to for platform-specific work)
3. **`native-app-designer`** — Primary UI/UX direction and experience design (consult first for any UI/UX work)
4. **`swift-concurrency-expert`** — Swift 6.2 concurrency/actor isolation (compiler errors, Sendable fixes)
5. **`swiftui-performance-audit`** — SwiftUI runtime performance diagnosis (janky scrolling, excessive updates)
6. **`swiftui-animation`** — Advanced animations/transitions (matched geometry, shaders)

**Note:** `build-macos-apps` acts as an orchestrator to select the right lane quickly, not as canonical technical reference. Prefer direct skill calls for implementation work.

## External Project Code Lookup Priority

When you need to inspect code from projects outside this repository, use this source order:

1. **`MCP grep`** - default source for code-centric GitHub lookup
2. **`gh` CLI** - issues/PRs/history and direct repository inspection
3. **`deepwiki`** - broad repository context
4. **Web search** - last resort only

---



## Problem-Specific Routing

### UI/UX and Interaction Work

**Start here:** `native-app-designer`
- Define visual/motion direction
- Set UX acceptance criteria
- Analyze interface quality

**Then (if needed):** `swiftui-patterns` → `swiftui-animation` → `swiftui-performance-audit`
- Implement view composition
- Add advanced animations
- Diagnose performance issues

**Example:** "Design the meeting recording UI" → `native-app-designer` for UX direction → `swiftui-patterns` for view implementation → `swiftui-performance-audit` if scrolling is slow

---

### SwiftUI Performance Issues

**Primary:** `swiftui-performance-audit`
- Janky scrolling, layout thrash, excessive view updates
- Animation hitches or jank
- View rendering bottlenecks

**Complementary:** `swiftui-patterns` for view composition refactors
**Profile with:** `make profile-report` (trace capture + metric extraction)

**Example:** "Scrolling in recording list is janky" → `swiftui-performance-audit` → recommend profile-report

---

### System-Level Performance (CPU, Memory, Energy)

**Primary:** `performance`
- CPU/memory profiling outside SwiftUI rendering
- Energy drain diagnosis
- App startup optimization
- I/O bottlenecks

**Not:** `swiftui-performance-audit` (that's for UI rendering only)

**Profile with:** Instruments.app, `make profile-report`

**Example:** "Meeting app drains battery quickly" → `performance` for system-level energy profiling

---

### Audio Capture/Processing Bottlenecks

**Primary:** `audio-realtime` (when MeetingAssistantCoreAudio is involved)
- Audio glitches, underruns, dropout
- Low-latency audio callback optimization
- ProcessTap or AVAudioSourceNode work
- Real-time buffer management

**Not:** `performance` (unless CPU profiling needed alongside)

**Example:** "Audio recording has glitches on M2" → `audio-realtime` for real-time callback tuning

---

### Concurrency and Actor Isolation

**Swift 6.2 compiler errors or Sendable diagnostics:**
→ **`swift-concurrency-expert`** (remediation, error fixes)

**Foundational/conceptual guidance only:**
→ **`concurrency`** (when no compiler issue in scope)

**Code-level verification:** Before merge on any concurrency-touching code:
```bash
make test-strict
./scripts/preflight.sh --strict-concurrency
```

**Example:** "error: Actor-isolated property accessed from non-isolated context" → `swift-concurrency-expert` for isolation fix

---

### Code Quality, Readability, Refactoring

**Primary:** `code-quality`
- Improve readability
- Rename for clarity
- Refactor duplicated logic
- Apply clean code conventions

**Complementary:** `code-review` if a full semáforo review is needed (Medium/High risk)

**Example:** "Extract duplicate audio logic into reusable service" → `code-quality`

---

### Debugging, Crashes, Flaky Tests

**Primary:** `debugging-strategies`
- Investigate crashes
- Trace unknown root causes
- Analyze flaky behavior
- Multi-subsystem diagnosis

**Complementary:** Other skills (audio-realtime, concurrency, performance) if area-specific

**Example:** "Crash on app quit when recording is active" → `debugging-strategies` → narrows to subsystem → escalate

---

### Data Persistence, Storage, Migrations

**Primary:** `data-persistence`
- Design repositories
- Plan data migrations
- Implement synchronization

**Complementary:** `security` if PII/sensitive data handling needed

**Example:** "Design storage strategy for meeting transcripts" → `data-persistence`

---

### Intelligence Kernel and Summary Quality

**Primary:** `intelligence-kernel`
- Kernel mode routing and feature-flag gating
- Canonical summary schema/trust-flags validation
- Summary benchmark thresholds, baseline, and enforce/report modes

**Complementary:** `data-persistence` (schema/migration impact), `quality-assurance` (regression gates)

**Example:** "Adjust canonical summary confidence rules" → `intelligence-kernel`

---

### Security and Secret Management

**General security posture:**
→ **`security`** (validate input, protect sensitive data, platform controls)

**Keychain/credential handling specifically:**
→ **`keychain-security`** (KeychainManager patterns, secret storage)

**Example:** "Safely store API key for transcription service" → `keychain-security`

---

### Networking and API Integration

**Primary:** `networking`
- API client design
- Request/response modeling
- URLSession configuration
- Network resiliency

**Complementary:** `security` for credential/TLS handling

**Example:** "Integrate with transcription API" → `networking` + `security`

---

### Documentation and API Comments

**Primary:** `documentation`
- DocC comments
- API documentation
- MARK organization
- README and guides

**Example:** "Add DocC comments to AudioRecorder public API" → `documentation`

---

### Git and Version Control

**Standard Git workflows:**
→ **`git-workflow`** (branches, commits, PRs, merges)

**Advanced Git operations:**
→ **`git-advanced-workflows`** (rebase, bisect, cherry-pick, reflog)

**Example:** "Rebase feature branch onto latest main" → `git-advanced-workflows`

---

### Testing and Quality Assurance

**Test writing and mocking:**
→ **`quality-assurance`** (XCTest patterns, mocks, verification gates)

**XCTest specifics:**
→ **`testing-xctest`** (@Test syntax, XCTAssert patterns)

**Example:** "Add unit tests for TranscriptionService" → `quality-assurance` or `testing-xctest`

---

### Localization and Accessibility

**Primary:** `localization`
- Localize UI text (`"key".localized`)
- Bundle module management
- Accessibility labels (VoiceOver)
- Sanitize removed text from Localizable.strings

**Example:** "Add Portuguese (Brazil) localization" → `localization`

---

### Menu Bar and macOS Native UI

**Primary:** `menubar`
- NSStatusItem configuration
- NSMenu and NSPopover behavior
- Non-activating overlays

**Complementary:** `macos-development` for platform integration context

**Example:** "Implement menu-bar popover for recording controls" → `menubar`

---

### Swift Package Manager and Dependencies

**Primary:** `swift-package-manager`
- Edit Package.swift
- Manage SPM dependencies
- Fix package resolution

**Example:** "Add new dependency on audio processing library" → `swift-package-manager`

---

### Repository Standards and Project Maintenance

**Primary:** `project-standards`
- Update AGENTS.md
- Document project policy
- Track known limitations
- Align repository standards

**Example:** "Update AGENTS.md to reflect new skill" → `project-standards`

---

## Skill Files and Direct Access

| Skill | File | When to use |
|-------|------|-----------|
| `audio-realtime` | `.agents/skills/audio-realtime/SKILL.md` | AVAudioSourceNode, ProcessTap, underruns |
| `build-macos-apps` | `.agents/skills/build-macos-apps/SKILL.md` | Quick workflow routing |
| `code-quality` | `.agents/skills/code-quality/SKILL.md` | Readability, refactoring |
| `code-review` | `.agents/skills/code-review/SKILL.md` | Semáforo review (🔴/🟡/🟢) |
| `concurrency` | `.agents/skills/concurrency/SKILL.md` | Conceptual async/await guidance |
| `data-persistence` | `.agents/skills/data-persistence/SKILL.md` | Storage design, migrations |
| `debugging-strategies` | `.agents/skills/debugging-strategies/SKILL.md` | Crash/flaky investigation |
| `documentation` | `.agents/skills/documentation/SKILL.md` | DocC, API docs |
| `intelligence-kernel` | `.agents/skills/intelligence-kernel/SKILL.md` | Kernel modes, canonical summary, summary benchmark gates |
| `macos-development` | `.agents/skills/macos-development/SKILL.md` | Canonical macOS/Swift guidance |
| `native-app-designer` | `.agents/skills/native-app-designer/SKILL.md` | UI/UX direction & design |
| `networking` | `.agents/skills/networking/SKILL.md` | API clients, URLSession |
| `performance` | `.agents/skills/performance/SKILL.md` | CPU/memory/energy profiling |
| `security` | `.agents/skills/security/SKILL.md` | Input validation, data protection |
| `swift-concurrency-expert` | `.agents/skills/swift-concurrency-expert/SKILL.md` | Swift 6.2 actor isolation, Sendable|
| `swiftui-animation` | `.agents/skills/swiftui-animation/SKILL.md` | Advanced animations, shaders |
| `swiftui-patterns` | `.agents/skills/swiftui-patterns/SKILL.md` | View composition, @State |
| `swiftui-performance-audit` | `.agents/skills/swiftui-performance-audit/SKILL.md` | UI rendering performance |
| `testing-xctest` | `.agents/skills/testing-xctest/SKILL.md` | XCTest, @Test, mocking |

---

## Notes

- Skills are loaded **conditionally**—consult only when relevant to task
- One skill per session usually best; chain skills only when sequential layers apply
- If uncertain, default to `macos-development` or `native-app-designer` as fallback
- Always cite the skill file in your request if you want specific guidance
