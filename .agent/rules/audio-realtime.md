---
trigger: always_on
---

# Audio Real-Time Constraints

## Zero Allocation Policy (CRITICAL)
- **Constraint**: NEVER allocate memory (Classes, Arrays, Strings, Closures) inside the audio render callback (`AVAudioSourceNode`, `process()`).
- **Reason**: Allocations can trigger GC or locks, causing audio glitches/pops.
- **Action**: Use pre-allocated buffers (Ring Buffers, UnsafeMutablePointer).

## Lock Safety
- **Constraint**: NEVER use `NSLock`, `@MainActor`, or `await` inside the audio callback.
- **Allowed**: Only use `OSAllocatedUnfairLock` (or `os_unfair_lock`) for synchronization.

## Memory Copying
- **Constraint**: Avoid manual loops for copying samples.
- **Action**: Use `memcpy` via `UnsafeMutablebufferPointer.copyMemory`.