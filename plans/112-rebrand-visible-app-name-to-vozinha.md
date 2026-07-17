# Plan 112: Rebrand the visible app name to Vozinha

> **Executor instructions**: Follow this plan step by step. The plan assumes
> that `Vozinha` is the commercial/display name and that existing technical
> identities remain stable. Stop at the decision checkpoint if that assumption
> is rejected. Do not perform a global blind replacement.
>
> **Drift check (run first)**: `git diff --stat 0c077987..HEAD -- Config/Branding.xcconfig Packages/MeetingAssistantCore/Sources/Common/Config/AppIdentity.swift scripts/config/app_identity.sh App/Info.plist App/en.lproj/InfoPlist.strings App/pt-BR.lproj/InfoPlist.strings`.
> If any listed file changed since this plan was written, compare the current
> state before editing; a mismatch in identity ownership is a STOP condition.

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: none
- **Category**: migration
- **Planned at**: commit `0c077987`, 2026-07-17
- **Implementation**: complete in commits `fef5066e` and `1cc0ce15`
- **Remaining gate**: manual upgrade-continuity smoke test over an existing installation

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `High/Full`
- **Parallelizable**: no — all workstreams change the same product identity contract.
- **Reviewer required**: yes — the change affects persistence continuity, build/release infrastructure, signing, and localized user-facing copy.
- **Rationale**: The visible rename is straightforward, but the repository has duplicated identity definitions and release artifacts. A single coordinated implementation is safer than parallel edits that can disagree about which identifiers must remain stable.
- **Escalate when**: the bundle identifier, XPC identifier, Keychain service, Application Support directory, UserDefaults domain, Sparkle feed, signing identity, or target/module names are also renamed; that becomes a separate migration plan or a broader High/Full scope.

## Decision checkpoint

Before editing product files, confirm this identity contract with the maintainer:

| Identity | Current | Target in this plan | Ownership / rule |
|---|---|---|---|
| Commercial/display name | `Prisma` | `Vozinha` | Declared once in `Config/AppIdentity.plist`; emitted into build/runtime adapters |
| App bundle identifier | `com.mourato.prisma` | unchanged | Declared once in the manifest; preserve permissions, installation continuity, and Launch Services identity |
| XPC bundle identifier | `com.mourato.prisma.ai-service` | unchanged | Declared once in the manifest; preserve app/XPC relationship |
| App Support directory | `Prisma` | unchanged | Declared once in the manifest; preserve local recordings, models, databases, and settings |
| Logs directory | `Prisma` | unchanged | Declared once in the manifest; preserve diagnostic continuity |
| Keychain service | `com.mourato.prisma` | unchanged | Declared once in the manifest; preserve stored API keys |
| UserDefaults domains/keys | existing values | unchanged | Declared once in the manifest where applicable; preserve preferences and migrations |
| Swift project/target/module names | `MeetingAssistant*` | unchanged | Declared once in the manifest where build tooling needs it; internal architecture names are not user-facing |
| XPC product filename | `PrismaAI.xpc` | unchanged unless explicitly requested | Internal artifact; avoid unnecessary updater/signing churn |

If the maintainer wants any “unchanged” item renamed, stop and split that
request into an explicit migration design. Do not infer that a new brand means
new storage or security identifiers.

## Why this matters

The repository already separates the visible product name from technical
identifiers, but it currently duplicates identity values across
`Config/Branding.xcconfig`, `AppIdentity.swift`, and
`scripts/config/app_identity.sh`. A blind replacement could make the app look
like `Vozinha` while silently changing its data directories, Keychain lookup,
permissions, or update identity. This plan produces the new visible brand,
defines canonical ownership by identity domain, and adds checks that prevent
the duplicated sources from drifting again.

## Current state

- `Config/Branding.xcconfig` contains build-time values: `APP_DISPLAY_NAME`,
  `APP_PRODUCT_NAME`, bundle IDs, product names, support/log directory names,
  Keychain service ID, and log subsystem (`Config/Branding.xcconfig:1-13`).
- `AppIdentity.swift` contains runtime and persistence values, including the
  visible name, bundle IDs, support/log directory names, Keychain service,
  legacy migration names, and stable window identifiers
  (`Packages/MeetingAssistantCore/Sources/Common/Config/AppIdentity.swift:3-28`).
- `scripts/config/app_identity.sh` independently defines the app product and
  XPC product names (`scripts/config/app_identity.sh:1-8`).
