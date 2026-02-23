---
name: code-review
description: This skill should be used when the user asks to "review this change", "do a code review", "audit this PR", or "find risks before merge".
---

# Code Review (Meeting Assistant)

## Goal

Perform a pragmatic review of the change set before the final push, focusing on:

- Correctness and concurrency (Swift 6 / `@MainActor` / race conditions)
- Security and privacy (sensitive data, logs, permissions)
- Performance (hot paths, allocations, observation/Combine)
- UX (Settings consistency, invalid states, feedback)
- Maintainability (duplication, cohesion, coupling, naming)
- Testability (injection points, pure logic)

## How to run

### 1) Scope

- List commits and touched files.
- Separate behavior changes from structural refactors.

### 2) Technical checklist

- Threading: does state mutation happen on the correct actor/thread?
- Side effects: are updates to `UserDefaults` and `KeyboardShortcuts` consistent?
- State: are there impossible/stuck states (e.g., a lock that never releases)?
- Failure paths: on error/cancel, does the system return to a sane state?
- Logs: no PII; consistent severity.
- i18n/a11y: localization keys and accessibility labels/hints are correct.

### 3) UX checklist

- Settings placement is coherent and discoverable.
- “Reset” returns the UI to a predictable, consistent state.
- Custom shortcuts are disabled when not selected.

### 4) Security checklist

- No conflicting simultaneous recording.
- No leaking of file paths or sensitive inputs in logs.

### 5) Final summary table (traffic-light)

Use a short table with priority and recommendation:

- Critical: crash risk, data loss, security, user harm
- Medium: confusing behavior, technical debt, performance regressions
- Low: clarity improvements, optional refactors

Suggested columns:

- Severity
- Area (UX/Perf/Sec/Conc/Test/Arch)
- Finding
- Impact
- Recommendation

## Expected output

- A summary table (traffic-light).
- Objective notes with references to files/symbols.
- Short, actionable next steps.
