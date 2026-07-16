# Plan 050: Design an opt-in live provider drift benchmark

> **Executor instructions**: This is a design/CI spike. Do not add credentials, live provider secrets, or blocking production gates. Any code or CI change requires thermo review and security review.
>
> **Drift check**: `git diff --stat 80ed5788..HEAD -- .agents/reports Packages/MeetingAssistantCore/Tests scripts .github .agents/docs plans/README.md`

## Status

- **Priority**: P3
- **Effort**: M
- **Risk**: HIGH
- **Depends on**: plans/039-align-swift6-concurrency-baseline.md
- **Category**: tests
- **Planned at**: commit `80ed5788`, 2026-07-12
- **Related issue**: #107

## Why this matters

The summary benchmark is intentionally fixture-only. That gives deterministic local regression coverage but cannot detect provider-side format or behavior drift. A live lane could be useful, but it must remain opt-in/non-blocking and must not weaken Prisma's local-first or secret-handling guarantees.

## Current state

- The fixture benchmark and summary schema live under the existing test/benchmark infrastructure and `.agents/reports/`.
- No live provider sandbox contract, credential source, redaction policy, or CI job is currently defined.
- The repository is public; secrets must never be placed in issues, fixtures, source, or workflow YAML.

## Commands you will need

| Purpose | Command | Expected result |
|---|---|---|
| Benchmark tests | `make benchmark-summary` | exit 0 |
| Sensitive test review | `make test-sensitive` | exit 0 or baseline classified |
| Full gates | `make lint && make build-test` | exit 0, baseline classified |

## Scope

**In scope**:

- A design note and, only if the sandbox contract is available, opt-in benchmark harness/CI configuration.
- Redaction, retention, failure, and non-blocking reporting policy.
- Tests for parsing/comparison of captured provider responses without live credentials.
- `plans/README.md`

**Out of scope**:

- Adding provider secrets or requesting them from contributors.
- Making live output a merge gate.
- Sending user transcripts or personal data to a provider.

## Steps

### Step 1: Define the sandbox contract

Specify provider, sanitized input, expected output envelope, credential injection mechanism, retention, redaction, rate limits, and failure policy. If no controlled sandbox exists, stop after documenting the prerequisite.

**Verify**: the contract contains no secret values and can run without user recordings.

### Step 2: Design comparison and reporting

Separate schema validity, semantic drift, and provider availability. Store only redacted artifacts/metrics. Keep the local fixture benchmark authoritative for merge gates.

**Verify**: parser/comparator tests pass against synthetic fixtures.

### Step 3: Review security and CI impact

Run thermo review with security emphasis. Inspect secret handling, workflow permissions, artifact visibility, prompt/input privacy, and non-blocking behavior. Correct all Critical/Medium findings.

**Verify**: review has no unresolved Critical/Medium findings.

### Step 4: Decide whether implementation is justified

If the sandbox is unavailable or the CI cost/privacy trade-off is not acceptable, leave the design as a documented P3 prerequisite and do not implement a live lane.

**Verify**: issue #107 records the decision and evidence.

## Done criteria

- [x] A sandbox/no-sandbox decision is explicit.
- [x] No secret or personal transcript enters the repository or artifacts.
- [x] Fixture benchmarks remain deterministic and blocking where currently required.
- [x] Any implemented harness is opt-in and non-blocking.
- [x] Review and gates are recorded.
- [x] `plans/README.md` status row updated.

## Validation evidence — 2026-07-12

- Added `.agents/reports/provider-drift-benchmark-design-2026-07-12.md`.
- Decision: no controlled provider sandbox exists, so no live harness or CI workflow was added. Issue #107 remains open as a P3 prerequisite.
- `make benchmark-summary`: passed in report-only mode; fixture baseline unchanged.
- `make test-sensitive`: 114 executed, 17 skipped, 108 passed, 6 known `RecordingManagerTests` readiness failures; `StorageServiceSecurityTests` passed 7/7.
- `make lint`: non-blocking repository baseline; 362/504 files require formatting and 288 warnings.
- `make build-test`: build passed; 993 executed, 17 skipped, 977 passed, 16 known `MetricsDashboardViewModelTests` failures. CoreSimulator/service warnings are environmental.
- Thermo/security review: no unresolved Critical/Medium findings. No credentials, provider output, user recordings, or personal transcript data were added.

## STOP conditions

- A live benchmark requires committing or printing a provider credential.
- The provider cannot guarantee sanitized input/output handling.
- CI permissions/artifact visibility cannot be constrained.

## Maintenance notes

Treat live drift as observability, not correctness truth. Update fixture expectations only through deliberate review.
