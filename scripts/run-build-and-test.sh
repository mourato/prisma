#!/bin/bash
# =============================================================================
# run-build-and-test.sh - Sequential build + test with concise progress output
# =============================================================================

set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_step() {
    local pct="$1"
    local msg="$2"
    printf "[%s%%] %s\n" "${pct}" "${msg}"
}

extract_agent_field() {
    local field="$1"
    local log_file="$2"
    grep -E "^${field}=" "${log_file}" | tail -n 1 | cut -d'=' -f2-
}

run_step() {
    local label="$1"
    local pct_start="$2"
    local cmd="$3"
    local out_file="$4"

    print_step "${pct_start}" "${label}"
    eval "${cmd}" > "${out_file}" 2>&1
    local exit_code=$?

    local status summary duration
    status="$(extract_agent_field "AGENT_STATUS" "${out_file}")"
    summary="$(extract_agent_field "AGENT_SUMMARY" "${out_file}")"
    duration="$(extract_agent_field "AGENT_DURATION_SEC" "${out_file}")"

    if [ -z "${status}" ]; then
        status="FAIL"
    fi

    if [ -z "${duration}" ]; then
        duration="0"
    fi

    if [ -z "${summary}" ]; then
        summary="${label} failed"
    fi

    printf "      %s (%ss)\n" "${summary}" "${duration}"

    if [ "${exit_code}" -ne 0 ]; then
        echo ""
        sed -n '/AGENT_FAILURE_SNIPPET_BEGIN/,/AGENT_FAILURE_SNIPPET_END/p' "${out_file}" || true
    fi

    return "${exit_code}"
}

LOG_DIR="${MA_AGENT_LOG_DIR:-/tmp/ma-agent}"
mkdir -p "${LOG_DIR}"

BUILD_OUT="${LOG_DIR}/build-test-build.step.log"
TEST_OUT="${LOG_DIR}/build-test-test.step.log"

run_step "Build" "0" "MA_AGENT_MODE=1 ./scripts/run-build.sh --configuration Debug --agent" "${BUILD_OUT}" || exit $?
run_step "Test" "50" "MA_AGENT_MODE=1 ./scripts/run-tests-xcode.sh --agent" "${TEST_OUT}" || exit $?

print_step "100" "Build + Test completed"
