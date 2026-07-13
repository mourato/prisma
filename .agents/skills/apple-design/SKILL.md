---
name: apple-design
description: Apple's approach to interface design, fluid movement and physics — translated to Swift, SwiftUI and UIKit. Use for gesture-oriented UI, spring animations, sheets, materials, typography, Dynamic Type, Reduce Motion, or Apple-style interaction fundamentals.
---

# Apple Design

## Role

Own the interaction, motion, material, depth, typography, and feedback
principles that make Prisma's SwiftUI/AppKit surfaces feel native.

## Scope Boundary

Use this skill for gesture-oriented UI, interruptible transitions, translucent
materials, typography/scaled layout, accessibility-aware motion, and the design
reasoning behind those behaviors. Use `macos-app-engineering` for ordinary view
ownership, lifecycle, settings, previews, and AppKit bridging.

## When to Use

Trigger for drag/swipe/sheet interactions, spring or momentum animation, press
feedback, material/depth changes, Dynamic Type or tracking/leading work, Reduce
Motion behavior, or an Apple-style visual/interaction review.

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
| Reduce Motion or accessibility review | Reduce Motion and accessibility; design fundamentals |
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
- `../swiftui-pro/SKILL.md`

## References

- [Detailed Apple design guidance](references/apple-design-details.md)
