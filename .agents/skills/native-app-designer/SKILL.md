---
name: native-app-designer
description: This skill should be used when the user asks to "design or redesign macOS/iOS interface", "improve user experience", "analyze UI/UX quality", or "define visual/motion direction". For macOS/iOS UI work, consult this skill first.
---

# Native App Designer (Primary UI/UX Reference)

## Role

Use this as the primary UI/UX reference for Apple-platform interfaces.

For this repository (macOS app), consult this skill whenever the task includes:

- UI implementation changes
- UX analysis or review
- Visual hierarchy, spacing, typography, color direction
- Interaction and motion behavior
- Interface quality improvements and polish

## Scope Boundary

- This skill owns visual/interaction direction and UX quality criteria.
- This skill complements implementation-oriented skills:
  - `../swiftui-patterns/SKILL.md` for SwiftUI composition/state/layout
  - `../swiftui-animation/SKILL.md` for advanced motion mechanics
  - `../swiftui-performance-audit/SKILL.md` for runtime render/update performance
  - `../macos-development/SKILL.md` for platform integration and lifecycle

## Mandatory Consultation Rule (macOS/iOS)

When the stack is macOS and/or iOS and the task touches interface or user experience, load this skill before implementation.

Use this sequence:

1. `native-app-designer` -> define UX/UI direction and acceptance criteria.
2. `swiftui-patterns` or `macos-development` -> implement structure and platform behavior.
3. `swiftui-animation` / `swiftui-performance-audit` -> refine motion and runtime quality when needed.

## UX/UI Review Checklist

1. **Clarity**: Primary actions and hierarchy are obvious within 3 seconds.
2. **Consistency**: Uses project design-system components/tokens before custom wrappers.
3. **Native Feel**: Interactions align with macOS/iOS conventions.
4. **Accessibility**: Labels, contrast, and reduced-motion paths are covered.
5. **Motion Quality**: Animation supports comprehension, not decoration.
6. **Visual Rhythm**: Spacing/typography form clear grouping and scanning flow.

## Practical Guidelines

- Prefer semantic colors/materials and design-system tokens over hardcoded values.
- Avoid generic, repetitive layouts that flatten hierarchy.
- Use motion to guide attention and communicate state changes.
- Keep reduced-motion behavior available for motion-heavy transitions.
- For macOS surfaces, use AppKit bridging only when SwiftUI behavior is insufficient.

## Routing

- Need concrete SwiftUI state/layout patterns -> `../swiftui-patterns/SKILL.md`
- Need advanced transition/shader choreography -> `../swiftui-animation/SKILL.md`
- Need runtime performance diagnosis for jank/layout thrash -> `../swiftui-performance-audit/SKILL.md`
- Need broader platform lifecycle/integration decisions -> `../macos-development/SKILL.md`
