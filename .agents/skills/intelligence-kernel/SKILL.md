---
name: intelligence-kernel
description: This skill should be used when the user asks to "change meeting post-processing", "work with canonical summary schema", "tune intelligence kernel modes", or "update summary benchmark gates".
---

# Intelligence Kernel

## Role

Operational guidance for the reusable intelligence kernel, canonical summary contract, and summary-quality regression gates.

## Scope Boundary

- Use this skill for intelligence-kernel contracts, mode routing, trust flags, and benchmark gates.
- Use `../data-persistence/SKILL.md` when the main concern is storage or migration rather than kernel behavior.
- Use `../quality-assurance/SKILL.md` when the main concern is command selection and verification policy.

## When to Use

Use this skill for:
- `IntelligenceKernelMode` routing changes (`meeting`, `dictation`, `assistant`)
- Canonical summary contract/schema updates
- Trust-flags validation behavior changes
- Summary benchmark thresholds, baseline, or gate mode updates
- Meeting post-processing and grounded Q&A changes that must remain mode-aware

## Canonical Contract Surface

Primary files:
- `Packages/MeetingAssistantCore/Sources/Domain/Models/IntelligenceKernel.swift`
- `Packages/MeetingAssistantCore/Sources/Domain/Models/CanonicalSummary.swift`
- `Packages/MeetingAssistantCore/Sources/AI/Services/Output/CanonicalSummaryPipeline.swift`

Canonical summary fields:
- `schemaVersion`, `generatedAt`, `summary`, `keyPoints`, `decisions`, `actionItems`, `openQuestions`, `trustFlags`

Trust flags:
- `isGroundedInTranscript`
- `containsSpeculation`
- `isHumanReviewed`
- `confidenceScore` (`0...1`)

Validation invariants:
- `schemaVersion` must be within `1...CanonicalSummary.currentSchemaVersion`
- `summary` must be non-empty after trimming
- list entries (`keyPoints`, `decisions`, `openQuestions`) cannot contain empty strings
- each `actionItems.title` must be non-empty
- `trustFlags.confidenceScore` must be in `0...1`

## Mode Gating and Rollout

Gate behavior through feature flags and settings adapters:
- `FeatureFlags.enableIntelligenceKernel`
- `FeatureFlags.enableMeetingIntelligenceMode`
- `FeatureFlags.enableDictationIntelligenceMode`
- `FeatureFlags.enableAssistantIntelligenceMode`
- `AppSettingsStore.intelligenceKernelEnabled`
- `AppSettingsStore.isIntelligenceKernelModeEnabled(_:)`

Rule: call sites should stay on shared kernel contracts and avoid mode-specific branching in UI surfaces.

## Benchmark and Regression Gates

Commands:

```bash
make benchmark-summary
make benchmark-summary-agent
./scripts/run-summary-benchmark.sh --enforce
./scripts/run-summary-benchmark.sh --report-only --record-baseline
```

Gate control:
- `MA_SUMMARY_BENCHMARK_GATE_MODE=report-only` (default)
- `MA_SUMMARY_BENCHMARK_GATE_MODE=enforce`

Artifacts:
- Fixtures: `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/Resources/Benchmarks/summary-benchmark-fixtures.v1.json`
- Baseline: `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/Resources/Benchmarks/summary-benchmark-baseline.v1.json`
- Result: `/tmp/summary-benchmark-result.v1.json` (or `/tmp/ma-agent/summary-benchmark-result.v1.json` in agent mode)

## Change Checklist

1. Apply `reuse -> extend -> create` before adding new kernel-specific abstractions.
2. If schema changes, update `CanonicalSummary.currentSchemaVersion` and persistence compatibility.
3. Keep fallback/repair flows deterministic; avoid introducing non-deterministic parser behavior.
4. Add/adjust tests in kernel contracts, persistence validation, and benchmark regression suites.
5. Run `make build-test`; for rubric changes, run benchmark commands.

## Routing

- Cross-module API boundary decisions -> `../architecture/SKILL.md`
- Persistence and migration impact -> `../data-persistence/SKILL.md`
- Validation gates and test strategy -> `../quality-assurance/SKILL.md`

## 2026-03-04 Progression Drill

### New Evidence

- `0d986f8` introduced per-transcription model selection and conversation-state persistence.
- Changes spanned AI/Data/Domain/UI and tests (`MeetingQAServiceTests`, `IntelligenceKernelContractsTests`).

### Skill Deepening Focus

1. Add explicit invariants for model-selection persistence lifecycle (create, reload, edit, delete).
2. Define schema-safe fallback behavior when conversation state is missing/partial.
3. Require contract-test updates whenever kernel-facing persistence fields change.
4. Keep post-processing prompts mode-aware while preserving canonical contract output.

## 2026-06-19 Progression Drill

### New Evidence

- `13193664` refactored transcription provider selection and retry logic around `TranscriptionProviderSelection`.
- Recent retry work established that history retry options must be segmented by `capturePurpose` and must hide providers/models that are not fully configured.
- Product decision: meeting retries remain local-only until the meeting configuration model explicitly supports remote providers.

### Skill Deepening Focus

1. Use provider-selection domain values across UI, recording, and transcription clients; avoid raw model strings for retry or mode-aware flows.
2. Keep meeting and dictation retry surfaces aligned with their real configuration models, not with a global provider list.
3. Filter history actions by readiness before display: installed local models, valid remote API keys, and capture-purpose compatibility.
4. Add contract tests when provider-selection overrides cross AI/Data/UI boundaries or can affect post-processing metrics.

## 2026-07-01 Progression Drill

### New Evidence

- `a62d4a8e` added `AIPromptTemplates.requestPrompts(...)` so request-time and snapshot prompt assembly share the same resolver.
- `a62d4a8e` introduced a simple-model dictation strategy for `gpt-oss-120b` that only applies to dictation with the default prompt; Flex and custom prompts keep advanced instructions.
- `PromptServiceTests` now assert mode-specific prompt behavior: dictation avoids meeting language, simple dictation uses `<TRANSCRIPT>`, meeting keeps `<TRANSCRIPTION>`, and existing context metadata is not duplicated.

### Skill Deepening Focus

1. Route prompt assembly through the shared request resolver whenever mode, selected model, context metadata, or prompt type can affect output.
2. Keep simple-model optimizations tightly scoped by mode and prompt identity; do not weaken meeting or custom-prompt contracts to help one local model.
3. Preserve context metadata as disambiguation only, and test that tagged context is not duplicated in request bodies.
4. Pair prompt-template edits with focused prompt tests before broader AI or post-processing checks.
