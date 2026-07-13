#!/bin/bash

# Canonical Fast/Full validation runner with content-addressed PASS evidence.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=scripts/lib/agent-output.sh
source "${SCRIPT_DIR}/lib/agent-output.sh"

RUNNER_SCHEMA_VERSION=1
AGENT_MODE=0
LANE=""
BASE_REF=""
DRY_RUN=0
NO_REUSE=0
START_TIME="$(date +%s)"
OVERALL_STATUS="PASS"
COMMANDS_FILE=""
REASONS_FILE=""
SELECTED_LANE=""
DECISION_STRATEGY="requested"
RUN_DIR=""
FINGERPRINT=""
CACHE_RESULT=""
CHILD_RESULTS=()

usage() {
    cat <<'USAGE'
Usage: ./scripts/validate-agent.sh --lane fast|full|auto [options]

Options:
  --lane LANE           Required: fast, full, or auto
  --base REF            Base ref used for changed-file/risk selection
  --dry-run             Print the selected command graph without executing it
  --no-reuse            Ignore cached PASS evidence and execute the gate
  --agent               Emit compact AGENT_* result lines
  --help, -h            Show this help
USAGE
}

parse_args() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --lane)
                [ "$#" -ge 2 ] || { echo "Error: --lane requires a value."; exit 1; }
                LANE="$2"
                shift 2
                ;;
            --base)
                [ "$#" -ge 2 ] || { echo "Error: --base requires a ref value."; exit 1; }
                BASE_REF="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=1
                shift
                ;;
            --no-reuse)
                NO_REUSE=1
                shift
                ;;
            --agent)
                AGENT_MODE=1
                MA_AGENT_MODE=1
                shift
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    case "${LANE}" in
        fast|full|auto) ;;
        *)
            echo "Error: --lane must be fast, full, or auto."
            exit 1
            ;;
    esac
}

prepare_run() {
    cd "${PROJECT_ROOT}"
    ma_agent_prepare_run_dir >/dev/null
    RUN_DIR="${MA_AGENT_RUN_DIR}"
    COMMANDS_FILE="${RUN_DIR}/validate-agent.commands.tsv"
    REASONS_FILE="${RUN_DIR}/validate-agent.reasons.txt"
    : > "${COMMANDS_FILE}"
    : > "${REASONS_FILE}"
}

base_commit() {
    if [ -z "${BASE_REF}" ]; then
        printf '%s\n' ""
        return
    fi
    if ! git rev-parse --verify --quiet "${BASE_REF}^{commit}" >/dev/null; then
        echo "Error: base ref '${BASE_REF}' does not exist."
        exit 1
    fi
    git rev-parse --verify "${BASE_REF}^{commit}"
}

hash_working_state() {
    {
        printf 'HEAD=%s\n' "$(git rev-parse HEAD)"
        printf 'BASE=%s\n' "$(base_commit)"
        printf '%s\n' 'STAGED_DIFF_BEGIN'
        git diff --cached --binary
        printf '%s\n' 'STAGED_DIFF_END'
        printf '%s\n' 'UNSTAGED_DIFF_BEGIN'
        git diff --binary
        printf '%s\n' 'UNSTAGED_DIFF_END'
        while IFS= read -r path; do
            [ -n "${path}" ] || continue
            printf 'UNTRACKED=%s\n' "${path}"
            if [ -f "${path}" ]; then
                shasum -a 256 "${path}"
            else
                printf '%s\n' 'non-regular-file'
            fi
        done < <(git ls-files --others --exclude-standard | sort)
    } | shasum -a 256 | awk '{print $1}'
}

hash_gate_inputs() {
    {
        while IFS= read -r path; do
            [ -f "${path}" ] || continue
            printf 'PATH=%s\n' "${path}"
            shasum -a 256 "${path}"
        done < <(
            {
                git ls-files -- 'Makefile' 'AGENTS.md' 'scripts' '.agents/docs' '.agents/skills/delivery-workflow' \
                    '.swiftlint.yml' '.swiftformat' 'Package.swift' '*.xcodeproj/project.pbxproj' '*.xcworkspace/*'
            } | sort -u
        )
    } | shasum -a 256 | awk '{print $1}'
}

