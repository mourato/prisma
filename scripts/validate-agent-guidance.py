#!/usr/bin/env python3

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MARKDOWN_FILES = [
    ROOT / "AGENTS.md",
    *sorted((ROOT / ".agents" / "docs").glob("*.md")),
    *sorted((ROOT / ".agents" / "skills").glob("*/SKILL.md")),
]

MAKE_TARGET_RE = re.compile(r"^([A-Za-z0-9_.-]+):", re.MULTILINE)
MARKDOWN_LINK_RE = re.compile(r"\[[^\]]+\]\(([^)]+)\)")
INLINE_PATH_RE = re.compile(
    r"`((?:\.\.?/|\.agents/|scripts/|App/|Packages/|Config/|\.github/|AGENTS\.md|README\.md|Makefile)[^`\s]*)`"
)
INLINE_MAKE_RE = re.compile(r"`make\s+([A-Za-z0-9_.-]+)`")
FENCED_CODE_BLOCK_RE = re.compile(r"```[^\n]*\n(.*?)```", re.DOTALL)
KNOWN_PATH_SUFFIXES = (
    ".md",
    ".sh",
    ".py",
    ".swift",
    ".xcodeproj",
    ".xcworkspace",
    ".strings",
    "/",
)


def parse_make_targets(makefile_path: Path) -> set[str]:
    text = makefile_path.read_text(encoding="utf-8")
    targets: set[str] = set()

    for match in MAKE_TARGET_RE.finditer(text):
        target = match.group(1)
        if target.startswith("."):
            continue
        targets.add(target)

    return targets


def resolve_local_path(source_file: Path, reference: str) -> Path | None:
    clean_reference = reference.split("#", 1)[0].strip()
    if not clean_reference:
        return None
    if clean_reference.startswith(("http://", "https://", "mailto:", "file://")):
        return None
    if any(token in clean_reference for token in ("*", "{", "}", "...")):
        return None

    if clean_reference.startswith("./") or clean_reference.startswith("../"):
        source_relative = (source_file.parent / clean_reference).resolve()
        if source_relative.exists():
            return source_relative

        root_relative = (ROOT / clean_reference.removeprefix("./")).resolve()
        if root_relative.exists():
            return root_relative

        return source_relative

    sibling_candidate = (source_file.parent / clean_reference).resolve()
    if sibling_candidate.exists():
        return sibling_candidate

    return (ROOT / clean_reference).resolve()


def extract_make_targets(text: str) -> set[str]:
    targets = {match.group(1) for match in INLINE_MAKE_RE.finditer(text)}

    for block in FENCED_CODE_BLOCK_RE.findall(text):
        for line in block.splitlines():
            stripped = line.strip()
            if not stripped.startswith("make "):
                continue
            target = stripped.split()[1]
            if re.fullmatch(r"[A-Za-z0-9_.-]+", target):
                targets.add(target)

    return targets


def looks_like_local_reference(reference: str) -> bool:
    return "/" in reference or reference.endswith(KNOWN_PATH_SUFFIXES)


def validate_make_references(markdown_file: Path, text: str, known_targets: set[str]) -> list[str]:
    errors: list[str] = []
    for target in sorted(extract_make_targets(text)):
        if target not in known_targets:
            errors.append(f"Unknown make target '{target}' in {markdown_file.relative_to(ROOT)}")
    return errors


def validate_path_references(markdown_file: Path, text: str) -> list[str]:
    errors: list[str] = []
    text_without_code_blocks = FENCED_CODE_BLOCK_RE.sub("", text)

    references = {match.group(1) for match in MARKDOWN_LINK_RE.finditer(text_without_code_blocks)}
    references.update(match.group(1) for match in INLINE_PATH_RE.finditer(text_without_code_blocks))

    for reference in sorted(references):
        if not looks_like_local_reference(reference):
            continue
        if "%20" in reference:
            reference = reference.replace("%20", " ")

        local_path = resolve_local_path(markdown_file, reference)
        if local_path is None:
            continue
        if not local_path.exists():
            errors.append(
                f"Missing local reference '{reference}' in {markdown_file.relative_to(ROOT)}"
            )

    return errors


def main() -> int:
    known_targets = parse_make_targets(ROOT / "Makefile")
    errors: list[str] = []

    for markdown_file in MARKDOWN_FILES:
        text = markdown_file.read_text(encoding="utf-8")
        errors.extend(validate_make_references(markdown_file, text, known_targets))
        errors.extend(validate_path_references(markdown_file, text))

    if errors:
        for error in sorted(set(errors)):
            print(f"error: {error}")
        return 1

    print("Guidance validation passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())