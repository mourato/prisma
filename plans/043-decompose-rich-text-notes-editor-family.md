# Plan 043: Decompose the rich-text notes editor family

> **Executor instructions**: Preserve editor behavior exactly. This is a UI/editor refactor with a mandatory thermo and accessibility review; correct all Critical/Medium findings before final gates.
>
> **Drift check**: `git diff --stat 80ed5788..HEAD -- Packages/MeetingAssistantCore/Sources/UI/components/settings/MeetingNotesRichTextEditor.swift Packages/MeetingAssistantCore/Sources/UI/Services/MeetingNotesMarkdownDocumentStore.swift Packages/MeetingAssistantCore/Sources/UI/components/settings/MeetingNotesMarkdownEditor.swift Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/MeetingNotesRichTextControllerTests.swift plans/README.md`

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: plans/041-modernize-swiftui-interactions-and-accessibility.md
- **Category**: tech-debt
- **Planned at**: commit `80ed5788`, 2026-07-12
- **Related issue**: #113

## Why this matters

`MeetingNotesRichTextEditor.swift` is 1,229 lines and still violates the serious 1,000-line file threshold and 600-line type threshold. The adjacent `MeetingNotesMarkdownDocumentStore.swift` is 1,118 lines. This concentration makes selection, formatting, markdown conversion, autosave, AppKit bridging, and SwiftUI layout difficult to review independently and increases regression risk in a user-edited document surface.

## Current state

- `MeetingNotesRichTextEditor.swift:1` contains the SwiftUI/AppKit editor surface, formatting actions, selection state, and preview.
- The main editor type begins near line 480 and exceeds the type-body limit.
- `MeetingNotesMarkdownDocumentStore.swift` owns persistence/coalescing behavior and is also oversized; keep it separate from view extraction.
- `MeetingNotesRichTextControllerTests.swift` is the existing behavior-test seam.

## Commands you will need

| Purpose | Command | Expected result |
|---|---|---|
| Editor tests | `swift test --package-path Packages/MeetingAssistantCore --filter 'MeetingNotesRichTextControllerTests|MeetingNotesMarkdown'` | exit 0 |
| Preview coverage | `make preview-check` | exit 0 |
| Build/lint | `make build-agent && make lint` | exit 0, no new violations |
| Full gate | `make build-test` | exit 0, baseline classified |

## Scope

**In scope**:

- `MeetingNotesRichTextEditor.swift`
- `MeetingNotesMarkdownDocumentStore.swift` only for extraction of clearly owned persistence/coalescing helpers
- `MeetingNotesMarkdownEditor.swift` only when a shared editor contract is required
- Existing editor/controller tests and focused new tests
- `plans/README.md`

**Out of scope**:

- Changing markdown semantics, persistence schema, autosave timing, keyboard shortcuts, or selection behavior.
- Replacing AppKit text editing with a new third-party editor.
- Combining the rich-text and markdown editors into one generic abstraction.

## Steps

### Step 1: Characterize editor contracts

Document and test formatting commands, selection replacement, markdown round-trips, autosave/coalescing, keyboard shortcuts, link editing, and error recovery. Use `MeetingNotesRichTextControllerTests` as the test pattern.

**Verify**: focused editor tests -> pass before extraction.

### Step 2: Extract by responsibility and ownership

Create unique colocated files for layout shell, toolbar/action controls, selection/command mapping, AppKit bridge, and pure formatting helpers. Keep document-store persistence helpers in the service family. Avoid computed `some View` properties when a dedicated `View` type makes ownership clearer.

**Verify**: `wc -l` and `swiftlint lint` -> no serious file/type violations in the editor family; focused tests pass.

### Step 3: Review accessibility and architecture

Run thermo review with `accessibility-audit` guidance. Inspect focus, VoiceOver labels, keyboard navigation, undo/redo, AppKit ownership, autosave cancellation, and retain cycles. Correct all Critical/Medium findings.

**Verify**: review report has no unresolved Critical/Medium findings.

### Step 4: Run gates

Run `make preview-check`, `make build-agent`, `make lint`, and `make build-test`; record any pre-existing unrelated baseline separately.

**Verify**: commands complete with recorded results and the plan ledger is updated.

## Done criteria

- [ ] No editor file remains above 1,000 lines; each extracted type has one clear responsibility.
- [ ] Formatting, selection, keyboard, autosave, persistence, and accessibility behavior is preserved.
- [ ] Focused editor tests and previews pass.
- [ ] Thermo/accessibility review has no unresolved Critical/Medium findings.
- [ ] Full gates are attempted and documented.
- [ ] `plans/README.md` status row updated.

## STOP conditions

- A split requires changing persisted markdown/schema behavior.
- AppKit and SwiftUI ownership cannot be separated without changing text-editing semantics.
- Existing tests do not cover a behavior that extraction would risk; add characterization tests first or stop.

## Maintenance notes

Keep pure formatting/conversion logic independently testable. Do not reintroduce a single editor god type through a generic wrapper or closure-heavy component.