toolchain_identity_hash() {
    {
        if command -v swift >/dev/null 2>&1; then swift --version 2>&1 || true; else echo 'swift=unavailable'; fi
        if command -v xcodebuild >/dev/null 2>&1; then xcodebuild -version 2>&1 || true; else echo 'xcodebuild=unavailable'; fi
        if command -v swiftlint >/dev/null 2>&1; then swiftlint version 2>&1 || true; else echo 'swiftlint=unavailable'; fi
        if command -v swiftformat >/dev/null 2>&1; then swiftformat --version 2>&1 || true; else echo 'swiftformat=unavailable'; fi
    } | shasum -a 256 | awk '{print $1}'
}

compute_fingerprint() {
    local effective_base
    effective_base="$(base_commit)"
    FINGERPRINT="$({
        printf 'runnerSchema=%s\n' "${RUNNER_SCHEMA_VERSION}"
        printf 'requestedLane=%s\n' "${LANE}"
        printf 'selectedLane=%s\n' "${SELECTED_LANE}"
        printf 'baseRef=%s\n' "${BASE_REF}"
        printf 'baseCommit=%s\n' "${effective_base}"
        printf 'head=%s\n' "$(git rev-parse HEAD)"
        printf 'workingState=%s\n' "$(hash_working_state)"
        printf 'gateInputs=%s\n' "$(hash_gate_inputs)"
        printf 'toolchain=%s\n' "$(toolchain_identity_hash)"
    } | shasum -a 256 | awk '{print $1}')"
}

load_auto_decision() {
    local preview_log="${RUN_DIR}/scope-decision-preview.log"
    local preview_result="${RUN_DIR}/scope-check.result.json"
    local base_args=""
    local decision

    if [ -n "${BASE_REF}" ]; then
        base_args="--base $(printf '%q' "${BASE_REF}")"
    fi
    if ! eval "./scripts/scope-check.sh --dry-run --agent ${base_args}" > "${preview_log}" 2>&1; then
        echo "Error: scope-check could not select an auto lane. See ${preview_log}."
        exit 1
    fi
    if [ ! -f "${preview_result}" ]; then
        echo "Error: scope-check did not produce a machine-readable lane decision."
        exit 1
    fi

    decision="$(python3 - "${preview_result}" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    result = json.load(handle)
decision = result.get("decision", {})
if decision.get("selectedLane") not in {"fast", "full"}:
    raise SystemExit("invalid selected lane")
print(decision["selectedLane"])
print(decision.get("strategy", "scope-check"))
for reason in decision.get("reasons", []):
    print(reason)
PY
    )"
    SELECTED_LANE="$(printf '%s\n' "${decision}" | sed -n '1p')"
    DECISION_STRATEGY="$(printf '%s\n' "${decision}" | sed -n '2p')"
    printf '%s\n' "${decision}" | sed -n '3,$p' > "${REASONS_FILE}"
}

select_lane() {
    if [ "${LANE}" = "auto" ]; then
        load_auto_decision
    else
        SELECTED_LANE="${LANE}"
        DECISION_STRATEGY="requested"
        printf 'requested lane: %s\n' "${LANE}" > "${REASONS_FILE}"
    fi
}

