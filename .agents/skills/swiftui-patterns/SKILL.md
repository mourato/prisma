---
name: swiftui-patterns
description: This skill should be used when the user asks to "build SwiftUI views", "improve state management", "refactor SwiftUI layouts", or "use design system components".
---

# SwiftUI Patterns

## Overview

Recommended patterns for SwiftUI development in the Prisma project.

## Mandatory Pairing

For macOS/iOS interface tasks, consult `../native-app-designer/SKILL.md` first to define UX/UI direction and acceptance criteria.
Then use this skill to implement view composition, state handling, and layout patterns.

## When to Use

Activate this skill when working with:
- State property wrappers (`@State`, `@StateObject`, `@ObservedObject`)
- Navigation (`NavigationStack`, `NavigationView`)
- SwiftUI views and modifiers
- View lifecycle and composition

Route to `swiftui-animation` when the task is primarily about advanced transitions, motion choreography, matched geometry, or shader-based effects.

## Reusable Components First

Before writing new UI code, treat the interface as reusable blocks:

- Search existing design-system/UI blocks first (`MACard`, `MAGroup`, `MAToggleRow`, `MACallout`, `MABadge`, `MAActionButton`, `MAThemePicker` and related components).
- Apply `reuse -> extend -> create`:
  - **Reuse** when an existing component already fits.
  - **Extend** when the component can absorb the variant without breaking existing usage.
  - **Create** only when the pattern is genuinely new or cannot be represented coherently by extension.
- Avoid copy-paste view composition for repeated visual structures.

## Key Concepts

### State Management

```swift
// ✅ CORRECT - @StateObject for owned reference types
class RecordingViewModel: ObservableObject {
    @Published var isRecording = false
}

struct RecordingView: View {
    @StateObject private var viewModel = RecordingViewModel()

    var body: some View {
        Button(action: viewModel.toggleRecording) {
            Text(viewModel.isRecording ? "Stop" : "Start")
        }
    }
}

// ❌ WRONG - @State for shared reference
struct BadView: View {
    @State private var sharedService = SharedService() // Violates ownership
}
```

### Navigation (iOS 16+)

Use `NavigationStack` for type-safe navigation:

```swift
// ✅ CORRECT - NavigationStack with typed path
struct AppNavigation: View {
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            HomeView()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .settings:
                        SettingsView()
                    case .detail(let id):
                        DetailView(id: id)
                    }
                }
        }
    }
}

enum Route: Hashable {
    case settings
    case detail(id: String)
}
```

## Common Patterns

### View Modifiers

Group related modifiers and extract common chains:

```swift
// Group related modifiers
Text("Title")
    .font(.title)
    .fontWeight(.bold)
    .foregroundColor(.primary)

// Extract common chains
extension View {
    func cardStyle() -> some View {
        self
            .padding()
            .background(Color(.windowBackgroundColor))
            .cornerRadius(8)
            .shadow(radius: 2)
    }
}
```

### Performance Optimization

```swift
// Lazy loading for large lists
LazyVStack {
    ForEach(recordings) { recording in
        RecordingRow(recording: recording)
    }
}

// Identity for views that need redraw
struct ContentView: View {
    @State private var items: [Item] = []

    var body: some View {
        List($items) { $item in
            ItemRow(item: $item)
        }
        .id(items.id) // Force redraw when ID changes
    }
}
```

## Settings UI Patterns

### Settings UX Consistency Checklist

- Use drill-down rows consistently for secondary settings pages.
- For any settings row that pushes a secondary page, reuse `SettingsDrillDownListRow` inside a `NavigationStack`, following the pattern in `EnhancementsSettingsTab` before creating a custom row wrapper.
- Keep row anatomy stable: title, optional short subtitle, disclosure indicator.
- Avoid repeating the same title or description in the page header and again in the first settings card unless the card introduces materially new context.
- Prefer inline descriptive copy for the page-level explanation. Reserve info popovers/tooltips for secondary guidance, edge cases, or optional workflows.
- If two or more info affordances appear in the same local cluster, consolidate them into one helper surface unless each serves a clearly distinct purpose.
- Ensure keyboard navigation works (Tab/Arrow/Enter/Escape) across rows and detail pages.
- Surface explicit loading/empty/success/warning states in dynamic settings blocks.
- Keep destructive actions visually separated from neutral actions.
- Pair row title/description semantics for VoiceOver and include clear accessibility hints.

