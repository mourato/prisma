# History performance baseline — 2026-07-12

## Scope

This baseline measures the existing Core Data metadata query, metadata mapping, in-memory history filtering, and repeated `TranscriptionSettingsViewModel` reloads. Fixtures are deterministic, in-memory, and contain no provider data or personal recordings.

Dataset sizes: 50, 250, and 1,000 metadata rows.

## Results

| Dataset | Query + mapping average | Query + mapping minimum | Filter average | Filter minimum | Matching rows |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 50 | 1.009 ms | 0.990 ms | 0.543 ms | 0.523 ms | 1 |
| 250 | 5.229 ms | 5.136 ms | 2.637 ms | 2.558 ms | 5 |
| 1,000 | 21.463 ms | 20.656 ms | 10.624 ms | 10.573 ms | 17 |

The ViewModel reload probe performed 3 metadata reloads over 250 rows in 75.295 ms total, or about 25.1 ms per reload. All active source, app, and search filters returned the expected rows.

## Decision

Keep the current bounded Core Data query plus notification-triggered reload path. Do not add `NSFetchedResultsController`, diff-based updates, or FTS in this slice:

- the current UI path is bounded at 250 rows;
- the measured 250-row query and filter work remains well below the 100 ms interactive reload target;
- the 1,000-row unbounded probe remains below the 50 ms query/mapping investigation threshold;
- substring search is not currently expensive enough to justify schema/index architecture work.

## Re-evaluation triggers

Re-run this suite before changing the architecture when one of these becomes true:

- the history UI needs to display more than 250 rows per reload;
- the 1,000-row query + mapping baseline exceeds 50 ms on the supported development hardware;
- an interactive reload exceeds 100 ms;
- notification-driven reload frequency becomes measurable as a repeated-update problem rather than a correctness problem.

Issues #97 and #98 remain measurement-gated. The next slice should be selected from new measurements, not from the issue labels alone.

## Reproduction

```bash
make test-perf
swift test --package-path Packages/MeetingAssistantCore --filter TranscriptionHistoryPerformanceTests
```
