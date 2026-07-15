# Localization Patterns — extended reference

Extended examples and checklists. Hard rules and `Bundle.safeModule` usage live in `../SKILL.md`.

## String management

```swift
// ❌ WRONG
Text("Record")

// ✅ CORRECT
Text("recording.start".localized)
```

## Mandatory registration on new key introduction

When introducing a new `"key".localized` usage:

1. Add the key to `en.lproj/Localizable.strings` with the English value.
2. Add the key to `pt.lproj/Localizable.strings` with the Portuguese translation.
3. Keep locale files symmetric.
4. Keep source usage, locale entries, and focused test coverage in the same commit/slice.
5. Verify with `LocalizationKeyIntegrityTests` or a tighter focused check before merge.

Missing registration is a defect, not a deferrable item — applies at any risk lane.

## Mandatory sanitization on UI text removal

When user-facing text is removed:

1. Remove orphaned keys from all supported locale files.
2. Confirm no source references remain.
3. Keep locale files symmetric.

## Key convention

```swift
"recording.start"
"recording.stop"
"settings.transcriptions.empty_desc"
```

## Accessible copy (VoiceOver text)

Describe **what the UI does**, not just labels:

```swift
// ❌ WRONG — label only
Button(action: {}) { Image(systemName: "mic.fill") }
.accessibilityLabel("Microphone")

// ✅ CORRECT — purpose description
Button(action: {}) { Image(systemName: "mic.fill") }
.accessibilityLabel("recording.start.accessibility".localized)
.accessibilityHint("recording.start.hint.accessibility".localized)
```

Accessibility key pattern: `component.action.accessibility`

```swift
"menubar.recording.start.accessibility" = "Start recording";
"menubar.recording.stop.accessibility" = "Stop recording";
```

## Settings taxonomy changes

When settings pages are merged or renamed:

1. Update locale files, section titles, search index mappings, and tests in the same slice.
2. Keep old localization keys only when legacy routes or search terms still need them.
3. Add search tests for both new parent labels and old child terms.
4. Re-check for duplicated copy when parent and child labels say the same thing.
