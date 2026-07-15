---
name: macos-app-engineering
description: Use for macOS UI/app work touching SwiftUI views, AppKit bridging, Settings UI, design-system components, previews, lifecycle, or platform behavior.
---

# macOS App Engineering

## Role

Own ordinary macOS application implementation: SwiftUI composition, settings
surfaces, AppKit bridges, lifecycle, previews, platform availability, and
design-system reuse.

## Scope Boundary

Use this skill for macOS UI/app implementation and review. Route motion/physics
to `apple-design`, accessibility audits to `accessibility-audit`, concurrency
to `swift-concurrency-expert`, and architecture decisions to `architecture`.

## When to Use

Trigger for SwiftUI views, Settings navigation/layout, design-system controls,
preview coverage, AppKit panels/status items, lifecycle integration, or native
macOS behavior.

## Non-negotiable rules

- Preserve native `NavigationSplitView`/`List(.sidebar)` semantics and existing
  settings taxonomy unless the request explicitly changes them.
- Reuse existing design-system tokens, settings containers, navigation state,
  localization, and search contracts before creating new abstractions.
- Keep AppKit bridging at lifecycle/panel/capability boundaries and preserve
  macOS 15 fallbacks for newer APIs.
- In settings `Form` surfaces, use a native `Picker` with a visible label as
  the default value-control pattern. Reserve `DSMenuPicker` for compact
  controls outside `Form`, such as filters or fixed-width action rows.
- Keep previews representative, deterministic, and free of network, Keychain,
  hardware, or destructive persistence side effects.
- Respect Dynamic Type, Reduce Motion, focus, keyboard, VoiceOver, and native
  control behavior.

## Routed references

Read [macOS engineering details](references/macos-app-engineering-details.md)
for the relevant implementation guidance:

| Request | Reference sections |
|---|---|
| SwiftUI composition/state and performance | SwiftUI composition and state; rendering |
| Settings pages/navigation/design system | Settings and design-system patterns |
| AppKit bridge, lifecycle, panels, capabilities | macOS platform integration and execution sequence |
| Previews and verification | Preview requirements and verification |
| Broad UI direction | UI/UX direction |

## Verification and handoff

Report the owning view/coordinator, reused components/tokens, availability and
accessibility behavior, preview/test commands, and known baseline failures.

## Related Skills

- `../apple-design/SKILL.md`
- `../swiftui-pro/SKILL.md`
- `../accessibility-audit/SKILL.md`

## References

- [Detailed macOS app guidance](references/macos-app-engineering-details.md)