- `App/Info.plist` correctly obtains `CFBundleDisplayName` from
  `APP_DISPLAY_NAME`, but still contains literal `Prisma` permission copy and
  the existing Sparkle feed (`App/Info.plist:7-53`). The localized permission
  copies are in `App/en.lproj/InfoPlist.strings` and
  `App/pt-BR.lproj/InfoPlist.strings`.
- Runtime comments and behavior-adjacent literals still mention `Prisma`, for
  example the resident menu-bar process and workspace filtering
  (`App/AppDelegate/AppDelegateLifecycle.swift:10-12`,
  `Packages/MeetingAssistantCore/Sources/Infrastructure/Services/MeetingDetector.swift:92-100`).
- Recording context filtering uses a helper named
  `isPrismaBundleIdentifier`, but its actual comparison is against
  `AppIdentity.bundleIdentifier` and the runtime bundle ID
  (`Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/RecordingManagerStart.swift:240-265`).
  The helper name should be made brand-neutral, not changed to a new brand.
- Release automation still names the product `Prisma`, including the Sparkle
  workflow, release scripts, DMG scripts, and test fixtures that expect
  `Prisma.app`.
- Localized `Prisma` copy appears in onboarding, About, metrics, permissions,
  menu-bar accessibility, settings, and update messages in the English and
  Portuguese resource files.

## Canonical identity ownership

Use one machine-readable Property List as the only hand-maintained identity
source: `Config/AppIdentity.plist`. It should contain separate sections for
`product`, `technical`, `persistence`, `migration`, and `internal` values. The
fact that values live in one manifest does not mean they should be equal: the
manifest must explicitly preserve the old technical and persistence values
while changing only the product display name.

Generate the consumers from that manifest:

1. `Config/Branding.xcconfig` becomes a generated Xcode adapter containing
   `APP_DISPLAY_NAME = Vozinha`, `APP_PRODUCT_NAME = Vozinha`, and the
   unchanged bundle/XPC settings required by the project.
2. `Packages/MeetingAssistantCore/Sources/Common/Config/AppIdentityValues.generated.swift`
   becomes a generated Swift adapter. `AppIdentity.swift` retains runtime
   behavior and migration logic but reads its constants from the generated
   values type; it must not duplicate identity literals.
3. `scripts/config/app_identity.sh` becomes a generated shell adapter, or a
   thin wrapper around one, so build/DMG/profile scripts do not maintain a
   second product-name list.
4. Add a deterministic generator with `--check` mode. Normal generation may
   update these adapters; CI and `make guidance-check` must fail if generation
   would produce a diff. Generated files must carry a header saying they are
   generated and must not be edited manually.

Use Foundation's Property List support in the generator and in tests; do not
introduce a third-party parser or require `jq`. This gives Xcode, Swift, and
shell tooling one declarative source while retaining native adapters for each
consumer.

The implementation must not rename `MeetingAssistantCore`, Swift imports,
targets, schemes, bundle IDs, Keychain services, or storage directories as a
side effect of the branding change.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Inventory old brand | `rg -n -i --hidden -g '!/.git/**' -g '!plans/**' -g '!.agents/reports/**' 'prisma' .` | Every remaining match is classified as intentional, technical, historical, or a missed user-facing occurrence |
| Guidance validation | `make guidance-check` | Exit 0; no guidance/link/Makefile reference errors |
| Strict lint | `make lint-strict-agent` | Exit 0; no new Swift lint errors |
| Focused package tests | `make test-agent` | Exit 0; affected tests pass |
| Canonical validation | `make validate-agent ARGS="--lane full --no-reuse --agent"` | Exit 0, or a documented baseline failure unrelated to this change |
| Release parity | `make ci-release-parity` | Exit 0 in the configured dry-run/release-parity mode |

For commands that require a clean tree, use the repository's normal isolated
worktree workflow. Do not delete or reset unrelated user changes.

## Scope

### In scope

- `Config/Branding.xcconfig`
- `Config/AppIdentity.plist`
- The deterministic identity generator and its `--check` validation path.
- `Packages/MeetingAssistantCore/Sources/Common/Config/AppIdentity.swift`
- `Packages/MeetingAssistantCore/Sources/Common/Config/AppIdentityValues.generated.swift`
- `scripts/config/app_identity.sh`
- `App/Info.plist`
- `App/en.lproj/InfoPlist.strings`
- `App/pt-BR.lproj/InfoPlist.strings`
- `Packages/MeetingAssistantCore/Sources/Common/Resources/en.lproj/Localizable.strings`
- `Packages/MeetingAssistantCore/Sources/Common/Resources/pt.lproj/Localizable.strings`
- App/runtime files containing user-facing or brand-specific literals, including
  `App/MeetingAssistantApp.swift`,
  `App/AppDelegate/AppDelegateLifecycle.swift`,
  `Packages/MeetingAssistantCore/Sources/Infrastructure/Services/MeetingDetector.swift`,
  and `Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/RecordingManagerStart.swift`.
