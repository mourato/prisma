---
name: testing-xctest
description: This skill should be used when the user asks to "write XCTest tests", "refactor test doubles", "add async tests", or "improve test structure" in Prisma.
---

# XCTest Patterns

## Role

Use this skill for XCTest implementation details in Prisma.

- Own test structure, naming, doubles, fixtures, and async test patterns.
- Delegate verification gates and merge commands to `../quality-assurance/SKILL.md`.
- Delegate lifecycle policy and risk lanes to `../task-lifecycle/SKILL.md`.

## Scope Boundary

Use this skill when the task is about writing or refactoring test code, especially under `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests`.

- XCTestCase organization
- `@MainActor` tests
- async `setUp` and `tearDown`
- mocks, fakes, spies, and fixtures
- deterministic assertions and failure messages

Do not use this skill to choose lane policy or merge gates.

## Test Structure Standards

### File and Type Layout

- Keep one primary subject area per test file.
- Prefer one top-level `final class ...Tests: XCTestCase` per file unless a second helper test type is clearly justified.
- Name files after the subject under test when possible, for example `TranscriptionDeliveryServiceTests.swift` or `AudioRecorderTests.swift`.

### Naming

- Use descriptive test names that encode behavior and outcome.
- Prefer `test<Action>_<Condition>_<ExpectedResult>` or an equivalent readable pattern already used nearby.
- Avoid vague names such as `testExample` or `testSuccess`.

### Arrange/Act/Assert

- Keep setup obvious and local.
- Extract helpers only when repeated setup obscures intent.
- Use comments sparingly; a short `// Given`, `// When`, `// Then` is acceptable when the flow is long.

## Async and Main-Actor Patterns

- Mark the test type or individual tests with `@MainActor` when they touch UI-bound state or main-actor services.
- Use async `setUp` only when initialization actually requires suspension.
- Prefer awaiting concrete observable effects instead of sleeping for timing.
- Keep task cancellation explicit in tests that start long-lived work.

## Doubles and Fixtures

- Prefer protocol-backed fakes or spies over broad inheritance-based mocks.
- Keep test doubles minimal and scoped to the behavior under assertion.
- Avoid doubles that implement unrelated protocol surface just to satisfy compilation; split protocols or add focused adapters if this becomes common.
- Put reusable fixtures near the owning subject area, not in a generic dumping-ground file.

## Existing Repository Examples

- `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/TranscriptionDeliveryServiceTests.swift`
- `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/AudioRecorderTests.swift`
- `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/ShortcutDefinitionAndEngineTests.swift`

Use these files as examples for local naming, protocol-backed doubles, and behavior-focused assertions.

## Verification

- Run targeted tests first via `./scripts/run-tests.sh --file <TestFile>` or `--test <testName>`.
- Use `../quality-assurance/SKILL.md` for merge-gate selection and broader validation.

## Related Skills

- `../quality-assurance/SKILL.md`
- `../task-lifecycle/SKILL.md`
- `../code-quality/SKILL.md`
