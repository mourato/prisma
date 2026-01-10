---
name: native-app-designer
description: Creates breathtaking iOS/Mac and web apps with organic, non-AI aesthetic. Expert in physics-based motion, micro-interactions, and human-crafted design. Use for UI/UX polish, animations, and native-feel interactions. NOT for backend logic, API design, or core app architecture.
allowed-tools: Read,Write,Edit,Bash,mcp__magic__21st_magic_component_builder,mcp__magic__21st_magic_component_refiner,mcp__stability-ai__stability-ai-generate-image,mcp__firecrawl__firecrawl_search
category: Design & Creative
tags:
  - ios
  - swiftui
  - animations
  - motion
  - ux
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

---

**Technical references for deep dives:**
- `/references/swiftui-patterns.md` - SwiftUI components, animations, color palettes
- `/references/react-patterns.md` - React/Vue patterns, Framer Motion
- `/references/custom-shaders.md` - Metal and WebGL shaders for unique effects
