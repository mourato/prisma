---
name: macos-design-guidelines
description: Apple Human Interface Guidelines for Mac. Use when building macOS apps with SwiftUI or AppKit, implementing menu bars, toolbars, window management, or keyboard shortcuts. Triggers on tasks involving Mac UI, desktop apps, or Mac Catalyst.
license: MIT
metadata:
  author: platform-design-skills
  version: "1.0.0"
---

# macOS Human Interface Guidelines

## Role

Use this skill as the canonical owner for macOS Human Interface Guidelines interpretation in Prisma.

- Own native interaction quality guidance for menus, windows, shortcuts, toolbars, and desktop conventions.
- Translate Apple HIG expectations into actionable rules for this repository.
- Delegate implementation mechanics and broader UX direction to their specialist owners.

## Scope Boundary

- Use this skill for HIG alignment and macOS-native interaction guidance.
- Use `../macos-development/SKILL.md` for concrete implementation details.
- Use `../native-app-designer/SKILL.md` for broader experience direction beyond HIG compliance.

## When to Use

Use this skill when building macOS apps with SwiftUI or AppKit, implementing menu bars, toolbars, window management, or keyboard shortcuts.

Mac apps serve power users who expect deep keyboard control, persistent menu bars, resizable windows, and tight system integration. Use this skill as the fast HIG checklist, not as a long pattern library.

## Critical Rules

### Menu bar and commands

- Keep standard menus intact when applicable: App, Edit, View, Window, Help, plus File for document-oriented flows.
- Keep command names stable and discoverable.
- Use standard shortcuts for standard actions.
- Keep Settings available from the App menu with `Cmd+,`.

### Windows and layout

- Main windows should be resizable with sensible minimum sizes.
- Respect fullscreen, minimize, zoom, and state restoration expectations.
- Do not create duplicate primary windows that split ownership of the same workflow.

### Toolbars, sidebars, and popovers

- Keep toolbars focused on primary actions.
- Use sidebars for stable navigation, not dense action clusters.
- Use popovers for transient contextual content, not primary multi-step workflows.

### Visual chrome

- Prefer system materials, fonts, and spacing rhythms over custom chrome.
- Avoid decorative layering that reduces clarity or performance.
- Respect Dark Mode, accent color, Reduce Motion, and Reduce Transparency.

### Accessibility

- Every interactive element needs an accessibility label or equivalent semantic role.
- Full keyboard access must remain usable on changed surfaces.
- Focus order should match the visible hierarchy.

## Review Checklist

Check these before shipping or approving a UI change:

- menu path and shortcut are discoverable
- resize/fullscreen/minimize behavior remains native
- no redundant affordances are competing in the same viewport
- toolbar and sidebar roles are clear
- popovers are transient and contextual
- reduced-motion and full-keyboard paths remain usable
- custom chrome is justified instead of decorative

## Related Skills

- `../native-app-designer/SKILL.md`
- `../macos-development/SKILL.md`
- `../menubar/SKILL.md`
- `../accessibility-audit/SKILL.md`

## References

- [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
