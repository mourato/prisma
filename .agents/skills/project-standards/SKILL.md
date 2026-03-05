---
name: project-standards
description: This skill should be used when the user asks to "update AGENTS.md", "document project policy", "track known limitations", or "align repository standards".
---

# Project Operational Standards

## Overview

Guidelines for maintaining consistent project documentation and visibility into technical constraints.

## 1. Limitation Tracking

- **Track in GitHub Issues**: Register known limitations and intentional trade-offs as GitHub issues (use `gh`) with the `known-limitation` label.
- **Avoid markdown backlog files**: Do not maintain a standalone `KNOWN_LIMITATIONS.md` file.
- **Issue quality**: Each issue should include context, impact, and a clear future direction/acceptance criteria.

## 2. Agent Documentation

- **Living Guidance**: Ensure `AGENTS.md` reflects the current state of tools, scripts, and skills.
- **Reusable Blocks Policy**: Keep the `reuse -> extend -> create` rule synchronized between `AGENTS.md` and affected implementation skills.
- **Compact Execution Mode**: When script execution modes change (for example `*-agent` targets), update `AGENTS.md` and relevant skills with command usage, log locations, and output contracts.
- **Design System Guidance**: Keep the UI Design System tokens/components documented (and referenced from `AGENTS.md` / relevant skills).
- **Preview Standard**: Keep preview-related guidance centralized in `preview-coverage` and other UI skills.
- **Clean Registry**: Periodically audit `.agents/skills` to remove stale or redundant guidance.
- **Redundancy Audit**: Periodically audit repeated UI/logic guidance and consolidate duplicate instructions into reusable skill sections.
- **B2 Module Awareness**: Keep docs aligned with the current module split (`Common`, `Domain`, `Infrastructure`, `Data`, `Audio`, `AI`, `UI`, compatibility `Core`).
- **Path Validity**: After file moves between modules, update all documentation links and examples to the new canonical paths.
- **Command Surface Sync**: When Makefile/script targets are renamed or removed, update `AGENTS.md`, README, and affected skills/docs in the same PR to avoid stale guidance.

## 3. Information Routing (No Root `docs/`)

Route new knowledge using this order:

1. **Skill absorption** (`.agents/skills/...`) for reusable operational guidance.
2. **GitHub issue** (`gh issue create`) for backlog items, known limitations, and follow-up work.
3. **Deletion** for stale or duplicate files with no current operational value.

Rules:

- Do not create new documentation files under root `docs/`.
- Keep durable project policy in `AGENTS.md` or skills.
- Keep pending work in GitHub issues instead of markdown backlog files.
- For generated report artifacts, prefer `/tmp` or `.agents/reports/`.

## 4. Consistency

- **Commit Messages**: Enforce Conventional Commits consistently to ensure a readable history.
- **Branch Workflow**: Use the single-checkout feature-branch workflow defined in `AGENTS.md`.
- **UI Quality Gate**: Run `make preview-check` when UI views are added/changed.

## 5. Language

- All documentation must be written in **English**.
- All code comments must be written in **English**.
