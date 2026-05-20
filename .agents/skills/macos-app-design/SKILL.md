---
name: macos-app-design
description: Use when designing or building native macOS applications with SwiftUI or AppKit. Triggers on menu bar structure, keyboard shortcuts, multi-window behavior, Liquid Glass design system, macOS Tahoe/Sequoia, sidebar navigation, toolbar design, app icons, SF Symbols, or making an app feel like a "good Mac citizen."
---

# macOS App Design & Development

Guide for designing and implementing native-feeling, "good Mac citizen" apps: fast, elegant, accessible, and deeply integrated with macOS workflows.

## Two Rules That Beat Everything Else

1. **Prefer system components and conventions** over bespoke UI—fastest path to "feels right on Mac"
2. **If you customize bars, backgrounds, borders, or control chrome**: stop and justify it

## Quick Reference: Mac Citizen Checklist

| Area | Requirement |
|------|-------------|
| **Menu Bar** | Standard layout (App/File/Edit/View/Window/Help), ⌘, for Settings |
| **Keyboard** | Every primary command reachable via keyboard, standard shortcuts work |
| **Windows** | Resize fluidly, support multiple windows, respect fullscreen/minimize |
| **Sidebars** | Top-level navigation, scannable items, content extends behind |
| **Toolbars** | Group by function/frequency, demote secondary to "more" menu |
| **Text** | Use system text components, standard editing behaviors |
| **Accessibility** | VoiceOver labels, full keyboard navigation, Reduced Motion support |

## Liquid Glass Quick Rules

**Do:**
- Use for navigation/controls layer (toolbars, sidebars, bars)
- Let system components provide built-in behaviors

**Don't:**
- Apply to content layer (tables, lists, document content)
- Stack "glass on glass"

## App Archetypes

Identify your app type first:
- **Document-based**: Files as primary units (open/save/duplicate)
- **Library + editor**: Sidebar lists items, detail in main area
- **Utility**: Single window, optional menu bar
- **Menu-bar app**: Lives in menu bar, minimal UI
- **Pro tool**: Dense, power-user workflows

## Deliverables Before Building

1. **App archetype** identified
2. **Information architecture** (sidebar structure, navigation, window model)
3. **Command map** (menus + keyboard shortcuts for every major feature)
4. **State + data model** (persistence, undo/redo, concurrency)
5. **Accessibility plan** (VoiceOver, keyboard, contrast, reduce motion)

## Prisma Window Strategy (Decision Record)

Prisma follows a hybrid utility model:

- Keep one canonical primary application window per workflow surface (for example, Settings as a single source of truth)
- Allow focused auxiliary windows only when detached context materially improves flow (onboarding, transient overlays, or specialized tool surfaces)
- Avoid multiplying equivalent primary windows that duplicate navigation state and increase command ambiguity

Decision criteria for opening a new window:

- Required for side-by-side comparison of independent user contexts
- Required for long-running detached tasks that should survive navigation changes
- Otherwise, prefer in-window navigation, split view, sheet, or popover

Execution constraints:

- Every auxiliary window must remain fully keyboard operable and resizable when content can benefit from resize
- Preserve standard window controls, fullscreen behavior, and state restoration expectations
- Commands and shortcuts must target stable, predictable window ownership

## Recurring macOS Design Audit Checklist

Run this checklist before release and whenever navigation or window behavior changes.

1. Menu and shortcuts
- Standard menu groups remain intact and discoverable
- No shortcut collisions with system-reserved combinations
- Settings remains reachable via App menu and Cmd+Comma

2. Window model and behavior
- Primary window strategy still matches the hybrid policy above
- No accidental duplicate primary windows introduced
- Resize, minimize, fullscreen, and reopen behaviors remain native

3. Sidebar and navigation affordances
- No redundant affordances in the same viewport without distinct value
- Sidebar can always be restored via command path when hidden
- Navigation state transitions stay predictable during back/forward flows

4. Accessibility and motion
- VoiceOver order and labels verified on changed surfaces
- Decorative-only icons are hidden from accessibility tree
- Reduced Motion and Reduced Transparency paths remain usable

5. Visual chrome discipline
- Navigation chrome uses system material before custom effects
- Custom titlebar/background styling is justified and minimal
- No stacked decorative layers that reduce clarity or performance

## Full Reference

For complete design system details, Icon Composer workflow, SF Symbols guidance, evaluation rubrics, and Definition of Done checklist:

See: [references/macos-design-guide.md](references/macos-design-guide.md)

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Missing menu bar commands | Every feature in menus with keyboard shortcuts |
| Settings outside App menu | Always ⌘, opening from App menu |
| Custom text components | Use system text for Mac editing ecosystem |
| Toolbar overload | Demote secondary actions, group by function |
| Glass on content | Reserve Liquid Glass for navigation layer only |
| Breaking standard shortcuts | Never override ⌘C, ⌘V, ⌘Z, etc. |
| Single-window only | Support multiple windows when it benefits workflows |
