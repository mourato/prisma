# Plan 051: Re-run modularization triage and resolve only confirmed hygiene findings

> **Executor instructions**: This is a scoped cleanup, not a broad rewrite. Confirm every finding from the current main branch before editing. Run thermo review and correct all Critical/Medium findings.
>
> **Drift check**: `git diff --stat 80ed5788..HEAD -- App Packages/MeetingAssistantCore/Sources scripts .agents/reports plans/README.md`

## Status

- **Priority**: P3
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/039-align-swift6-concurrency-baseline.md
- **Category**: tech-debt
- **Planned at**: commit `80ed5788`, 2026-07-12
- **Related issue**: #108

## Why this matters

Issue #108 refers to a historical modularization report, a `MAThemePicker` compiler finding, missing imports, and non-English comments. `MAThemePicker` is no longer present, but current source still contains Portuguese comments and current lint/build state should be triaged from main rather than relying on the February report.

## Current state

- `scripts/modularization_triage.py` exists and can be inspected for supported invocation.
- The historical compiler symbol named in the issue is absent from current source search.
- Project conventions require reports under `.agents/reports/` and prohibit root `docs/` artifacts.
- Current lint has unrelated size/format issues; do not reclassify every existing warning as a modularization regression.

## Commands you will need

| Purpose | Command | Expected result |
|---|---|---|
| Triage | `python3 scripts/modularization_triage.py --help` | supported arguments are shown without modifying source |
| Architecture | `make arch-check` | exit 0 |
| Build/lint | `make build-agent && make lint` | exit 0 with findings classified |
| Full gate | `make build-test` | exit 0, baseline classified |

## Scope

**In scope**:

- Confirmed import/module-boundary findings from the current triage.
- Confirmed stale/non-English comments in files touched by the triage, only where translation improves maintainability.
- A current report under `.agents/reports/` if the supported script requires one.
- Focused tests/build fixes and `plans/README.md`.

**Out of scope**:

- Renaming public types or broad comment translation across the entire repository.
- Fixing unrelated lint size violations; use Plans 042–047.
- Treating absence of `MAThemePicker` as a code change requirement.

## Steps

### Step 1: Run current triage in a non-destructive mode

Use the script's supported read-only/report output path. Compare findings with current imports, compiler/build output, and module boundaries.

**Verify**: report contains only current, reproducible findings.

### Step 2: Fix confirmed findings

Apply minimal import/comment hygiene fixes only for confirmed findings. Preserve comments that document domain behavior; translate or remove only stale/non-English implementation comments that impede maintenance.

**Verify**: `make arch-check` and focused build pass.

### Step 3: Review and validate

Run thermo review focused on accidental module coupling, deleted context, and comment accuracy. Correct all Critical/Medium findings, then run lint and full tests.

**Verify**: no unresolved Critical/Medium findings; commands recorded.

## Done criteria

- [x] Historical findings are reclassified against current main.
- [x] Confirmed import/comment issues are fixed or explicitly deferred.
- [x] No root `docs/` report is created.
- [x] Architecture/build/lint/full gates are recorded.
- [x] Thermo review has no unresolved Critical/Medium findings.
- [x] Issue #108 is updated with current evidence.
- [x] `plans/README.md` status row updated.

## Validation evidence — 2026-07-12

- `python3 scripts/modularization_triage.py --help`: supported read-only/report arguments confirmed.
- Generated `.agents/reports/modularization-triage-2026-07-12.md` from the current build log with the optional comment heuristic.
- `make arch-check`: passed.
- Current triage found no reproducible `MAThemePicker` issue, no compiler error, and no confirmed missing import. Heuristic import/comment candidates were classified and deferred; no source change was justified.
- `make build-agent`: passed.
- `make lint`: non-blocking repository baseline; 362/504 files require formatting and 288 warnings.
- `make build-test`: build passed; 993 executed, 17 skipped, 977 passed, 16 known `MetricsDashboardViewModelTests` failures. The source state was unchanged from the latest full gate while this report-only plan ran.
- Thermo review: no unresolved Critical/Medium findings. The report documents why heuristic findings are not actionable regressions.

## STOP conditions

- The script's current interface writes outside approved report paths.
- A compiler issue cannot be reproduced on current main.
- Translation would touch broad product copy or localization resources.

## Maintenance notes

Future modularization reports should cite current commit SHA and distinguish historical findings from current regressions.
