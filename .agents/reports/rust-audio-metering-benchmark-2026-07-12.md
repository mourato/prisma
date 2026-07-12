# Rust audio metering benchmark — 2026-07-12

## Scope

Compared `SwiftEnergyMeterKernel` with `RustEnergyMeterKernel` for a mono
4,096-frame buffer at 48 kHz and 16 waveform bars. The Rust path now passes an
`UnsafeBufferPointer<Float>` directly to the FFI and computes bars only after a
successful Rust RMS/peak result.

## Result

`make test-perf` passed all 12 selected performance tests, including the three
metering measurements:

| Path | XCTest wall-clock average | Relative standard deviation |
| --- | ---: | ---: |
| Swift baseline | 0.002 s | 14.520% |
| Rust pilot with injected FFI | 0.002 s | 41.879% |
| Rust pilot with staged dylib | 0.001 s | 6.825% |

The values are local XCTest wall-clock measurements and are rounded by the
test runner. They are not a stable cross-machine performance guarantee.

## Decision

Keep `FeatureFlags.enableRustAudioMathKernels` set to `false`. The no-copy
boundary and parity checks are now in place, but this single local run is not
enough to accept runtime risk or claim a production-level CPU/allocation win.
The next useful Rust kernel remains bar-level computation, which would remove
the remaining Swift scan from the Rust success path.
