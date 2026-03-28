@preconcurrency import FluidAudio
import Foundation

// MARK: - Sendable Conformances for FluidAudio

// FluidAudio checkouts are patched before supported builds/tests so
// AsrManager carries its unchecked Sendable conformance in-module.
extension OfflineDiarizerManager: @unchecked @retroactive Sendable {}

// Note: DiarizationResult, OfflineDiarizerConfig, and TokenTiming
// are already Sendable in FluidAudio 0.12.x.
