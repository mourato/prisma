# SwiftUI Patterns

> **Skill Condicional** - Ativada quando trabalhando com SwiftUI views

## Visão Geral

Padrões recomendados para desenvolvimento SwiftUI no Meeting Assistant.

## Quando Usar

Ative esta skill quando detectar:
- `@State`, `@StateObject`, `@ObservedObject`
- `NavigationStack`, `NavigationView`
- `View`, `some View`
- `body: some View`
- SwiftUI modifiers

## Conceitos-Chave

### State Management

```swift
// ✅ CORRETO - @StateObject para owned reference types
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

// ❌ ERRADO - @State para referência compartilhada
struct BadView: View {
    @State private var sharedService = SharedService() // Viola ownership
}
```

### Navigation (iOS 16+)

```swift
// ✅ CORRETO - NavigationStack com typed path
struct AppNavigation {
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

## Patterns Comuns

### View Modifiers

```swift
// Agrupar modifiers relacionados
Text("Title")
    .font(.title)
    .fontWeight(.bold)
    .foregroundColor(.primary)

// Extrair cadeia comum
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

### Performance

```swift
// Lazy loading para listas grandes
LazyVStack {
    ForEach(recordings) { recording in
        RecordingRow(recording: recording)
    }
}

// Identificação para views que precisam redraw
struct ContentView: View {
    @State private var items: [Item] = []

    var body: some View {
        List($items) { $item in
            ItemRow(item: $item)
        }
        .id(items.id) // Força redraw quando ID muda
    }
}
```

## Armadilhas Comuns

1. **State compartilhado** - Use `@StateObject`, não `@State` para injeção
2. **NavigationView antigo** - Use `NavigationStack` no iOS 16+
3. **Aninhamento profundo** - Extraia subviews
4. **Bindings em loops** - Use `ForEach($items) { $item in }`

## Referências

- [SettingsView.swift](Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Views/Settings/SettingsView.swift)
- [TranscriptionListView.swift](Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Views/TranscriptionListView.swift)
