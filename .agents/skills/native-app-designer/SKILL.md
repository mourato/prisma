---
name: native-app-designer
description: This skill should be used when the user asks to "redesign native UI", "improve visual hierarchy", "apply glassmorphism", or "craft high-fidelity motion design" for macOS/iOS.
---

# Native App Designer

Elite native app designer specializing in breathtaking, human-centered applications that feel organic and alive—never generic or AI-generated.

## When to Use This Skill

✅ **Use for:**
- Physics-based motion design and micro-interactions
- App onboarding flows with personality
- Custom shader effects (Metal/WebGL)
- Component library design with character
- Polishing UI to feel "premium" and "native"

❌ **Do NOT use for:**
- Core app architecture → use **macos-development**
- Backend API logic → use **backend-architect**
- Simple static websites → use **web-design-expert**

## Common Anti-Patterns

### Anti-Pattern: Generic Card Syndrome
**What it looks like**: Every component is a white card with shadow.
**What to do instead**: Mix layouts—cards, lists, grids, overlays, inline elements.

### Anti-Pattern: Linear Animation Death
**What it looks like**: `.animation(.linear(duration: 0.3))`
**What to do instead**: Use spring physics with response/damping parameters.

### Anti-Pattern: Animation Overload
**What it looks like**: Everything bounces, slides, and fades constantly.
**What to do instead**: Animate intentionally—guide attention, provide feedback.

## Design Philosophy: Beyond Generic

### What Makes Apps Look "AI-Generated" (AVOID)
- ❌ Perfectly centered everything with no visual rhythm
- ❌ Generic gradients (linear purple-to-blue everywhere)
- ❌ Oversized, ultra-rounded corners on everything
- ❌ Soulless animations (generic slide-in-from-bottom)

### What Makes Apps Feel Human-Crafted (DO THIS)
- ✅ **Asymmetry with purpose**: Break the grid intentionally
- ✅ **Organic motion**: Physics-based animations, spring dynamics
- ✅ **Textural elements**: Subtle noise, gradients with character
- ✅ **Emotional color**: Palettes that evoke feeling

## Motion Design Principles

### Spring Physics Cheat Sheet
```swift
// Snappy, responsive
.spring(response: 0.3, dampingFraction: 0.7)

// Bouncy, playful
.spring(response: 0.5, dampingFraction: 0.5)

// Smooth, elegant
.spring(response: 0.6, dampingFraction: 0.8)
```

### Animation Timing
- **Immediate feedback**: 0-100ms (button press)
- **Quick transitions**: 150-300ms (page change)
- **Deliberate animations**: 300-500ms (onboarding)

## Platform-Specific Best Practices

### iOS/macOS Native
- Use system materials (.ultraThinMaterial, .regularMaterial)
- Respect safe areas and Dynamic Island
- Support Dynamic Type (accessibility)
- Use SF Symbols with weight matching
- Support dark mode with semantic colors

## macOS Glassmorphism Patterns

### Floating Indicators

Create floating UI elements using capsule shapes with material blur:

```swift
HStack(spacing: 8) {
    recordingDot
    waveformCanvas
}
.padding(.horizontal, 16)
.padding(.vertical, 8)
.background(.ultraThinMaterial)
.clipShape(Capsule())
.shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
```

### Shadow Guidelines
- **Floating elements**: `color: .black.opacity(0.15), radius: 8, x: 0, y: 4`
- **Subtle cards**: `color: .black.opacity(0.1), radius: 4, x: 0, y: 2`
- **Elevated panels**: `color: .black.opacity(0.2), radius: 12, x: 0, y: 6`

### Pulsing Active State

Use subtle pulsing to indicate active/recording states:

```swift
struct PulsingModifier: ViewModifier {
    @State private var isPulsing = false
    
    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 0.5 : 1.0)
            .scaleEffect(isPulsing ? 0.85 : 1.0)
            .animation(
                .easeInOut(duration: 0.8)
                    .repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear { isPulsing = true }
    }
}

// Usage
Circle()
    .fill(Color.red)
    .frame(width: 8, height: 8)
    .modifier(PulsingModifier())
```

### Waveform Visualization Styles

Two styles for audio visualization:
- **Classic**: Full waveform canvas (use DSWaveformImageViews or custom)
- **Mini**: Simplified animated bars

```swift
// Mini bars - simplified visualization
HStack(spacing: 2) {
    ForEach(0..<7, id: \.self) { index in
        RoundedRectangle(cornerRadius: 1)
            .fill(Color.white)
            .frame(width: 2, height: barHeight(for: index))
            .animation(.easeOut(duration: 0.08), value: amplitude)
    }
}
```

## Window Layer Patterns

### Always-Visible Overlays

For floating indicators that must appear above all windows (including fullscreen apps):

```swift
// Use NSPanel with high window level
let panel = NSPanel(...)
panel.level = .screenSaver  // Above Status Bar, works in fullscreen
panel.styleMask = [.borderless, .nonactivatingPanel]
panel.isOpaque = false
panel.backgroundColor = .clear
panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
```

**Window Level Reference** (lowest to highest):
1. `.normal` - Standard windows
2. `.floating` - Utility panels
3. `.statusBar` - Status bar level
4. `.modalPanel` - Modal dialogs
5. `.screenSaver` - ⭐ Use for always-visible indicators

---

**Technical references for deep dives:**
- [FloatingRecordingIndicatorView.swift](Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Views/Components/FloatingRecordingIndicatorView.swift)
- [RecordingButton.swift](Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Views/Components/RecordingButton.swift)
- [MeetingAssistantDesignSystem.swift](Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/DesignSystem/MeetingAssistantDesignSystem.swift)
- [DesignSystem Components](Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/DesignSystem/Components/)
