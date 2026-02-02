---
trigger: always_on
---

# Audio Real-Time Constraints

## Critical Policy

When working with audio recording, AVAudioEngine, AVAudioSourceNode, or real-time audio processing:

**NEVER allocate memory inside audio callbacks** - No Classes, Arrays, Strings, or Closures in render callbacks.

**NEVER use NSLock or @MainActor** in audio callbacks - Only use `OSAllocatedUnfairLock`.

**ALWAYS mark audio callbacks @Sendable** - Closures between threads must be `@Sendable`.

## Comprehensive Guidance

For complete patterns, architecture, and examples, see:
- **[audio-realtime skill](.agent/skills/audio-realtime/SKILL.md)** - Complete audio subsystem architecture and constraints