@preconcurrency import FluidAudio
import Foundation

// MARK: - Sendable Conformances for FluidAudio

// FluidAudio types are not yet marked as Sendable in the library,
// but they are designed to be used with Swift Concurrency and are
// internally thread-safe for their intended purpose.

extension AsrManager: @unchecked @retroactive Sendable {}
extension OfflineDiarizerManager: @unchecked @retroactive Sendable {}

// Note: DiarizationResult, OfflineDiarizerConfig, and TokenTiming
// are already Sendable in FluidAudio 0.12.x.