- Release/build files that expose the product name, including
  `.github/workflows/sparkle-release.yml`, `scripts/build-release.sh`,
  `scripts/create-dmg.sh`, `scripts/debug-app.sh`,
  `scripts/profile-performance.sh`, and related name assertions in tests.
- `README.md`, `AGENTS.md`, and other current project documentation where
  `Prisma` describes the current product rather than a historical decision.
- New focused tests/checks for identity parity and storage/Keychain continuity.

### Out of scope

- Renaming the Xcode project, targets, SwiftPM products, directories, imports,
  XPC target, or `MeetingAssistantCore` modules.
- Changing `com.mourato.prisma`, `com.mourato.prisma.ai-service`, Keychain
  service identifiers, support/log paths, UserDefaults domains, or migration
  keys.
- Changing Sparkle's feed URL, EdDSA public key, signing identity, or update
  protocol. Only update artifact display names where required.
- Replacing the app icon or designing new brand assets; treat that as a
  separate visual-brand task.
- Rewriting historical plans, archived reports, benchmark references, or
  migration comments that explain the old identity.
- Renaming temporary filenames or internal symbols solely because they contain
  `prisma`; change them only when they are user-visible or misleading in the
  new branding.

## Steps

### Step 1: Characterize the identity surface

Run the inventory command above and classify every `Prisma`/`prisma` match into
one of four buckets: user-facing brand, build/release artifact, protected
technical identifier, or historical/internal reference. Record the result in
the plan execution notes or a focused test fixture; do not edit files during
this step. Confirm that the protected values in the decision table are present
and that the current working tree has no unrelated identity changes.

**Verify**: `git status --short` plus the inventory `rg` command → no unrelated
changes and a complete classification of all matches.

### Step 2: Establish the single manifest and generated adapters

Create `Config/AppIdentity.plist` as the only hand-maintained identity source.
Implement a deterministic generator using Foundation that emits the Xcode
xcconfig adapter, the Swift values adapter, and the shell adapter. Add a
`--check` mode that exits non-zero when generated output is stale. Keep
`AppIdentity.swift` as handwritten behavior and migration logic, but remove
duplicated identity constants from it. Add parity coverage for the manifest,
generated outputs, and the protected bundle IDs, storage names, Keychain
service, migration names, and stable window identifiers. Prefer existing test
patterns in `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/`
and avoid network, Keychain, hardware, or destructive persistence in tests.

**Verify**: run the generator, then its `--check` mode and `make test-agent` →
no generated diff and all affected tests pass.

### Step 3: Apply the visible `Vozinha` rebrand

Change build product/display values and all current user-facing localized copy
in English and Portuguese. Update onboarding, About, metrics, menu-bar
accessibility labels, permissions, settings, integration test messages, and
update messages. Keep localization keys stable; only change values unless a
key is genuinely brand-specific. Replace brand-specific helper names such as
`isPrismaBundleIdentifier` with neutral names based on the behavior, while
keeping the bundle-ID comparison unchanged.

Update comments only when they describe the current product. Do not alter
technical identifiers or migration constants.

**Verify**: `rg -n -i 'prisma'` → only classified intentional, technical, or
historical matches remain; `make lint-strict-agent` → exit 0.

### Step 4: Align build, packaging, tests, and release automation

Update shell scripts, Sparkle workflow labels, archive/DMG names, schemes, and
test fixtures so that the visible application artifact is `Vozinha.app` where
the build product is expected to be branded. Preserve `MeetingAssistant` as
the scheme/target name and preserve `PrismaAI.xpc` unless the decision
checkpoint is explicitly expanded. Ensure the Sparkle feed URL, public key,
bundle IDs, and signing/notarization inputs are unchanged.

**Verify**: `make build-agent` → debug build completes and produces
`Vozinha.app`; inspect the built Info.plist with `plutil` → display name is
`Vozinha` and protected identifiers are unchanged; `make ci-release-parity` →
release parity passes.

### Step 5: Validate upgrade continuity

Test the new build over an existing `Prisma` installation or a controlled
fixture containing existing preferences, local data, model files, and API-key
entries. Confirm that the app reads the same Application Support directory,
logs directory, UserDefaults, and Keychain service; that existing microphone,
screen-recording, automation, and calendar permissions continue to apply; and
that Launch at Login still points to the same app identity. Confirm that
Sparkle recognizes the new build as an update to the existing installation.

