---
name: SwiftUI Patterns
description: This skill should be used when working with SwiftUI views, "@State", "@StateObject", "@ObservedObject", "NavigationStack", view modifiers, or SwiftUI-specific patterns and best practices.
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

## Common Pitfalls

1. **Shared state** - Use `@StateObject`, not `@State` for injection
2. **Old NavigationView** - Use `NavigationStack` on iOS 16+
3. **Deep nesting** - Extract subviews for clarity
4. **Bindings in loops** - Use `ForEach($items) { $item in }`

## References

- [SettingsView.swift](Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Views/Settings/SettingsView.swift)
- [TranscriptionListView.swift](Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Views/TranscriptionListView.swift)
