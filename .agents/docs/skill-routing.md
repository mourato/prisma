# Skill Routing Guide

When working on Prisma, multiple skills may be relevant to a task. This guide provides routing logic that keeps one canonical owner per domain and avoids instruction overlap.

## General Routing Priority

When uncertain which skill to use, apply this priority order:

1. **`build-macos-apps`** — request intake and workflow routing for macOS app tasks
2. **`macos-development`** — canonical macOS and Swift implementation guidance
3. **`task-lifecycle`** — source of truth for risk lane and lifecycle phases
4. **`native-app-designer`** — primary UI and UX direction
5. **`swift-concurrency-expert`** — Swift 6.2 concurrency remediation
6. **`swiftui-performance-audit`** — SwiftUI runtime performance diagnosis

`build-macos-apps` is an orchestrator, not a deep implementation reference.

## External Project Code Lookup Priority

When inspecting code outside this repository, use this source order:

1. `MCP grep`
2. `gh` CLI
3. `deepwiki`
4. Web search

---

## Problem-Specific Routing

### Architecture and Boundaries

**Primary:** `architecture`
- Clean Architecture boundaries
- Dependency injection
- Cross-module ownership

**Complementary:** `macos-development`

**Example:** "Refactor meeting post-processing into a separate module" → `architecture`

---

### UI/UX and Interaction Work

**Start here:** `native-app-designer`
- Define visual and motion direction
- Set UX acceptance criteria
- Analyze interface quality

**Then (if needed):** `macos-design-guidelines` → `swiftui-patterns` → `swiftui-animation` → `swiftui-performance-audit`

**Example:** "Design the meeting recording UI" → `native-app-designer`

---

### SwiftUI Performance Issues

**Primary:** `swiftui-performance-audit`
- Janky scrolling
- Layout thrash
- Excessive view updates

**Complementary:** `swiftui-patterns`

**Example:** "Scrolling in recording list is janky" → `swiftui-performance-audit`

---

### System-Level Performance

**Primary:** `performance`
- CPU, memory, startup, and energy profiling outside SwiftUI rendering

**Complementary:** `observability-diagnostics`

**Example:** "Meeting app drains battery quickly" → `performance`

---

### Audio Capture and Processing

**Primary:** `audio-realtime`
- Audio glitches, underruns, dropout
- Low-latency callback optimization
- ProcessTap or AVAudioSourceNode work

**Example:** "Audio recording has glitches on M2" → `audio-realtime`

---

### Concurrency and Actor Isolation

**Compiler errors or Sendable diagnostics:** `swift-concurrency-expert`

**Conceptual guidance only:** `concurrency`

**Example:** "Actor-isolated property accessed from non-isolated context" → `swift-concurrency-expert`

---

### Code Quality and Refactoring

**Primary:** `code-quality`
- Readability and maintainability improvements
- Refactoring duplicated logic

**Complementary:** `swift-conventions`, `code-review`

**Example:** "Extract duplicate audio logic into a reusable service" → `code-quality`

---

### Error Modeling and Recovery

**Primary:** `error-handling`
- Error types and recovery paths
- Logging expectations for failures

**Complementary:** `observability-diagnostics`

**Example:** "Standardize export errors and recovery messaging" → `error-handling`

---

### Debugging, Crashes, and Flaky Behavior

**Primary:** `debugging-strategies`
- Unknown root cause investigation
- Crash analysis
- Flaky behavior

**Complementary:** `observability-diagnostics`, plus any subsystem skill that matches the narrowed scope

**Example:** "Crash on app quit when recording is active" → `debugging-strategies`

---

### Logging, Telemetry, and Diagnostics

**Primary:** `observability-diagnostics`
- `AppLogger` and `Logger`
- Structured event naming
- Payload redaction
- Failure signatures and metric correlation

**Example:** "Add diagnostic logging around shortcut capture failures" → `observability-diagnostics`

---

### Data Persistence, Storage, and Migrations

**Primary:** `data-persistence`
- Repositories
- Storage strategy
- Migrations and synchronization

**Complementary:** `security`

**Example:** "Design storage strategy for meeting transcripts" → `data-persistence`

---

### Intelligence Kernel and Summary Quality

**Primary:** `intelligence-kernel`
- Kernel mode routing and feature flags
- Canonical summary schema and trust flags
- Summary benchmark thresholds and enforcement

**Complementary:** `data-persistence`, `quality-assurance`

**Example:** "Adjust canonical summary confidence rules" → `intelligence-kernel`

---

### Security and Secret Management

**Primary:** `security`
- Threat model baseline
- Input validation
- Sensitive data controls

**Credentials specifically:** `keychain-security`

**Example:** "Safely store API key for transcription service" → `keychain-security`

---

### Networking and API Integration

**Primary:** `networking`
- API client design
- Request and response modeling
- URLSession configuration

**Complementary:** `security`

