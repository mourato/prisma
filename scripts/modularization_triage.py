#!/usr/bin/env python3
"""Generate a triage report for SwiftPM multi-target modularization.

This script is tailored for the MeetingAssistantCore B2 split. It produces a
Markdown report listing:
- Swift compiler errors grouped by file (from an xcodebuild log)
- Suggested missing module imports per file (heuristic)
- Extra static-scan candidates (uses symbol but lacks module import)
- Non-English comment candidates (heuristic; optional)

Usage:
  python3 scripts/modularization_triage.py     --worktree /path/to/worktree     --log /tmp/test-output.log     --out .agents/reports/modularization_triage_report.md
"""

from __future__ import annotations

import argparse
import datetime as dt
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Sequence, Set, Tuple


ERROR_RE = re.compile(
    r"^(?P<file>/.*?\.swift):(?P<line>\d+):(?P<col>\d+): (?P<severity>error|warning): (?P<msg>.*)$"
)

CANNOT_FIND_TYPE_RE = re.compile(r"cannot find type '(?P<sym>[^']+)' in scope")
CANNOT_FIND_VALUE_RE = re.compile(r"cannot find '(?P<sym>[^']+)' in scope")
CANNOT_INFER_MEMBER_RE = re.compile(r"cannot infer contextual base in reference to member '(?P<member>[^']+)'")


# Symbol → module import suggestions.
# Keep this list explicit and conservative (prefer a small number of strong mappings).
SYMBOL_TO_MODULE: Dict[str, str] = {
    # Common
    "AppLogger": "MeetingAssistantCoreCommon",
    "LogCategory": "MeetingAssistantCoreCommon",
    "FeatureFlags": "MeetingAssistantCoreCommon",
    "InputSanitizer": "MeetingAssistantCoreCommon",

    # Domain
    "Meeting": "MeetingAssistantCoreDomain",
    "MeetingApp": "MeetingAssistantCoreDomain",
    "Transcription": "MeetingAssistantCoreDomain",
    "TranscriptionResponse": "MeetingAssistantCoreDomain",
    "PostProcessingPrompt": "MeetingAssistantCoreDomain",

    # Infrastructure
    "AppSettingsStore": "MeetingAssistantCoreInfrastructure",
    "SoundFeedbackSound": "MeetingAssistantCoreInfrastructure",
    "AccessibilityPermissionService": "MeetingAssistantCoreInfrastructure",
    "PasteboardServiceProtocol": "MeetingAssistantCoreInfrastructure",
    "PasteboardService": "MeetingAssistantCoreInfrastructure",
    "PermissionState": "MeetingAssistantCoreDomain",  # UI/domain permission enums
    "TranscriptionService": "MeetingAssistantCoreInfrastructure",
    "PostProcessingServiceProtocol": "MeetingAssistantCoreInfrastructure",

    # Audio
    "RecordingManager": "MeetingAssistantCoreAudio",
    "RecordingSource": "MeetingAssistantCoreAudio",

    # AI
    "TranscriptionClient": "MeetingAssistantCoreAI",
    "PostProcessingService": "MeetingAssistantCoreAI",
}

# Contextual member names that frequently imply missing LogCategory imports.
MEMBER_TO_MODULE: Dict[str, str] = {
    "recordingManager": "MeetingAssistantCoreCommon",
    "health": "MeetingAssistantCoreCommon",
    "general": "MeetingAssistantCoreCommon",
    "databaseManager": "MeetingAssistantCoreCommon",
}

# Words to heuristically detect Portuguese comments.
PT_WORDS = {
    "para",
    "por",
    "enquanto",
    "gravação",
    "gravar",
    "estado",
    "permissão",
    "configurações",
    "serviço",
    "repositório",
    "sincroniza",
    "inicialização",
    "por enquanto",
    "tela",
}


@dataclass(frozen=True)
class CompilerFinding:
    file: Path
    line: int
    col: int
    severity: str
    message: str