cache_is_valid() {
    local cache_path="$1"
    [ -f "${cache_path}" ] || return 1
    python3 - "${cache_path}" "${FINGERPRINT}" <<'PY'
import json
import os
import re
import sys

path, fingerprint = sys.argv[1:]
def require_logs(value):
    for log_path in re.split(r"[,;]", value or ""):
        if log_path and not os.path.isfile(log_path):
            raise ValueError("missing log")

try:
    with open(path, encoding="utf-8") as handle:
        result = json.load(handle)
    if result.get("schemaVersion") != 2:
        raise ValueError("schema")
    if result.get("status") != "PASS" or result.get("dryRun") is not False:
        raise ValueError("status")
    if result.get("validationFingerprint") != fingerprint:
        raise ValueError("fingerprint")
    if not os.path.isdir(result.get("runDir", "")):
        raise ValueError("run directory")
    for command in result.get("commands", []):
        require_logs(command.get("log"))
    child_results = result.get("childResults")
    if not child_results:
        raise ValueError("children")
    for child_path in child_results:
        if not os.path.isfile(child_path):
            raise ValueError("missing child")
        with open(child_path, encoding="utf-8") as child_handle:
            child = json.load(child_handle)
        if child.get("validationFingerprint") != fingerprint:
            raise ValueError("child fingerprint")
        if child.get("status") != "PASS":
            raise ValueError("child status")
        require_logs(child.get("log"))
        for command in child.get("commands", []):
            require_logs(command.get("log"))
except (OSError, ValueError, json.JSONDecodeError):
    raise SystemExit(1)
PY
}

emit_agent_result() {
    local status="$1"
    local result_path="$2"
    local duration=$(( $(date +%s) - START_TIME ))
    if [ "${DRY_RUN}" -eq 1 ]; then
        return
    fi
    if [ "${AGENT_MODE}" -eq 0 ]; then
        echo "Validation result: status=${status}; lane=${SELECTED_LANE}; fingerprint=${FINGERPRINT}; result=${result_path}"
    fi
    if [ "${AGENT_MODE}" -eq 1 ]; then
        echo "AGENT_STEP=validate-agent"
        echo "AGENT_STATUS=${status}"
        echo "AGENT_DURATION_SEC=${duration}"
        echo "AGENT_LOG=${RUN_DIR}"
        echo "AGENT_ERROR_COUNT=$([ "${status}" = "PASS" ] && echo 0 || echo 1)"
        echo "AGENT_SUMMARY=lane=${SELECTED_LANE}; fingerprint=${FINGERPRINT}"
        echo "AGENT_VALIDATION_FINGERPRINT=${FINGERPRINT}"
        if [ -n "${result_path}" ] && [ "${result_path}" = "${CACHE_RESULT}" ]; then
            echo "AGENT_REUSED=1"
        else
            echo "AGENT_REUSED=0"
        fi
        echo "AGENT_RESULT_JSON=${result_path}"
    fi
}

run_step() {
    local name="$1"
    local command="$2"
    local log_path="${RUN_DIR}/${name}.log"
    local started
    local ended
    local exit_code
    local status
    local result_paths
    local result_csv

    echo "Running ${name}: ${command}"
    started="$(date +%s)"
    if eval "${command}" > "${log_path}" 2>&1; then
        exit_code=0
        status="PASS"
    else
        exit_code=$?
        status="FAIL"
        OVERALL_STATUS="FAIL"
    fi
    ended="$(date +%s)"
    result_paths="$(sed -n 's/^AGENT_RESULT_JSON=//p' "${log_path}" | while IFS= read -r path; do [ -f "${path}" ] && printf '%s\n' "${path}"; done)"
    result_csv="$(printf '%s\n' "${result_paths}" | sed '/^$/d' | paste -sd, -)"
    if [ "${exit_code}" -eq 0 ] && [ -z "${result_csv}" ]; then
        status="INCOMPLETE"
        OVERALL_STATUS="FAIL"
    fi
    printf '%s\t%s\t%s\t%s\t%s\n' "${name}" "${status}" "$((ended - started))" "${log_path}" "${result_csv}" >> "${COMMANDS_FILE}"
    while IFS= read -r path; do
        [ -n "${path}" ] || continue
        CHILD_RESULTS+=("${path}")
    done < <(printf '%s\n' "${result_paths}" | sed '/^$/d')
}