Do not log or copy secret values, transcripts, prompts, or personal data while
performing this validation.

**Verify**: `make validate-agent ARGS="--lane full --no-reuse --agent"` → full
technical gate passes; manual upgrade checklist → every continuity item passes
or has a documented baseline/environment limitation.

### Step 6: Update current documentation and handoff evidence

Update current README and project guidance to state that `Vozinha` is the
display brand and that technical identifiers remain stable by design. Leave
historical plans/reports unchanged. Record the identity ownership matrix, the
protected identifiers, commands run, results, baseline failures, and any
follow-up work such as icon replacement or technical namespace renaming.

**Verify**: `make guidance-check` → exit 0; `git diff --check` → no whitespace
errors; `git status --short` → only planned files are changed.

## Test plan

- Add an identity-contract test covering the expected display name and the
  protected bundle/XPC/storage/Keychain/migration values.
- Add or extend a runtime identity test proving that `AppIdentity` uses bundle
  metadata for the display name while retaining a deterministic test fallback.
- Preserve existing storage and Keychain migration tests; do not rewrite their
  service/path expectations to `Vozinha` in this plan.
- Run `make test-agent`, `make lint-strict-agent`, and the full
  `make validate-agent` command above.
- Perform a built-artifact inspection and an upgrade-continuity smoke test;
  source tests alone cannot prove Launch Services, TCC, Sparkle, or signing
  behavior.

## Done criteria

- [x] The app displays `Vozinha` in the built bundle and current localized UI.
- [x] `Config/AppIdentity.plist` is the only hand-maintained identity source.
- [x] `Branding.xcconfig`, the generated Swift values, and the shell adapter
      are deterministic outputs and pass generator `--check`.
- [x] `AppIdentity.swift` owns runtime behavior/migrations without duplicating
      identity literals.
- [x] `com.mourato.prisma`, the XPC bundle ID, Keychain service, storage/log
      directories, UserDefaults domains, migration names, and stable window
      identifiers are unchanged.
- [x] `MeetingAssistant*` targets, schemes, modules, and imports remain intact.
- [x] Release scripts, DMG/archive expectations, tests, and Sparkle parity use
      the new visible product name without changing update identity.
- [x] `make test-agent` exits 0.
- [x] `make lint-strict-agent` exits 0.
- [x] `make validate-agent ARGS="--lane full --no-reuse --agent"` exits 0, or
      known baseline failures are documented.
- [x] `make ci-release-parity`, `make guidance-check`, and `git diff --check`
      pass.
- [x] No secrets, transcripts, prompts, credentials, or machine state were
      added to the repository or diagnostics.
- [x] Only planned files are modified and the reviewer confirms the identity
      matrix.
- [ ] Manual upgrade-continuity smoke test confirms existing data, permissions,
      login item, and Sparkle continuity.

## STOP conditions

Stop and report instead of improvising if:

- The maintainer wants to change any protected technical identifier.
- A source-of-truth value cannot be derived or validated without introducing a
  new build-generation system outside this plan.
- Existing data, Keychain entries, permissions, login-item registration, or
  Sparkle continuity cannot be demonstrated with the stable identifiers.
- The built artifact still has a stale display name after the branding change.
- The change requires renaming more than the scoped build/release/runtime
  files, targets/modules, or more than eight unrelated production areas.
- Any validation failure appears to be caused by a baseline issue and cannot be
  isolated from the rebrand after two reasonable attempts.

## Maintenance notes

- Future product renames should update the branding source and identity matrix,
  not search-and-replace the repository.
- Any future bundle-ID or Keychain-service change requires an explicit migration
  design and an upgrade test before release.
- Keep `MeetingAssistant*` names stable until there is a separate architectural
  decision to rename the internal namespace.
- Reviewers should pay particular attention to accidental changes in TCC,
  Keychain, UserDefaults, Application Support, Sparkle, and Launch at Login
  continuity.
- A later brand-assets plan may replace the icon and website/appcast naming;
  that work is intentionally deferred here.
- Current development-only references in `Packages/MeetingAssistantCore/Sources/Core/MeetingAssistantCore.docc/MeetingAssistantCore.md`,
  `Packages/MeetingAssistantCore/Sources/UI/components/design-system/DSShortcutControlsRow.swift`,
  and `scripts/setup-dev-environment.sh` can be cleaned up separately; they do
  not ship as the app's visible branding.
