# Opt-in live provider drift benchmark design — 2026-07-12

## Decision

Do not implement a live provider lane yet. The repository has no controlled provider sandbox, no provider-owned test account contract, and no CI policy that constrains live response artifacts and credentials sufficiently for a safe default implementation. Keep this as a P3 prerequisite and leave issue #107 open.

The authoritative merge gate remains the deterministic fixture benchmark:

```bash
make benchmark-summary
```

It runs report-only against synthetic fixtures and does not contact a provider. The live lane, if implemented later, must remain opt-in, non-blocking, and independent from this gate.

## Required sandbox contract

Implementation should not begin until a provider and an owner supply all of the following:

| Area | Required contract |
| --- | --- |
| Provider/account | A provider-owned sandbox or dedicated low-privilege test account, with an explicit monthly/request budget and a named owner. |
| Input | Synthetic, reviewed text only; no user recordings, meeting titles, names, emails, identifiers, or copied production transcripts. The prompt and fixture version must be pinned. |
| Endpoint | An allowlisted provider endpoint and model identifier. Custom/user-configured endpoints are never eligible for this lane. |
| Credential | A runtime-only CI secret injected by the secret manager. It must not be committed, echoed, included in test output, or exposed to pull requests from forks. |
| Output | Parse in memory. Retain only redacted metrics and failure categories; never upload raw provider responses or prompts as artifacts. |
| Retention | If a diagnostic artifact is ever needed, use a short explicit retention period and a private artifact scope. Default behavior is no raw artifact. |
| Limits | Hard timeout, bounded input/output size, bounded concurrency, rate limit, and a single-provider request budget. Availability failures must stop the lane cleanly. |
| Trigger | Manual dispatch or a protected scheduled workflow only. Never run automatically for untrusted pull requests. |
| Permissions | Read-only workflow permissions, no repository write token, and no access to user data or production storage. |

## Comparison and reporting model

The future runner must separate three outcomes:

1. **Schema validity** — HTTP/transport success, response decoding, canonical-summary schema version, required fields, and trust-flag constraints.
2. **Semantic drift** — comparison against the pinned synthetic expected result using the existing summary metrics. Report field-level differences and redacted aggregate metrics; do not treat a provider response as correctness truth.
3. **Provider availability** — authentication, rate limiting, timeout, service outage, or quota. Availability must be reported separately from quality drift and must never be converted into a merge failure.

The runner should emit a small result containing provider/model identifiers, fixture version, timestamp, latency bucket, schema outcome, metric deltas, and a redacted failure category. It should not emit transcript text, prompt text, raw JSON, API keys, authorization headers, file paths, or personal identifiers.

## CI and failure policy

- The local fixture benchmark remains the only blocking summary gate.
- A live benchmark must be explicitly enabled and must default to skipped/not configured when the sandbox secret is absent.
- A live failure is an observation for issue/reporting purposes, not a reason to block a pull request or change production defaults.
- Do not retry indefinitely. At most one bounded retry may be used for a classified transient availability error, with the retry visible in metrics.
- Never update fixture expectations from live output automatically. Any fixture or rubric change requires a separate reviewed change.
- Keep all output redacted before logging or artifact upload. Secret scanning is a secondary check, not a substitute for preventing raw output.

## Current evidence

- `make benchmark-summary` passed on 2026-07-12 with the report-only fixture lane; the baseline was unchanged.
- The fixture parser/comparator already has synthetic coverage in [`SummaryBenchmarkRegressionTests.swift`](../../Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/SummaryBenchmarkRegressionTests.swift) and [`SummaryBenchmarkRunner.swift`](../../Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/Benchmarks/SummaryBenchmarkRunner.swift).
- `make test-sensitive` executed 114 tests with 17 skipped, 108 passed, and the existing 6 `RecordingManagerTests` readiness failures caused by shared settings/test isolation interference. `StorageServiceSecurityTests` passed 7/7.
- No credentials, provider responses, user recordings, or personal transcript data were added to the repository or artifacts.

## Revisit criteria

Reopen issue #107 only when a controlled sandbox owner, secret-injection path, artifact policy, and protected trigger are available. At that point, implement the smallest parser/comparator seam using synthetic captured responses first, add redaction tests, and keep the live workflow opt-in/non-blocking from its first run.
