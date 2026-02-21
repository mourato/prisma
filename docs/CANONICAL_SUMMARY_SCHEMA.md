# Canonical Summary Schema

This document defines the canonical summary contract introduced for intelligence features.

## Scope

The canonical summary payload is stored as `CanonicalSummary` in Swift domain models and persisted in Core Data.

Contract fields:

- `schemaVersion` (`Int`)
- `generatedAt` (`Date`)
- `summary` (`String`)
- `keyPoints` (`[String]`)
- `decisions` (`[String]`)
- `actionItems` (`[CanonicalSummary.ActionItem]`)
- `openQuestions` (`[String]`)
- `trustFlags` (`CanonicalSummary.TrustFlags`)

Trust flags:

- `isGroundedInTranscript` (`Bool`)
- `containsSpeculation` (`Bool`)
- `isHumanReviewed` (`Bool`)
- `confidenceScore` (`Double`, range `0...1`)

## Versioning

- Current version: `CanonicalSummary.currentSchemaVersion == 1`.
- Persistence metadata stores schema version in `canonicalSummarySchemaVersion`.
- Legacy records with no canonical summary use version `0` and `canonicalSummaryData == nil`.

## Validation and Rejection Rules

Payload validation is enforced before persistence:

- `schemaVersion` must be within `1...currentSchemaVersion`.
- `summary` must be non-empty after trimming.
- `keyPoints`, `decisions`, and `openQuestions` cannot contain empty strings.
- Every `actionItems.title` must be non-empty after trimming.
- `trustFlags.confidenceScore` must be within `0...1`.

Invalid payloads are rejected with `CanonicalSummaryValidationError`.

## Migration Safety

Core Data adds optional/defaulted fields:

- `canonicalSummaryData` (optional binary)
- `canonicalSummarySchemaVersion` (default `0`)
- `summaryGroundedInTranscript` (default `false`)
- `summaryContainsSpeculation` (default `false`)
- `summaryHumanReviewed` (default `false`)
- `summaryConfidenceScore` (default `0.0`)

This keeps automatic lightweight migration safe for existing stores.
