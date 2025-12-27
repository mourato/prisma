# Project Best Practices

## High-Performance Audio (Real-Time)

### Zero Allocation Policy
- **Rule**: Do not allocate memory (Classes, Arrays, Strings) inside the audio render callback (`AVAudioSourceNode`, `Process Tap`).
- **Why**: Allocations can trigger locks or garbage collection, causing audio dropouts (glitches).
- **Solution**: Pre-allocate buffers (e.g., Ring Buffer) during initialization.

### Efficient Copying
- **Rule**: Avoid manual `for` loops for copying audio samples between buffers.
- **Solution**: Use `memcpy` via `UnsafeMutableBufferPointer` to move memory blocks efficiently.
- **Risk**: Requires strict bounds checking (`min(source.count, dest.count)`) to prevent buffer overflows.

## Concurrency

### Lock Safety
- **Rule**: NEVER use `NSLock` or `@MainActor` inside a real-time audio callback.
- **Solution**: Use `OSAllocatedUnfairLock` (Spinlock equivalent) which blocks for nanoseconds rather than milliseconds.
- **Reference**: `SystemAudioRecorder.CallbackStorage`.

### Sendable Closure Protocol
- **Rule**: Closures passed between threads (especially for callbacks) MUST be marked `@Sendable`.
- **Why**: Ensures compiler verification of thread safety and prevents capturing mutable non-thread-safe state.
