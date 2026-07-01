# Plan 012: Merge Models, Text & Context, and Dictionary into Intelligence

> **Executor instructions**: Follow this plan step by step. Run every verification command and confirm the expected result before moving on. If anything in "STOP conditions" occurs, stop and report instead of improvising. When done, update the status row for this plan in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat a62d4a8e..HEAD -- Packages/MeetingAssistantCore/Sources/UI/pages/settings Packages/MeetingAssistantCore/Sources/UI/components/settings Packages/MeetingAssistantCore/Sources/UI/ViewModels Packages/MeetingAssistantCore/Sources/Common/Resources Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests`

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: `plans/010-consolidated-settings-routing-foundation.md`
- **Category**: direction / tech-debt
- **Planned at**: commit `a62d4a8e`, 2026-07-01

## Why this matters

`Models`, `Text & Context`, and `Dictionary` are three facets of one user question: how Prisma turns captured audio/text into useful output. Splitting them into three sidebar rows inflates navigation and makes model setup, AI cleanup, sensitive-app protection, and replacement rules feel unrelated. Merge them into one `Intelligence` destination with clear internal groups.

## Current state

- `ModelsSettingsTab.swift:24-53` contains provider/model setup and local/cloud transcription model sections.
- `EnhancementsSettingsTab.swift:58-68` contains Text & Context root content.
- `EnhancementsSettingsTab.swift:97-172` contains context awareness and sensitive-app protection.
- `EnhancementsSettingsTab.swift:71-95` contains post-processing and system-guidelines navigation.
- `VocabularySettingsTab.swift:16-68` contains dictionary replacement rules.
- `SettingsSearchIndex.swift:149-168` maps model/context/dictionary keys to three different sidebar destinations.
- `FloatingRecordingIndicatorSupport.swift:121-123` currently opens `.enhancements` for post-processing readiness issues.

## Commands you will need

| Purpose | Command | Expected on success |
| --- | --- | --- |
| AI/settings tests | `./scripts/run-tests.sh --suite dev --file SettingsSectionTests --file SettingsSearchIndexTests --file AppSettingsStoreAISelectionTests --file AppSettingsVocabularyRulesTests` | exit 0 |
| Recording indicator route test | `./scripts/run-tests.sh --suite dev --file RecordingIndicatorPostProcessingWarningTests` | exit 0 |
| Preview coverage | `make preview-check` | exit 0 |
| Compile | `make build-agent` | exit 0 |
| Full lane gate before push | `make build-test && make lint` | exit 0, or documented unrelated baseline failures |

## Scope

**In scope**:

- New `IntelligenceSettingsTab.swift`
- `ModelsSettingsTab.swift`
- `EnhancementsSettingsTab.swift`
- `VocabularySettingsTab.swift`
- `SettingsSection.swift`
- `SettingsPage.swift`
- `SettingsSearchIndex.swift`
- `SettingsSearchIndexKeys.swift`
- `FloatingRecordingIndicatorSupport.swift`
- Localizable strings in English and Portuguese
- Related tests

**Out of scope**:

- Changing provider credential storage or Keychain behavior.
- Changing prompt semantics.
- Copying VoiceInk prompt text or settings taxonomy.
- Renaming `Enhancements*` Swift types unless needed for a small, direct compile fix.

## Git workflow

- Branch: `advisor/012-merge-models-context-dictionary-intelligence`
- Commit style: `refactor(settings): merge intelligence configuration surfaces`

## Steps

### Step 1: Create `IntelligenceSettingsTab`

Create a container view with an internal route enum:

```swift
public enum IntelligenceSettingsRoute: Hashable {
    case models
    case textContext
    case dictionary
}
```

Use a segmented picker or compact drill-down list at the top. Reuse the existing tab bodies instead of copying:

- `ModelsSettingsTab()`
- `EnhancementsSettingsTab(...)`
- `VocabularySettingsTab()`

If embedding full tab headers causes repeated "Intelligence / Models / Text & Context" copy, add a parameter to child tabs such as `showsHeader: Bool = true` and pass `false` from the container.

**Verify**: `make build-agent` -> exit 0.

### Step 2: Make Intelligence the visible sidebar destination

Update `SettingsSection` visible order so `.intelligence` replaces `.models`, `.enhancements`, and `.vocabulary` in the sidebar. Keep old cases as legacy redirects.

Add strings:

- `settings.section.intelligence` = `Intelligence`
- Portuguese equivalent

Use a clear icon such as `brain.head.profile` or `sparkles`; do not add custom image assets.

**Verify**: `./scripts/run-tests.sh --suite dev --file SettingsSectionTests` -> exit 0.

### Step 3: Route old links and warnings into Intelligence

Update `FloatingRecordingIndicatorSupport.swift` so post-processing warning settings open the visible `.intelligence` destination, not `.enhancements`.

Update `RecordingIndicatorPostProcessingWarningTests.swift` expected section.

If the warning should ideally open the Text & Context child route, do not add stringly child-route plumbing in this plan. Open Intelligence root and ensure the Text & Context row/segment is visible enough.

**Verify**: `./scripts/run-tests.sh --suite dev --file RecordingIndicatorPostProcessingWarningTests` -> exit 0.

### Step 4: Update search mapping

Update `SettingsSearchIndex` so these map to `.intelligence`:

- `settings.section.models`
- `settings.models.*`
- `settings.section.ai`
- `settings.context_awareness.*`
- `settings.text_context.*`
- `settings.post_processing.*`
- `settings.enhancements.*`
- `settings.section.vocabulary`
- `settings.vocabulary.*`

Add tests for queries "Models", "Text & Context", "Dictionary", and "Replacement Rules" returning `.intelligence`.

**Verify**: `./scripts/run-tests.sh --suite dev --file SettingsSearchIndexTests` -> exit 0.

### Step 5: Remove redundant copy inside the merged page

Inside `IntelligenceSettingsTab`, keep one page-level description. Avoid repeating the same explanation in the page header and the first child header.

Native-app design criteria:

- The user should understand within 3 seconds that Intelligence has model setup, text/context behavior, and dictionary rules.
- Each subarea should have one visible explanation, not header + group + popover all saying the same thing.
- Keep popovers only where they add materially different detail.

**Verify**: `make preview-check` -> exit 0.

### Step 6: Run the thermo-nuclear review and fix its blockers

Invoke `thermo-nuclear-code-quality-review` with this scope:

```text
Audit the Intelligence consolidation diff. Look for copy-pasted tab content, child tabs that still render redundant headers, route logic scattered across SettingsPage/SearchIndex/indicator code, large-file growth, and abstractions that merely wrap existing tabs without reducing user or code complexity.
```

Fix every structural blocker. If a child tab needs extraction to stay readable, split by owning type directory or create uniquely named sibling files; do not use `Type+Concern.swift`.

**Verify**: rerun all commands from "Commands you will need".

## Test plan

- `SettingsSectionTests`: visible order and old-case redirect.
- `SettingsSearchIndexTests`: model/context/dictionary queries.
- `RecordingIndicatorPostProcessingWarningTests`: warning route opens Intelligence.
- Existing AI/vocabulary settings tests must still pass.

## Done criteria

- [ ] Sidebar has one Intelligence row instead of Models, Text & Context, and Dictionary.
- [ ] Existing old raw values still resolve safely.
- [ ] Search routes all model/context/dictionary queries to Intelligence.
- [ ] No provider credential behavior changes.
- [ ] Thermo-nuclear review blockers fixed.
- [ ] `plans/README.md` status row updated.

## STOP conditions

- Consolidation requires changing Keychain read/write logic.
- Child-route plumbing starts becoming a second navigation framework.
- Any source file crosses 700 lines without a decomposition plan in the same PR.

## Maintenance notes

Future model-selection work should land under Intelligence unless it is clearly workflow-specific, such as a Dictation-only active model picker already shown in Dictation.
