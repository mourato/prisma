#!/bin/bash
# Lightweight PR heuristics (warnings only).
# Intended to replace Danger-Swift rules with native GitHub Actions output.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_ROOT}"

BASE_REF="${GITHUB_BASE_REF:-main}"

if ! git rev-parse --verify "origin/${BASE_REF}" >/dev/null 2>&1; then
    git fetch --no-tags origin "${BASE_REF}:${BASE_REF}" >/dev/null 2>&1 || true
    git fetch --no-tags origin "${BASE_REF}" >/dev/null 2>&1 || true
fi

RANGE="origin/${BASE_REF}...HEAD"

changed_files="$(git diff --name-only "${RANGE}" || true)"
swift_files="$(printf "%s\n" "${changed_files}" | grep -E '\\.swift$' | grep -Ev 'GeneratedMocks\\.swift$' || true)"

additions="$(
    git diff --numstat "${RANGE}" \
        | awk '{ add += $1 } END { print add+0 }'
)"

if [ "${additions}" -gt 500 ]; then
    echo "::warning::PR is quite large (${additions} additions). Consider splitting for easier review."
fi

has_test_changes="0"
if printf "%s\n" "${changed_files}" | grep -q "Tests"; then
    has_test_changes="1"
fi

if [ -n "${swift_files}" ] && [ "${has_test_changes}" -eq 0 ]; then
    echo "::warning::Swift files changed but no test changes detected. Consider adding/updating tests where reasonable."
fi

if [ "${GITHUB_EVENT_NAME:-}" = "pull_request" ] && [ -n "${GITHUB_EVENT_PATH:-}" ] && [ -f "${GITHUB_EVENT_PATH}" ]; then
    python3 - <<'PY'
import json
import os

path = os.environ.get("GITHUB_EVENT_PATH")
with open(path, "r", encoding="utf-8") as f:
    event = json.load(f)

pr = event.get("pull_request") or {}
body = (pr.get("body") or "").strip()
if len(body) < 10:
    print("::warning::Please add a more detailed PR description (what/why).")
PY
fi

commit_subjects="$(git log --format=%s "origin/${BASE_REF}..HEAD" || true)"
if [ -n "${commit_subjects}" ]; then
    while IFS= read -r subject; do
        trimmed="$(echo "${subject}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
        if [ -n "${trimmed}" ] && [ "${#trimmed}" -lt 10 ]; then
            echo "::warning::Commit message '${trimmed}' is quite short; consider adding more context."
        fi
    done <<< "${commit_subjects}"
fi

if [ -n "${swift_files}" ]; then
    while IFS= read -r file; do
        [ -f "${file}" ] || continue

        if [[ "${file}" == *"/Tests/"* ]] || [[ "${file}" == *"Tests/"* ]] || [[ "${file}" == *"Test"* ]]; then
            continue
        fi

        if grep -qE "print\(|debugPrint\(" "${file}"; then
            echo "::warning file=${file}::Print/debugPrint detected. Prefer Logger/OSLog for production code."
        fi

        if grep -qiE "TODO:|FIXME:" "${file}"; then
            echo "::warning file=${file}::TODO/FIXME found. Consider tracking it explicitly or addressing before merge."
        fi

        if grep -q "public " "${file}" && ! grep -q "///" "${file}"; then
            echo "::warning file=${file}::Public APIs detected without DocC comments (///). Consider documenting."
        fi

        if grep -qE "[a-zA-Z0-9)]!" "${file}"; then
            echo "::warning file=${file}::Potential force-unwrap detected. Prefer guard/optional binding when possible."
        fi
    done <<< "${swift_files}"
fi

echo "PR checks completed."
