---
name: observability-diagnostics
description: This skill should be used when the user asks to "add logging", "improve telemetry", "diagnose with metrics", or "standardize diagnostic signals" in Prisma.
---

# Observability and Diagnostics

## Role

Use this skill to shape diagnostic data in Prisma.

- Own logging structure, telemetry naming, payload redaction, and failure-signature guidance.
- Complement `../debugging-strategies/SKILL.md` by improving what the system emits before and during investigation.
- Complement `../error-handling/SKILL.md` by defining how failures should be observed, not how they are modeled.

## Scope Boundary

Use this skill when work involves:

- `AppLogger` or `Logger`
- structured telemetry events
- diagnostic payload shape
- redaction and privacy-safe logging
- correlation between logs, telemetry, and metrics
- recording concise failure signatures in task or PR notes

## Diagnostic Standards

### Logging

- Log state transitions, boundary failures, and recovery attempts.
- Avoid noisy per-frame or per-buffer logs outside dedicated debug paths.
- Prefer structured context over long free-form messages when the same failure may recur.

### Telemetry Events

- Use stable, lower_snake_case event names.
- Keep payload keys stable and sanitized.
- Emit telemetry for decision points and degraded states, not for every implementation detail.

### Redaction

- Never log secrets, raw credentials, or sensitive transcript content.
- Sanitize user-controlled strings before attaching them to diagnostic payloads.
- Prefer identifiers, counts, and coarse state tokens over raw content.

### Failure Signatures

- Capture the first failing stage and the first actionable mismatch.
- Keep signatures short enough to repeat in PR notes or issue comments.
- If a metric or diagnostic payload exists, reference it by stable name rather than copying large blobs.

## Existing Repository References

- `Packages/MeetingAssistantCore/Sources/Common/Logging/ShortcutTelemetry.swift`
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Infrastructure/PerformanceMonitor.swift`
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Services/TextContextLogger.swift`

Use these as the current baseline for structured events, metrics intake, and privacy-aware failure logging.

## Related Skills

- `../debugging-strategies/SKILL.md`
- `../error-handling/SKILL.md`
- `../performance/SKILL.md`
- `../security/SKILL.md`
