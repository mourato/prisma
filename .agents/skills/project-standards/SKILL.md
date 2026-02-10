---
name: project-standards
description: This skill should be used when updating project-wide documentation, tracking technical debt, or maintaining AGENTS.md.
---

# Project Operational Standards

## Overview

Guidelines for maintaining consistent project documentation and visibility into technical constraints.

## 1. Limitation Tracking

- **Update KNOWN_LIMITATIONS.md**: Always update this file when implementing features with known trade-offs.
- **Format**: Give each limitation a descriptive title and a concise description.
- **Context**: Include the reason for the limitation (e.g., performance restriction, timeframe, system API bug) and the date.

## 2. Agent Documentation

- **Living Guidance**: Ensure `AGENTS.md` reflects the current state of tools, scripts, and skills.
- **Design System Guidance**: Keep the UI Design System tokens/components documented (and referenced from `AGENTS.md` / relevant skills).
- **Preview Standard**: Keep `docs/PREVIEW_GUIDELINES.md` and preview-related skills updated when UI preview rules change.
- **Clean Registry**: Periodically audit `.agents/skills` to remove stale or redundant guidance.
- **B2 Module Awareness**: Keep docs aligned with the current module split (`Common`, `Domain`, `Infrastructure`, `Data`, `Audio`, `AI`, `UI`, compatibility `Core`).
- **Path Validity**: After file moves between modules, update all documentation links and examples to the new canonical paths.

## 3. Consistency

- **Commit Messages**: Enforce Conventional Commits consistently to ensure a readable history.
- **Worktree Mandate**: Adhere to the Worktree-first development workflow for every task.
- **UI Quality Gate**: Run `make preview-check` when UI views are added/changed.

## 4. Language

- All documentation must be written in **English**.
- All code comments must be written in **English**.