write_aggregate() {
    local result_path="${RUN_DIR}/validate-agent.result.json"
    python3 - "${result_path}" "${FINGERPRINT}" "${SELECTED_LANE}" "${BASE_REF}" "${RUN_DIR}" "${OVERALL_STATUS}" "${COMMANDS_FILE}" "${REASONS_FILE}" "${DECISION_STRATEGY}" <<'PY'
import json
import sys

result_path, fingerprint, lane, base, run_dir, status, commands_path, reasons_path, strategy = sys.argv[1:]
commands = []
child_results = []
with open(commands_path, encoding="utf-8") as handle:
    for line in handle:
        name, step_status, duration, log_path, result_csv = line.rstrip("\n").split("\t")
        result_paths = [item for item in result_csv.split(",") if item]
        commands.append({"name": name, "status": step_status, "durationSec": int(duration), "log": log_path, "resultPaths": result_paths})
        child_results.extend(result_paths)
with open(reasons_path, encoding="utf-8") as handle:
    reasons = [line.rstrip("\n") for line in handle if line.rstrip("\n")]
result = {
    "schemaVersion": 2,
    "step": "validate-agent",
    "status": status,
    "durationSec": sum(item["durationSec"] for item in commands),
    "log": run_dir,
    "errorCount": 0 if status == "PASS" else 1,
    "commands": commands,
    "decision": {"selectedLane": lane, "strategy": strategy, "reasons": reasons},
    "validationFingerprint": fingerprint,
    "dryRun": False,
    "reused": False,
    "runDir": run_dir,
    "base": base,
    "childResults": child_results,
    "summary": f"{lane} validation {status.lower()}"
}
with open(result_path, "w", encoding="utf-8") as handle:
    json.dump(result, handle, separators=(",", ":"))
    handle.write("\n")
PY
    printf '%s\n' "${result_path}"
}

print_dry_run() {
    echo "Validation preview (no evidence recorded):"
    echo "- Requested lane: ${LANE}"
    echo "- Selected lane: ${SELECTED_LANE}"
    echo "- Strategy: ${DECISION_STRATEGY}"
    while IFS= read -r reason; do
        [ -n "${reason}" ] || continue
        echo "- Reason: ${reason}"
    done < "${REASONS_FILE}"
    if [ "${SELECTED_LANE}" = "full" ]; then
        echo "- Command: make lint-strict-agent"
        echo "- Command: make build-test"
    else
        local base_args=""
        if [ -n "${BASE_REF}" ]; then
            base_args=" ARGS=\"--base $(printf '%q' "${BASE_REF}")\""
        fi
        echo "- Command: make scope-check-agent${base_args}"
    fi
    find "${RUN_DIR}" -name '*.result.json' -delete
}

main() {
    local cache_root
    local result_path
    local cache_tmp

    parse_args "$@"
    prepare_run
    select_lane
    compute_fingerprint

    cache_root="$(ma_agent_log_dir)/validate-agent-index"
    CACHE_RESULT="${cache_root}/${FINGERPRINT}.result.json"
    export MA_AGENT_MODE=1
    export MA_AGENT_VALIDATION_FINGERPRINT="${FINGERPRINT}"

    if [ "${DRY_RUN}" -eq 1 ]; then
        print_dry_run
        emit_agent_result "PASS" ""
        return 0
    fi

    if [ "${NO_REUSE}" -eq 0 ] && cache_is_valid "${CACHE_RESULT}"; then
        echo "Reusing PASS evidence: ${CACHE_RESULT}"
        emit_agent_result "PASS" "${CACHE_RESULT}"
        return 0
    fi

    if [ "${SELECTED_LANE}" = "full" ]; then
        run_step "lint-strict" "make lint-strict-agent"
        run_step "build-test" "make build-test"
    else
        local base_args=""
        if [ -n "${BASE_REF}" ]; then
            base_args="ARGS=\"--base $(printf '%q' "${BASE_REF}")\""
        fi
        run_step "scope-check" "make scope-check-agent ${base_args}"
    fi

    result_path="$(write_aggregate)"
    if [ "${OVERALL_STATUS}" = "PASS" ]; then
        mkdir -p "${cache_root}"
        cache_tmp="${CACHE_RESULT}.tmp.$$"
        cp "${result_path}" "${cache_tmp}"
        mv -f "${cache_tmp}" "${CACHE_RESULT}"
    fi
    emit_agent_result "${OVERALL_STATUS}" "${result_path}"
    [ "${OVERALL_STATUS}" = "PASS" ]
}

main "$@"