def parse_xcodebuild_log(log_text: str) -> List[CompilerFinding]:
    findings: List[CompilerFinding] = []
    for line in log_text.splitlines():
        m = ERROR_RE.match(line.strip())
        if not m:
            continue
        findings.append(
            CompilerFinding(
                file=Path(m.group("file")),
                line=int(m.group("line")),
                col=int(m.group("col")),
                severity=m.group("severity"),
                message=m.group("msg"),
            )
        )
    return findings


def group_findings(findings: Sequence[CompilerFinding]) -> Dict[Path, List[CompilerFinding]]:
    grouped: Dict[Path, List[CompilerFinding]] = {}
    for f in findings:
        grouped.setdefault(f.file, []).append(f)
    return grouped


def extract_missing_symbols(message: str) -> Tuple[Set[str], Set[str]]:
    """Return (symbols, contextual_members)."""
    symbols: Set[str] = set()
    members: Set[str] = set()

    m = CANNOT_FIND_TYPE_RE.search(message)
    if m:
        symbols.add(m.group("sym"))

    m = CANNOT_FIND_VALUE_RE.search(message)
    if m:
        symbols.add(m.group("sym"))

    m = CANNOT_INFER_MEMBER_RE.search(message)
    if m:
        members.add(m.group("member"))

    return symbols, members


def swift_imports(swift_source: str) -> Set[str]:
    imports: Set[str] = set()
    for line in swift_source.splitlines():
        striped = line.strip()
        if not striped:
            continue
        if striped.startswith("import "):
            imports.add(striped.split()[1])
            continue
        # Stop scanning imports once we hit first non-import line.
        break
    return imports


def suggest_imports_for_file(
    content: str,
    existing_imports: Set[str],
    missing_symbols: Iterable[str],
    missing_members: Iterable[str],
) -> Set[str]:
    suggestions: Set[str] = set()

    for sym in missing_symbols:
        mod = SYMBOL_TO_MODULE.get(sym)
        if mod and mod not in existing_imports:
            suggestions.add(mod)

    for member in missing_members:
        mod = MEMBER_TO_MODULE.get(member)
        if mod and mod not in existing_imports:
            suggestions.add(mod)

    # Static heuristic: if symbol appears in file but module not imported.
    for sym, mod in SYMBOL_TO_MODULE.items():
        if mod in existing_imports:
            continue
        if re.search(rf"\b{re.escape(sym)}\b", content):
            suggestions.add(mod)

    return suggestions


def find_non_english_comment_lines(swift_source: str) -> List[Tuple[int, str]]:
    results: List[Tuple[int, str]] = []
    for i, line in enumerate(swift_source.splitlines(), start=1):
        striped = line.strip()
        if not striped.startswith("//"):
            continue
        lower = striped.lower()
        # Very simple heuristic: either contains accented chars or known PT words.
        has_accent = any(ch in lower for ch in "ãõáàâéêíóôúç")
        has_pt_word = any(word in lower for word in PT_WORDS)
        if has_accent or has_pt_word:
            results.append((i, striped))
    return results


def iter_swift_files(worktree: Path) -> List[Path]:
    sources = worktree / "Packages" / "MeetingAssistantCore" / "Sources"
    if not sources.exists():
        return []
    return sorted(p for p in sources.rglob("*.swift") if p.is_file())


