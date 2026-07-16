---
name: apple-design
description: Apple's approach to interface design, fluid movement and physics — translated to Swift and SwiftUI/AppKit for Prisma. Use for gesture-oriented UI, spring animations, sheets, materials, typography metrics, or Apple-style interaction fundamentals.
---

# Apple Design

## Role

Own interaction *feel*: motion, material, depth, typography metrics, and
feedback principles that make Prisma's SwiftUI/AppKit surfaces feel native.

## Scope Boundary

Exclusive claim: gesture/spring physics, interruptibility, velocity handoff,
materials/depth as hierarchy, and typography *metrics* (tracking/leading/
Dynamic Type–aware layout recipes).

Not owned here:

- Ordinary view/Settings/DS/preview/AppKit lifecycle → `macos-app-engineering`
- Accessibility *audit* pass/fail (VoiceOver, keyboard/focus, Reduce Motion
  compliance) → `accessibility-audit`
- SwiftUI modern-API review checklist → `macos-app-engineering`
  (`../macos-app-engineering/references/swiftui-review.md`)

## When to Use

Trigger for drag/swipe/sheet interactions, spring or momentum animation, press
feedback, material/depth changes, typography metrics (tracking/leading/scaled
layout recipes), or an Apple-style visual/interaction critique.

For Reduce Motion or Dynamic Type **audits**, start with `accessibility-audit`;
use this skill for the motion/type *implementation recipes* those audits
require.

## Non-negotiable rules

- Every motion path must have a meaningful Reduce Motion behavior.
- Preserve spatial continuity, interruptibility, and direct manipulation where
  the user expects 1:1 tracking.
- Use Dynamic Type-compatible metrics and preserve readable hierarchy when
  scaling or typography changes.
- Keep feedback multimodal and restrained; do not stack redundant copy, sound,
  haptics, and animation for one state change.
- Keep platform availability and native macOS behavior explicit.

## Routed references

Read [Apple design details](references/apple-design-details.md) only when the
request needs the corresponding deep guidance:

| Request | Reference sections |
|---|---|
| Drag, swipe, sheet, spring, momentum, or interruptible transitions | Response through rubber-banding; gesture feel checklist |
| Materials, depth, feedback, or haptics | Materials, multimodal feedback, design fundamentals |
| Reduce Motion implementation recipes | Reduce Motion and accessibility (then audit via `accessibility-audit`) |
| Dynamic Type, tracking, leading, or scaled layout | Typography |
| End-to-end interaction critique | Process and quick reference |

## Verification and handoff

Report the interaction contract, Reduce Motion behavior, affected surfaces,
reusable tokens/components, and focused preview/test or visual evidence. Keep
motion constants centralized in the existing design system; extend before
creating a local animation vocabulary.

## Related Skills

- `../macos-app-engineering/SKILL.md`
- `../accessibility-audit/SKILL.md`
- `../swift-conventions/SKILL.md`

## References

- [Detailed Apple design guidance](references/apple-design-details.md)
