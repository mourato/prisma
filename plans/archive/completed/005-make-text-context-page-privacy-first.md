# Plan 005: Make Text & Context a privacy-first cross-cutting settings page

> **Executor instructions**: Follow this plan step by step. Run every verification command and confirm the expected result before moving to the next step. If anything in the "STOP conditions" section occurs, stop and report. When done, update the status row for this plan in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat f66b446d..HEAD -- Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/EnhancementsSettingsTab.swift Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsSearchIndex.swift Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsSearchIndexKeys.swift Packages/MeetingAssistantCore/Sources/Common/Resources/en.lproj/Localizable.strings Packages/MeetingAssistantCore/Sources/Common/Resources/pt.lproj/Localizable.strings Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/SettingsSearchIndexTests.swift`
> If any in-scope file changed since this plan was written, compare the "Current state" excerpts against the live code before proceeding; on a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: `plans/004-reframe-settings-sidebar-taxonomy.md`
- **Category**: direction
- **Planned at**: commit `f66b446d`, 2026-07-01

## Why this matters

Context capture is both powerful and privacy-sensitive. In VoiceInk it is visible as "Context Awareness" in the main menu and permission surfaces; in Prisma it is currently nested inside the enhancements page alongside generic post-processing controls. Prisma should keep its privacy-friendly defaults, but the UI should make the model clear: context sources and protected apps are a cross-cutting policy for dictation and meetings, not an advanced AI tweak.

This plan keeps the existing `EnhancementsSettingsTab` type and storage. It changes page hierarchy and copy only.

## Current state

- `EnhancementsSettingsTab` currently renders:
  - `SettingsSectionHeader(title: "settings.section.ai", description: "settings.post_processing.description")`
  - `mainSection`
  - `protectSensitiveAppsSection`
  - `contextAwarenessSection`
- `mainSection` is titled `settings.post_processing.title` and contains the post-processing enable toggle plus a drill-down for system prompt.
- `protectSensitiveAppsSection` already uses the reusable `InstalledAppsSelectionViewModel`, with `TextContextExclusionPolicy.defaultBundleIDs` as protected defaults.
- `contextAwarenessSection` contains the context toggle and specific sources: Accessibility UI text, Clipboard, Window OCR, redaction.

Relevant current excerpts:

```swift
// Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/EnhancementsSettingsTab.swift:58
private var rootPage: some View {
    SettingsScrollableContent {
        SettingsSectionHeader(
            title: "settings.section.ai".localized,
            description: "settings.post_processing.description".localized
        )

        mainSection
        protectSensitiveAppsSection
        contextAwarenessSection
    }
}
```

```swift
// Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/EnhancementsSettingsTab.swift:146
private var protectSensitiveAppsSection: some View {
    DSGroup("settings.context_awareness.protect_sensitive_apps".localized, icon: "lock.shield") {
        ...
        InstalledAppsSelectionList(...)
    }
}
```

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Search tests | `swift test --package-path Packages/MeetingAssistantCore --filter SettingsSearchIndexTests` | exit 0 |
| Preview check | `make preview-check` | exit 0 |
| Fast compile | `make build-agent` | exit 0 |
| Full lane gate | `make build-test` | exit 0 or unrelated baseline failures documented |
| Full lane lint | `make lint` | exit 0 |

## Scope

**In scope**:
- `Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/EnhancementsSettingsTab.swift`
- `Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsSearchIndex.swift`
- `Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsSearchIndexKeys.swift`
- `Packages/MeetingAssistantCore/Sources/Common/Resources/en.lproj/Localizable.strings`
- `Packages/MeetingAssistantCore/Sources/Common/Resources/pt.lproj/Localizable.strings`
- `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/SettingsSearchIndexTests.swift`

**Out of scope**:
- Changing `AppSettingsStore` keys or defaults.
- Changing `TextContextExclusionPolicy`.
- Moving context capture runtime behavior.
- Adding a new sidebar enum case.
- Implementing per-app automation or VoiceInk-style Power Mode.

## Git workflow

- Branch: `advisor/text-context-privacy-page`
- Commit style: `refactor(settings): make text context page privacy-first`
- Risk lane: Medium / Full lane.

## Steps

### Step 1: Update the page header to describe the cross-cutting job

Assuming Plan 004 has changed the visible section label to `Text & Context`, update the page description key used by `SettingsSectionHeader` so it no longer reuses the generic post-processing description.

Add new localization keys:

- `settings.text_context.description`
  - English: `Control AI cleanup, context sources, and sensitive-app protection for dictation and meetings.`
  - Portuguese: `Controle limpeza por IA, fontes de contexto e proteção de apps sensíveis para ditado e reuniões.`

Update `EnhancementsSettingsTab.rootPage` to use:

```swift
SettingsSectionHeader(
    title: "settings.section.ai".localized,
    description: "settings.text_context.description".localized
)
```

Keep the existing title key from Plan 004; do not rename Swift types.

**Verify**: `rg -n "settings.text_context.description|settings.section.ai" Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/EnhancementsSettingsTab.swift Packages/MeetingAssistantCore/Sources/Common/Resources/*.lproj/Localizable.strings` shows both locales and the page reference.

### Step 2: Reorder sections so privacy policy comes before feature toggles

Change `rootPage` order to:

```swift
protectSensitiveAppsSection
contextAwarenessSection
mainSection
```

Rationale: sensitive-app protection is always-on policy; users should not infer it only matters when a toggle is enabled. This matches prior Prisma guidance: privacy-friendly behavior is product policy, not optional chrome.

Do not disable `protectSensitiveAppsSection` based on `contextAwarenessEnabled`.

**Verify**: `make preview-check` exits 0 after this step.

### Step 3: Rename visible Context Awareness copy to simpler user-facing language

Keep localization keys stable unless a new key is cleaner. Update visible values:

- `settings.context_awareness.title`
  - English: `Context Sources`
  - Portuguese: `Fontes de Contexto`
- `settings.context_awareness.enabled`
  - English: `Use context when improving text`
  - Portuguese: `Usar contexto ao melhorar texto`
- `settings.context_awareness.enabled_desc`
  - English: `Capture allowed local context at recording start and include it in AI cleanup.`
  - Portuguese: `Captura contexto local permitido no início da gravação e inclui na limpeza por IA.`
- `settings.context_awareness.protect_sensitive_apps`
  - English: `Protected Apps`
  - Portuguese: `Apps Protegidos`
- `settings.context_awareness.protect_sensitive_apps_desc`
  - English: `Never capture context from these apps. Built-in sensitive apps stay protected by default.`
  - Portuguese: `Nunca capture contexto destes apps. Apps sensíveis nativos continuam protegidos por padrão.`

Avoid repeating the same sentence in header, group description, and popover.

**Verify**: `rg -n '"settings.context_awareness.(title|enabled|enabled_desc|protect_sensitive_apps|protect_sensitive_apps_desc)"' Packages/MeetingAssistantCore/Sources/Common/Resources/*.lproj/Localizable.strings` shows the updated values.

### Step 4: Keep Settings search routing accurate

If new keys are added, add them to `SettingsSearchIndexKeys.swift` and route them to `.enhancements` in `SettingsSearchIndex.swift`.

Add tests in `SettingsSearchIndexTests.swift`:

- A text/context description key routes to `.enhancements`.
- A protected-apps key routes to `.enhancements`.
- The search query `Protected` or `Context` returns an `.enhancements` result.

**Verify**: `swift test --package-path Packages/MeetingAssistantCore --filter SettingsSearchIndexTests` exits 0.

### Step 5: Run UI checks and Full lane gates

Run:

```bash
make preview-check
make build-agent
make build-test
make lint
```

Expected: exit 0. If broad gates fail from unrelated baseline issues, document exact failing tests and show focused settings/search tests passing.

## Test plan

- Update `SettingsSearchIndexTests.swift` for any new keys and for user-facing context/protected-app search terms.
- No new ViewModel tests are required because this plan changes hierarchy and copy only.

## Done criteria

- [ ] `Text & Context` page header describes AI cleanup, context, and sensitive-app protection.
- [ ] Protected apps appear before context-source and post-processing controls.
- [ ] Copy no longer presents context capture as a vague "AI" feature.
- [ ] Settings search routes new/renamed text-context keys to `.enhancements`.
- [ ] `swift test --package-path Packages/MeetingAssistantCore --filter SettingsSearchIndexTests` exits 0.
- [ ] `make preview-check` and `make build-agent` exit 0.
- [ ] Full lane results from `make build-test` and `make lint` are recorded.
- [ ] No files outside the in-scope list are modified.

## STOP conditions

Stop and report if:

- `EnhancementsSettingsTab` has already been split into a new page or renamed.
- The change appears to require new settings storage.
- Sensitive-app protection is no longer always-on policy.
- Search routing changes require a broader search-index redesign.

## Maintenance notes

Reviewers should scrutinize redundancy. The page header, group title, and group description should each add distinct information. Do not add extra popovers unless they explain a different risk or permission.