def relpath(path: Path, base: Path) -> str:
    try:
        return str(path.relative_to(base))
    except Exception:
        return str(path)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--worktree", type=Path, required=True)
    parser.add_argument("--log", type=Path, default=Path("/tmp/test-output.log"))
    parser.add_argument("--out", type=Path, default=None)
    parser.add_argument("--include-non-english-comments", action="store_true")
    parser.add_argument("--max-comment-lines", type=int, default=3)
    args = parser.parse_args()

    worktree: Path = args.worktree
    log_path: Path = args.log

    out_path: Path
    if args.out is None:
        out_path = worktree / ".agents" / "reports" / "modularization_triage_report.md"
    else:
        out_path = args.out if args.out.is_absolute() else (worktree / args.out)

    log_text = ""
    if log_path.exists():
        log_text = log_path.read_text(errors="replace")

    findings = parse_xcodebuild_log(log_text)
    grouped = group_findings([f for f in findings if str(f.file).startswith(str(worktree))])

    swift_files = iter_swift_files(worktree)

    suggestions_by_file: Dict[Path, Set[str]] = {}
    static_candidates: List[Path] = []
    non_english_candidates: Dict[Path, List[Tuple[int, str]]] = {}

    for file_path in swift_files:
        content = file_path.read_text(errors="replace")
        imports = swift_imports(content)

        missing_syms: Set[str] = set()
        missing_members: Set[str] = set()
        for finding in grouped.get(file_path, []):
            syms, members = extract_missing_symbols(finding.message)
            missing_syms |= syms
            missing_members |= members

        suggestions = suggest_imports_for_file(
            content=content,
            existing_imports=imports,
            missing_symbols=missing_syms,
            missing_members=missing_members,
        )
        if suggestions:
            suggestions_by_file[file_path] = suggestions

        # Static candidate if it uses any mapped symbol but has none of the mapped module imports.
        uses_any = any(re.search(rf"\b{re.escape(sym)}\b", content) for sym in SYMBOL_TO_MODULE.keys())
        imports_any = any(mod in imports for mod in set(SYMBOL_TO_MODULE.values()))
        if uses_any and not imports_any:
            static_candidates.append(file_path)

        if args.include_non_english_comments:
            comment_lines = find_non_english_comment_lines(content)
            if comment_lines:
                non_english_candidates[file_path] = comment_lines[: max(1, args.max_comment_lines)]

    now = dt.datetime.now().astimezone()

    lines: List[str] = []
    lines.append(f"# Modularization triage report")
    lines.append("")
    lines.append(f"Generated: {now.isoformat(timespec='seconds')}")
    lines.append(f"Worktree: `{worktree}`")
    lines.append(f"Log: `{log_path}`")
    lines.append("")

    lines.append("## Summary")
    lines.append("")
    lines.append(f"- Swift files scanned: **{len(swift_files)}**")
    lines.append(f"- Files with compiler findings in log: **{len(grouped)}**")
    lines.append(f"- Files with suggested import fixes: **{len(suggestions_by_file)}**")
    if args.include_non_english_comments:
        lines.append(f"- Files with non-English comment candidates: **{len(non_english_candidates)}** (heuristic)")
    lines.append("")

    lines.append("## Compiler findings (from log)")
    lines.append("")
    if not grouped:
        lines.append("No compiler findings parsed from the log under this worktree.")
    else:
        for file_path in sorted(grouped.keys()):
            lines.append(f"### `{relpath(file_path, worktree)}`")
            lines.append("")
            for f in grouped[file_path]:
                lines.append(f"- L{f.line}:{f.col} `{f.severity}`: {f.message}")
            lines.append("")

    lines.append("## Suggested module imports (heuristic)")
    lines.append("")
    if not suggestions_by_file:
        lines.append("No import suggestions generated.")
    else:
        for file_path in sorted(suggestions_by_file.keys()):
            sugg = ", ".join(sorted(suggestions_by_file[file_path]))
            lines.append(f"- `{relpath(file_path, worktree)}` → `{sugg}`")
        lines.append("")

    lines.append("## Static-scan candidates")
    lines.append("")
    if not static_candidates:
        lines.append("No extra candidates found.")
    else:
        lines.append(
            "These files reference known cross-module symbols but do not import any of the mapped modules."
        )
        lines.append("")
        for file_path in static_candidates[:200]:
            lines.append(f"- `{relpath(file_path, worktree)}`")
        if len(static_candidates) > 200:
            lines.append(f"- (… and {len(static_candidates) - 200} more)")
        lines.append("")

    if args.include_non_english_comments:
        lines.append("## Non-English comment candidates (heuristic)")
        lines.append("")
        if not non_english_candidates:
            lines.append("No candidates found.")
        else:
            for file_path in sorted(non_english_candidates.keys()):
                lines.append(f"### `{relpath(file_path, worktree)}`")
                lines.append("")
                for line_no, text in non_english_candidates[file_path]:
                    lines.append(f"- L{line_no}: {text}")
                lines.append("")

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text("\n".join(lines) + "\n")

    print(f"Wrote report: {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
