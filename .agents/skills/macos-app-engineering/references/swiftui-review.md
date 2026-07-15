# SwiftUI review appendix — Prisma

Routed from `../SKILL.md`. Use this for a SwiftUI **review pass** (modern API,
structure, performance hygiene). Implementation ownership stays in
`macos-app-engineering-details.md`. Do not treat this file as a second skill.

## Platform constraints

- macOS 15 minimum; guard macOS 26+ APIs with `#available(macOS 26, *)`.
- macOS 27 APIs are preview-only until the SDK ships.
- Prefer SwiftUI for view policy; AppKit for status items, panels, lifecycle,
  and capabilities SwiftUI cannot express.
- Route accessibility audits to `../../accessibility-audit/SKILL.md`.
- Route Swift language style, naming, and file/module rules to
  `../../swift-conventions/SKILL.md`.
- Route concurrency remediation to `../../swift-concurrency-expert/SKILL.md`.
- Route gesture/spring feel to `../../apple-design/SKILL.md`.

## When reviewing — output format

Organize findings by file. For each issue:

1. State the file and relevant line(s).
2. Name the rule being violated.
3. Show a brief before/after fix.

Skip files with no issues. End with a prioritized summary of the most
impactful changes.

Example:

```swift
// Before
Text("Hello").foregroundColor(.red)

// After
Text("Hello").foregroundStyle(.red)
```

## Modern SwiftUI API

- Prefer `foregroundStyle()` over `foregroundColor()`.
- Prefer `clipShape(.rect(cornerRadius:))` over `cornerRadius(_:)`.
- Prefer the zero- or two-parameter `onChange` forms; avoid the deprecated
  one-parameter variant.
- Prefer `containerRelativeFrame()`, `visualEffect()`, or `Layout` over
  `GeometryReader` when they solve the layout need.
- Prefer `overlay(alignment:content:)` over the deprecated
  `overlay(_:alignment:)`.
- Prefer `.scrollIndicators(.hidden)` over `showsIndicators: false`.
- Prefer `ForEach(items.enumerated(), id: \.element.id)` without converting
  `enumerated()` to an array first.
- Prefer text interpolation over `Text` concatenation with `+`.
- Prefer `#Preview` over `PreviewProvider`.
- Prefer `ImageRenderer` over AppKit/UIKit bitmap renderers when capturing
  SwiftUI views.
- Prefer `sensoryFeedback()` for haptics when the surface needs them; do not
  stack haptics with redundant copy and animation for one state change.
- Use the `@Entry` macro for custom `EnvironmentValues` / `FocusValues` keys.
- Prefer generated asset symbols (`Image(.avatar)`) when the target is
  configured for them.
- Ignore iOS-only placements such as `.navigationBarLeading` /
  `.topBarLeading` unless the code is genuinely cross-platform; on macOS use
  the toolbar placements already established in the surrounding UI.

## View structure and animation

- Prefer extracted `View` structs over large `some View` computed helpers when
  the helper is non-trivial or reused. Small private helpers that keep `body`
  readable may stay inline.
- Keep button actions and business logic out of `body`; prefer methods or a
  view model/testable owner.
- Prefer `Button("Label", systemImage:symbol, action:)` when the action is a
  method reference.
- Prefer `TextField(..., axis: .vertical)` over `TextEditor` when placeholder
  text matters and a full-screen editor is not required.
- Never use `animation(_:)` without a `value:`; always watch an explicit value.
- Prefer `@Animatable` over hand-written `animatableData` when custom
  animatable data is required.
- Chain sequential animations with `withAnimation` completion, not artificial
  delays.
- For interruptible gesture/spring feel, escalate to `apple-design` rather than
  inventing local spring vocabulary here.

File-per-type and naming budgets: follow `swift-conventions` (and project
policy of files ≤600 lines).

## Data flow (aligned with AGENTS / MAE)

- Prefer Observation (`@Observable`, `@State`, `@Bindable`, `@Environment`) for
  **new** SwiftUI state.
- Preserve existing `ObservableObject` / `@StateObject` / `@ObservedObject`
  contracts until an intentional migration (see plan 040 boundaries). Do not
  “ban” ObservableObject in review findings when the type is legacy and in
  scope for preservation.
- Mark `@Observable` UI models `@MainActor` unless default actor isolation
  already covers them.
- Keep `@State` private to the owning view.
- Avoid `Binding(get:set:)` in `body`; bind stored state and use `onChange` for
  side effects.
- Prefer `Identifiable` types over ad-hoc `id:` key paths when practical.
- Do not use `@AppStorage` inside an `@Observable` class for change tracking.
- Secrets and credentials belong in Keychain (`keychain-security`), never in
  `@AppStorage` or source.

## Navigation and presentation

- Prefer `NavigationStack` / `NavigationSplitView`; flag deprecated
  `NavigationView`.
- Prefer `navigationDestination(for:)` over `NavigationLink(destination:)` in
  new code; do not mix both patterns in one hierarchy.
- Prefer `sheet(item:)` when presenting optional model data.
- Attach `confirmationDialog` near the control that triggers it.
- Preserve Prisma Settings/`NavigationSplitView` taxonomy via MAE details —
  do not invent a parallel navigation shell in review suggestions.

## Performance hygiene

- Prefer ternary modifier values over `if/else` view branching when that
  preserves structural identity and avoids `_ConditionalContent` churn.
- Avoid `AnyView` unless required; prefer `@ViewBuilder`, `Group`, or generics.
- Keep view initializers cheap; move async work to `task` (cancels on
  disappear) rather than heavy `onAppear` work.
- Do not sort/filter/localize eagerly in `body` or in repeated `List`/`ForEach`
  initializers when the work can live in the owner.
- Prefer `LazyVStack` / `LazyHStack` for large scroll content.
- Prefer storing built `@ViewBuilder` content values over escaping
  `() -> Content` closures on views when either pattern works.

## Explicit non-goals (route away)

| Topic | Owner |
|---|---|
| Settings/design-system components, previews, AppKit lifecycle | `macos-app-engineering` details |
| VoiceOver, keyboard/focus, Reduce Motion **audit** | `accessibility-audit` |
| Spring physics, velocity handoff, materials feel | `apple-design` |
| SwiftLint budgets, naming, module layout | `swift-conventions` |
| Actor isolation / Sendable fixes | `swift-concurrency-expert` |
| Generic readability refactors | `code-quality` |