### Design System

Use the project's Design System tokens/components to keep UI consistent and DRY:

- Tokens: `MeetingAssistantDesignSystem`
- Components: `MACard`, `MAGroup`, `MAToggleRow`, `MACallout`, `MABadge`, `MAActionButton`, `MAThemePicker`
- Always evaluate reusing/extending these components before introducing custom wrappers in feature views.
- Keyboard shortcut registration sections should use `MAShortcutSettingsSection` (instead of duplicating section layout). Keep a single consolidated helper affordance for shortcut context plus optional external remap guidance; do not stack multiple adjacent info popovers or repeat the same warning inline in each settings tab.

```swift
// Use MAGroup for labeled sections
MAGroup("Recording", icon: "recordingtape") {
    MAToggleRow(
        "Auto-start recording",
        description: "Optional description text",
        isOn: $viewModel.autoStart
    )
    
    Divider()
    
    // Additional content
}

// Use MACard for unlabeled containers
MACard {
    HStack {
        Text("Format")
        Spacer()
        Picker("", selection: $format) { ... }
    }
}
```

### Toggle vs Checkbox

**Always use toggles (switches) instead of checkboxes** when there is no separate "Save" button:

```swift
// ✅ CORRECT - Toggle for immediate-effect settings
MAToggleRow("Enable feature", isOn: $viewModel.isEnabled)

// ❌ WRONG - Checkbox for settings without explicit save
Toggle(isOn: $isEnabled) {
    Text("Enable feature")
}
.toggleStyle(.checkbox) // Misleading UX
```

##### Rationale
Checkboxes imply form-based interaction where changes are batched and saved together. Toggles communicate immediate effect, matching SwiftUI's two-way binding behavior.

### Left-Aligned Layouts

Settings content should be **left-aligned**, not centered:

```swift
// ✅ CORRECT - Left-aligned content
VStack(alignment: .leading, spacing: 20) {
    section1
    section2
}
.padding()
.frame(maxWidth: .infinity, alignment: .leading)

// ❌ WRONG - Centered content
VStack {
    section1
    section2
}
.padding()
// Default center alignment
```

### Compound Buttons with Dropdown

Create unified buttons with integrated dropdown using custom Menu:

```swift
HStack(spacing: 0) {
    // Main action button
    Button { onStart(.all) } label: {
        HStack(spacing: 8) {
            Image(systemName: "waveform")
            Text("Start Recording")
        }
        .frame(maxWidth: .infinity, height: 44)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    
    // Divider
    Rectangle()
        .fill(Color.white.opacity(0.3))
        .frame(width: 1, height: 24)
    
    // Dropdown with hidden indicator
    Menu {
        // Menu items
    } label: {
        Color.clear
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
    }
    .menuIndicator(.hidden)
    .overlay {
        Image(systemName: "chevron.down")
            .allowsHitTesting(false)
    }
}
.background(Color.blue)
.clipShape(Capsule())
```

## Common Pitfalls

1. **Shared state** - Use `@StateObject`, not `@State` for injection
2. **Old NavigationView** - Use `NavigationStack` on iOS 16+
3. **Deep nesting** - Extract subviews for clarity
4. **Bindings in loops** - Use `ForEach($items) { $item in }`
5. **Centered settings** - Use `.leading` alignment and `frame(maxWidth: .infinity, alignment: .leading)`
6. **Checkboxes for settings** - Use `SettingsToggle` or `.toggleStyle(.switch)`

## Preview Requirements

- Every SwiftUI `View` must include at least one `#Preview`.
- Add more than one preview when state variations are relevant.
- Keep previews deterministic and side-effect free.
- Use `PreviewRuntime.isRunning` for startup task suppression when needed.
- Use `PreviewStateContainer` when interactive bindings are required.
- Validate coverage with `make preview-check`.

## References

- [SettingsPage.swift](Packages/MeetingAssistantCore/Sources/UI/pages/settings/SettingsPage.swift)
- [TranscriptionStatusPage.swift](Packages/MeetingAssistantCore/Sources/UI/pages/transcription/TranscriptionStatusPage.swift)
- `.agents/skills/preview-coverage/SKILL.md`
