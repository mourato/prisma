# Summary Benchmark Framework (Axis 101)

## Purpose

This framework establishes deterministic benchmark and regression gates for summary quality.

It is designed to validate the stability of the canonical summary pipeline introduced in issues #99 and #100, and to provide objective quality gates for subsequent intelligence changes (including #103 and beyond).

## Scope

- Deterministic fixture-driven benchmark inputs (no live provider dependency)
- Rubric scoring over canonical summary output quality
- Versioned baseline and result artifacts
- Regression gate modes:
  - `report-only` (non-blocking)
  - `enforce` (blocking on threshold/baseline regressions)

## Artifacts

Fixture dataset (versioned):

- `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/Resources/Benchmarks/summary-benchmark-fixtures.v1.json`

Baseline artifact (versioned):

- `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/Resources/Benchmarks/summary-benchmark-baseline.v1.json`

Run result artifact:

- Default: `/tmp/summary-benchmark-result.v1.json`
- Agent mode: `/tmp/ma-agent/summary-benchmark-result.v1.json`

## Rubric (v1)

Higher is better unless noted:

- `schemaValidityRate >= 1.00`
- `summaryTokenF1 >= 0.85`
- `keyPointsF1 >= 0.80`
- `decisionsF1 >= 0.80`
- `actionItemsTitleF1 >= 0.75`
- `openQuestionsF1 >= 0.75`
- `trustFlagsAccuracy >= 0.90`
- `hallucinationRate <= 0.15` (lower is better)

## Commands

Run report-only benchmark:

```bash
make benchmark-summary
```

Run report-only benchmark in compact agent mode:

```bash
make benchmark-summary-agent
```

Run enforce mode directly:

```bash
./scripts/run-summary-benchmark.sh --enforce
```

Record baseline from current benchmark run:

```bash
./scripts/run-summary-benchmark.sh --report-only --record-baseline
```

## Preflight Integration

`preflight` includes the summary benchmark gate.

Mode is controlled by environment variable:

- `MA_SUMMARY_BENCHMARK_GATE_MODE=report-only` (default)
- `MA_SUMMARY_BENCHMARK_GATE_MODE=enforce`

Examples:

```bash
make preflight-agent
MA_SUMMARY_BENCHMARK_GATE_MODE=enforce make preflight-agent
```

## Two-Phase Rollout

1. Bootstrap phase:
   - Run benchmark in `report-only`
   - Record and commit baseline (`--record-baseline`)
2. Enforcement phase:
   - Switch gate mode to `enforce` in CI/preflight
   - Fail on threshold breaches or baseline regressions

## Known constraint

Historical pre-#103 baseline is not reconstructed in this axis.

The v1 baseline is anchored on the current `main` state at implementation time.
