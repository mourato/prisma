#!/usr/bin/env python3
"""Extract robust summary metrics from an Instruments .trace file.

The script avoids hardcoding one table schema and instead discovers available
schemas from the trace TOC, then tries to export row data for each schema.
It computes stable deltas when cumulative columns are present.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Any


ANIMATION_KEYWORDS = ("hitch", "frame", "fps", "vsync", "animation")


def is_animation_schema(schema: str | None) -> bool:
    if not schema:
        return False
    lowered = schema.lower()
    return any(keyword in lowered for keyword in ANIMATION_KEYWORDS)


def run_xctrace_export(args: list[str]) -> str:
    result = subprocess.run(
        ["/usr/bin/xcrun", "xctrace", "export", *args],
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout


def parse_toc(trace_path: Path) -> tuple[list[str], list[str]]:
    toc_xml = run_xctrace_export(["--input", str(trace_path), "--toc"])
    root = ET.fromstring(toc_xml)

    schemas: list[str] = []
    for table in root.findall(".//table"):
        schema = table.attrib.get("schema")
        if schema and schema not in schemas:
            schemas.append(schema)

    runs: list[str] = []
    for run in root.findall(".//run"):
        run_number = run.attrib.get("number")
        if run_number and run_number not in runs:
            runs.append(run_number)

    return schemas, runs


def try_export_table(trace_path: Path, schema: str, run_number: str) -> list[dict[str, str]]:
    with tempfile.NamedTemporaryFile(suffix=".xml", delete=False) as tmp:
        out_path = Path(tmp.name)

    try:
        xpath = f'/trace-toc/run[@number="{run_number}"]/data/table[@schema="{schema}"]'
        subprocess.run(
            [
                "/usr/bin/xcrun",
                "xctrace",
                "export",
                "--input",
                str(trace_path),
                "--xpath",
                xpath,
                "--output",
                str(out_path),
            ],
            check=True,
            capture_output=True,
            text=True,
        )
        root = ET.parse(out_path).getroot()
        return [row.attrib for row in root.findall(".//row")]
    except Exception:
        return []
    finally:
        out_path.unlink(missing_ok=True)


def to_float(value: str | None) -> float | None:
    if value is None:
        return None
    try:
        return float(value)
    except ValueError:
        return None


def delta_metric(rows: list[dict[str, str]], key: str) -> float | None:
    if len(rows) < 2:
        return None
    first = to_float(rows[0].get(key))
    last = to_float(rows[-1].get(key))
    if first is None or last is None:
        return None
    return last - first


def summarize_schema_rows(schema: str, rows: list[dict[str, str]]) -> dict[str, Any]:
    summary: dict[str, Any] = {
        "schema": schema,
        "rows": len(rows),
    }
    if not rows:
        return summary

    run_time_delta = delta_metric(rows, "run-time")
    total_wakeups_delta = delta_metric(rows, "tot-wakeups")
    user_time_delta = delta_metric(rows, "user-time")
    system_time_delta = delta_metric(rows, "system-time")

    if run_time_delta is not None:
        summary["delta_run_time"] = round(run_time_delta, 3)
    if total_wakeups_delta is not None:
        summary["delta_wakeups"] = round(total_wakeups_delta, 3)
    if user_time_delta is not None:
        summary["delta_user_time"] = round(user_time_delta, 3)
    if system_time_delta is not None:
        summary["delta_system_time"] = round(system_time_delta, 3)

    if run_time_delta and total_wakeups_delta is not None and run_time_delta > 0:
        summary["wakeups_per_sec"] = round(total_wakeups_delta / run_time_delta, 3)

    first_row = rows[0]
    last_row = rows[-1]
    for key in ("run-time", "tot-wakeups", "cpu-time", "avg-cpu", "max-cpu"):
        if key in first_row:
            summary[f"first_{key}"] = first_row[key]
        if key in last_row:
            summary[f"last_{key}"] = last_row[key]

    animation_metric_keys = (
        "hitch-count",
        "hitches",
        "total-hitches",
        "avg-frame-time",
        "frame-time",
        "frame-rate",
        "fps",
        "vsync-miss-count",
    )
    for key in animation_metric_keys:
        if key in first_row:
            summary[f"first_{key}"] = first_row[key]
        if key in last_row:
            summary[f"last_{key}"] = last_row[key]

        delta = delta_metric(rows, key)
        if delta is not None:
            summary[f"delta_{key}"] = round(delta, 3)

    summary["is_animation_schema"] = is_animation_schema(schema)

    return summary


def choose_primary_summary(summaries: list[dict[str, Any]]) -> dict[str, Any] | None:
    if not summaries:
        return None

    animation_candidates = [
        item for item in summaries if item.get("rows", 0) > 0 and item.get("is_animation_schema")
    ]
    if animation_candidates:
        with_hitch_delta = [
            item
            for item in animation_candidates
            if any(str(key).startswith("delta_hitch") for key in item.keys())
        ]
        if with_hitch_delta:
            return sorted(with_hitch_delta, key=lambda item: item.get("rows", 0), reverse=True)[0]

    with_wakeups = [
        item for item in summaries if item.get("rows", 0) > 0 and "wakeups_per_sec" in item
    ]
    if with_wakeups:
        return sorted(with_wakeups, key=lambda item: item.get("rows", 0), reverse=True)[0]

    preferred = [
        "cpu-statistics",
        "activity-monitor-process-live",
        "activity-monitor-process-ledger",
        "activity-monitor-system",
        "sysmon-process",
        "core-profile",
        "time-profile",
        "counters-profile",
    ]
    by_schema = {item.get("schema"): item for item in summaries}
    for schema in preferred:
        item = by_schema.get(schema)
        if item and item.get("rows", 0) > 0:
            return item

    with_rows = [item for item in summaries if item.get("rows", 0) > 0]
    if with_rows:
        return sorted(with_rows, key=lambda item: item.get("rows", 0), reverse=True)[0]
    return summaries[0]


def write_text_report(
    out_path: Path,
    trace_path: Path,
    run_number: str,
    schemas: list[str],
    primary: dict[str, Any] | None,
    summaries: list[dict[str, Any]],
) -> None:
    lines: list[str] = [
        f"trace={trace_path}",
        f"run={run_number}",
        f"available_schemas={','.join(schemas)}",
    ]

    if primary:
        lines.append(f"selected_schema={primary.get('schema', 'unknown')}")
        for key in (
            "rows",
            "delta_run_time",
            "delta_wakeups",
            "wakeups_per_sec",
            "delta_user_time",
            "delta_system_time",
            "first_run-time",
            "last_run-time",
            "first_tot-wakeups",
            "last_tot-wakeups",
            "first_cpu-time",
            "last_cpu-time",
            "first_avg-cpu",
            "last_avg-cpu",
            "first_max-cpu",
            "last_max-cpu",
            "first_hitch-count",
            "last_hitch-count",
            "delta_hitch-count",
            "first_total-hitches",
            "last_total-hitches",
            "delta_total-hitches",
            "first_frame-rate",
            "last_frame-rate",
            "delta_frame-rate",
            "first_fps",
            "last_fps",
            "delta_fps",
        ):
            if key in primary:
                lines.append(f"{key.replace('-', '_')}={primary[key]}")

    lines.append(f"schema_summaries={json.dumps(summaries, separators=(',', ':'))}")
    out_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Extract summary metrics from a .trace file")
    parser.add_argument("--trace", required=True, help="Path to .trace file")
    parser.add_argument("--out", required=True, help="Text output file")
    parser.add_argument("--json-out", required=False, help="JSON output file")
    parser.add_argument("--run", default="1", help="Run number inside trace (default: 1)")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    trace_path = Path(args.trace)
    out_path = Path(args.out)
    json_out_path = Path(args.json_out) if args.json_out else None

    if not trace_path.exists():
        raise FileNotFoundError(f"Trace not found: {trace_path}")

    schemas, runs = parse_toc(trace_path)
    run_number = args.run if args.run in runs else (runs[0] if runs else args.run)

    summaries: list[dict[str, Any]] = []
    for schema in schemas:
        rows = try_export_table(trace_path, schema, run_number)
        summaries.append(summarize_schema_rows(schema, rows))

    primary = choose_primary_summary(summaries)

    out_path.parent.mkdir(parents=True, exist_ok=True)
    write_text_report(out_path, trace_path, run_number, schemas, primary, summaries)

    if json_out_path:
        payload = {
            "trace": str(trace_path),
            "run": run_number,
            "available_schemas": schemas,
            "selected": primary,
            "schemas": summaries,
        }
        json_out_path.parent.mkdir(parents=True, exist_ok=True)
        json_out_path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