**Example:** "Integrate with transcription API" → `networking`

---

### Testing and Quality Assurance

**Verification policy and merge gates:** `quality-assurance`

**XCTest implementation details:** `testing-xctest`

**Example:** "Add unit tests for TranscriptionService" → `testing-xctest`

---

### Localization and Accessibility

**Primary:** `localization`
- Localize UI text
- Manage locale-file hygiene
- Keep accessibility copy localizable

**Audit and interaction accessibility:** `accessibility-audit`

**Example:** "Add Portuguese (Brazil) localization" → `localization`

---

### Menu Bar and macOS Native UI

**Primary:** `menubar`
- NSStatusItem configuration
- NSMenu and NSPopover behavior
- Non-activating overlays

**Complementary:** `macos-design-guidelines`, `macos-development`

**Example:** "Implement menu-bar popover for recording controls" → `menubar`

---

### Swift Package Manager and Dependencies

**Primary:** `swift-package-manager`
- Edit `Package.swift`
- Manage SPM dependencies
- Fix package resolution

**Example:** "Add new dependency on audio processing library" → `swift-package-manager`

---

### Repository Standards and Project Maintenance

**Primary:** `project-standards`
- Update `AGENTS.md`
- Document project policy
- Align repository standards

**Example:** "Update AGENTS.md to reflect new skill" → `project-standards`

---

### Skill Discovery and Authoring

**External skill search or installation:** `skills-discovery`

**Create or refactor a local skill:** `skill-development`

**Example:** "Find a skill for OpenAI docs" → `skills-discovery`

---

## Skill Files and Direct Access

| Skill | File | When to use |
|-------|------|-------------|
| `accessibility-audit` | `.agents/skills/accessibility-audit/SKILL.md` | VoiceOver, focus order, keyboard navigation, reduced motion |
| `architecture` | `.agents/skills/architecture/SKILL.md` | Module boundaries, Clean Architecture, DI |
| `audio-realtime` | `.agents/skills/audio-realtime/SKILL.md` | AVAudioSourceNode, ProcessTap, underruns |
| `build-macos-apps` | `.agents/skills/build-macos-apps/SKILL.md` | Quick workflow routing |
| `code-quality` | `.agents/skills/code-quality/SKILL.md` | Readability, refactoring |
| `code-review` | `.agents/skills/code-review/SKILL.md` | Semáforo review |
| `concurrency` | `.agents/skills/concurrency/SKILL.md` | Conceptual async/await guidance |
| `data-persistence` | `.agents/skills/data-persistence/SKILL.md` | Storage design, migrations |
| `debugging-strategies` | `.agents/skills/debugging-strategies/SKILL.md` | Crash and flaky investigation |
| `documentation` | `.agents/skills/documentation/SKILL.md` | DocC and API docs |
| `error-handling` | `.agents/skills/error-handling/SKILL.md` | Error modeling, recovery, logging |
| `intelligence-kernel` | `.agents/skills/intelligence-kernel/SKILL.md` | Kernel modes and summary benchmark gates |
| `macos-design-guidelines` | `.agents/skills/macos-design-guidelines/SKILL.md` | Human Interface Guidelines for Mac |
| `macos-development` | `.agents/skills/macos-development/SKILL.md` | Canonical macOS and Swift guidance |
| `native-app-designer` | `.agents/skills/native-app-designer/SKILL.md` | UI and UX direction |
| `networking` | `.agents/skills/networking/SKILL.md` | API clients and URLSession |
| `observability-diagnostics` | `.agents/skills/observability-diagnostics/SKILL.md` | Logs, telemetry, redaction, diagnostic signatures |
| `performance` | `.agents/skills/performance/SKILL.md` | CPU, memory, startup, and energy profiling |
| `quality-assurance` | `.agents/skills/quality-assurance/SKILL.md` | Verification gates and command policy |
| `skills-discovery` | `.agents/skills/skills-discovery/SKILL.md` | Find or install external skills |
| `skill-development` | `.agents/skills/skill-development/SKILL.md` | Create or refactor local skills |
| `task-lifecycle` | `.agents/skills/task-lifecycle/SKILL.md` | Risk classification and lifecycle policy |
| `testing-xctest` | `.agents/skills/testing-xctest/SKILL.md` | XCTest code structure, mocks, async tests |
| `security` | `.agents/skills/security/SKILL.md` | Input validation and data protection |
| `swift-concurrency-expert` | `.agents/skills/swift-concurrency-expert/SKILL.md` | Swift 6.2 actor isolation and Sendable fixes |
| `swiftui-animation` | `.agents/skills/swiftui-animation/SKILL.md` | Advanced animations and shaders |
| `swiftui-patterns` | `.agents/skills/swiftui-patterns/SKILL.md` | View composition and state management |
| `swiftui-performance-audit` | `.agents/skills/swiftui-performance-audit/SKILL.md` | UI rendering performance |
