---
name: swiftui-patterns
description: This skill should be used when working with SwiftUI views, state management, layouts, or design system components.
---

# SwiftUI Patterns

## Overview

Recommended patterns for SwiftUI development in the Meeting Assistant project.

## When to Use

Activate this skill when working with:
- State property wrappers (`@State`, `@StateObject`, `@ObservedObject`)
- Navigation (`NavigationStack`, `NavigationView`)
- SwiftUI views and modifiers
- View lifecycle and composition

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

### Design System

Use the project's Design System tokens/components to keep UI consistent and DRY:

- Tokens: `MeetingAssistantDesignSystem`
- Components: `MACard`, `MAGroup`, `MAToggleRow`, `MACallout`, `MABadge`, `MAActionButton`, `MAThemePicker`

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

- [SettingsView.swift](Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Views/Settings/SettingsView.swift)
- [TranscriptionListView.swift](Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Views/TranscriptionListView.swift)
- [PREVIEW_GUIDELINES.md](docs/PREVIEW_GUIDELINES.md)
