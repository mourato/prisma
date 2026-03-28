#!/bin/bash
# ======================================================================
# run-tests-xcode.sh - Wraps the Xcode-based test run with agent-friendly output
# ======================================================================

set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PACKAGE_DIR="${PROJECT_DIR}/Packages/MeetingAssistantCore"
DERIVED_DATA="${PROJECT_DIR}/.xcode-build"
PATCH_SCRIPT="${PROJECT_DIR}/scripts/apply-fluidaudio-patches.sh"

# shellcheck source=scripts/lib/agent-output.sh
source "${SCRIPT_DIR}/lib/agent-output.sh"

# Colors for user-facing output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

AGENT_MODE=0
QUIET=0
VERBOSE=0
STRICT_XCODE=0
BUNDLE_ERROR_PATTERN="Failed to create a bundle instance representing"
PACKAGE_CONTEXT_ERROR_PATTERN="does not contain an Xcode project, workspace or package"
OVERLAY_TEST_SUITE_IDENTIFIER="MeetingAssistantCoreTests/AssistantOverlayLifecycleTests"
HEARTBEAT_INTERVAL_SEC="${MA_XCODEBUILD_HEARTBEAT_INTERVAL_SEC:-15}"
STRICT_DERIVED_DATA_PATH="${MA_XCODE_STRICT_DERIVED_DATA:-}"

if ma_agent_mode_enabled; then
    AGENT_MODE=1
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        --agent)
            AGENT_MODE=1
            MA_AGENT_MODE=1
            shift
            ;;
        --quiet|-q)
            QUIET=1
            shift
            ;;
        --verbose|-v)
            VERBOSE=1
            shift
            ;;
        --strict-xcode)
            STRICT_XCODE=1
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--agent] [--quiet] [--verbose] [--strict-xcode]"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Enable progress bar for agent mode (after argument parsing)
ma_agent_progress_enable

export MA_SKIP_OVERLAY_LIFECYCLE_TESTS=1

if [ "${STRICT_XCODE}" -eq 1 ]; then
    if [ -z "${STRICT_DERIVED_DATA_PATH}" ]; then
        STRICT_DERIVED_DATA_PATH="$(mktemp -d /tmp/ma-xcode-strict-derived-data.XXXXXX)"
    fi
    DERIVED_DATA="${STRICT_DERIVED_DATA_PATH}"
fi

LOG_PATH="/tmp/ma-test-xcode-$$.log"
RESULT_PATH=""
if [ "${AGENT_MODE}" -eq 1 ]; then
    LOG_DIR="$(ma_agent_prepare_log_dir)"
    LOG_PATH="${LOG_DIR}/test-xcode.log"
    RESULT_PATH="${LOG_DIR}/test-xcode.result.json"
fi

if [ "${AGENT_MODE}" -eq 0 ]; then
    echo -e "${BLUE}Running tests (xcodebuild)...${NC}"
    echo -e "${YELLOW}Uses same build system as Xcode IDE for guaranteed parity${NC}"
    if [ "${STRICT_XCODE}" -eq 1 ]; then
        echo -e "${YELLOW}Strict mode enabled: no recoverable retry or swift test fallback${NC}"
        echo -e "${YELLOW}Strict mode derived data path: ${DERIVED_DATA}${NC}"
    fi
fi

if [ -x "${PATCH_SCRIPT}" ]; then
    (
        cd "${PACKAGE_DIR}"
        xcodebuild -resolvePackageDependencies -scheme MeetingAssistantCore -derivedDataPath "${DERIVED_DATA}" >/dev/null
    )
    "${PATCH_SCRIPT}" "${DERIVED_DATA}/SourcePackages/checkouts/FluidAudio"
fi

run_xcode_tests() {
    cd "${PACKAGE_DIR}"
    local host_arch
    host_arch="$(uname -m)"
    local destination="platform=macOS"
    if [ "${host_arch}" = "arm64" ] || [ "${host_arch}" = "x86_64" ]; then
        destination="platform=macOS,arch=${host_arch}"
    fi

    local xcode_args=(
        -scheme MeetingAssistantCore
        -derivedDataPath "${DERIVED_DATA}"
        -destination "${destination}"
        "-skip-testing:${OVERLAY_TEST_SUITE_IDENTIFIER}"
        test
    )

    # Single-worker execution is more stable for constrained or strict runs.
    if [ "${AGENT_MODE}" -eq 1 ] || [ "${STRICT_XCODE}" -eq 1 ]; then
        xcode_args=(-parallel-testing-enabled NO -jobs 1 "${xcode_args[@]}")
    fi

    xcodebuild \
        "${xcode_args[@]}"
}

is_recoverable_runner_failure() {
    local log_path="$1"
    if [ ! -f "${log_path}" ]; then
        return 1
    fi

    if grep -q "${BUNDLE_ERROR_PATTERN}" "${log_path}"; then
        return 0
    fi

    if grep -q "${PACKAGE_CONTEXT_ERROR_PATTERN}" "${log_path}"; then
        return 0
    fi

    return 1
}

run_xcode_tests_with_heartbeat() {
    (run_xcode_tests) >"${LOG_PATH}" 2>&1 &
    local xcode_pid=$!
    local start_time
    local now
    local next_heartbeat
    local elapsed
    local last_line
    local progress_counts
    local executed
    local passed
    local failed

    start_time=$(date +%s)
    next_heartbeat=$((start_time + HEARTBEAT_INTERVAL_SEC))

    while kill -0 "${xcode_pid}" 2>/dev/null; do
        sleep 1
        now=$(date +%s)
        if [ "${AGENT_MODE}" -eq 0 ] && [ "${QUIET}" -eq 0 ] && [ "${now}" -ge "${next_heartbeat}" ]; then
            elapsed=$((now - start_time))
            if progress_counts="$(ma_agent_extract_running_test_counts "${LOG_PATH}")"; then
                read -r executed passed failed <<< "${progress_counts}"
                echo -e "${BLUE}... still running (${elapsed}s) | Executed: ${executed} | Passed: ${passed} | Failed: ${failed}${NC}"
            else
                last_line="$(tail -n 1 "${LOG_PATH}" 2>/dev/null | tr -d '\r')"
                if [ -n "${last_line}" ]; then
                    echo -e "${BLUE}... still running (${elapsed}s) | ${last_line}${NC}"
                else
                    echo -e "${BLUE}... still running (${elapsed}s)${NC}"
                fi
            fi
            next_heartbeat=$((now + HEARTBEAT_INTERVAL_SEC))
        fi
    done

    wait "${xcode_pid}"
    EXIT_CODE=$?
}

run_swift_fallback_tests() {
    local fallback_log_path="$1"

    if [ "${AGENT_MODE}" -eq 1 ]; then
        MA_AGENT_MODE=0 "${SCRIPT_DIR}/run-tests.sh" --quiet >"${fallback_log_path}" 2>&1
    else
        "${SCRIPT_DIR}/run-tests.sh" --quiet >"${fallback_log_path}" 2>&1
    fi
}

START_TIME=$(date +%s)

# Start progress indicator
if [ "${AGENT_MODE}" -eq 1 ]; then
    ma_agent_progress_start "Running tests (xcodebuild)"
fi

if [ "${VERBOSE}" -eq 1 ] && [ "${AGENT_MODE}" -eq 0 ] && [ "${QUIET}" -eq 0 ]; then
    (run_xcode_tests) 2>&1 | tee "${LOG_PATH}"
    EXIT_CODE=${PIPESTATUS[0]}
else
    run_xcode_tests_with_heartbeat
fi

# Update progress for fallback if needed
if [ "${STRICT_XCODE}" -ne 1 ] && [ "${AGENT_MODE}" -eq 1 ] && [ "${EXIT_CODE}" -ne 0 ] && is_recoverable_runner_failure "${LOG_PATH}"; then
    ma_agent_progress_update "Running tests (swift test fallback)"
fi

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

FALLBACK_USED=0
RETRY_USED=0
FALLBACK_LOG_PATH="${LOG_PATH%.log}-swift-fallback.log"
if [ "${STRICT_XCODE}" -ne 1 ] && [ "${EXIT_CODE}" -ne 0 ] && is_recoverable_runner_failure "${LOG_PATH}"; then
    RETRY_USED=1
    if [ "${AGENT_MODE}" -eq 1 ]; then
        ma_agent_progress_update "Retrying tests (xcodebuild)"
    elif [ "${QUIET}" -eq 0 ]; then
        echo -e "${YELLOW}xcodebuild runner reported recoverable setup error; retrying xcodebuild once...${NC}"
    fi

    RETRY_START_TIME=$(date +%s)
    if [ "${VERBOSE}" -eq 1 ] && [ "${AGENT_MODE}" -eq 0 ] && [ "${QUIET}" -eq 0 ]; then
        (run_xcode_tests) 2>&1 | tee "${LOG_PATH}"
        EXIT_CODE=${PIPESTATUS[0]}
    else
        run_xcode_tests_with_heartbeat
    fi
    RETRY_END_TIME=$(date +%s)
    RETRY_DURATION=$((RETRY_END_TIME - RETRY_START_TIME))
    DURATION=$((DURATION + RETRY_DURATION))
fi

if [ "${STRICT_XCODE}" -ne 1 ] && [ "${EXIT_CODE}" -ne 0 ] && is_recoverable_runner_failure "${LOG_PATH}"; then
    FALLBACK_USED=1
    if [ "${AGENT_MODE}" -eq 0 ] && [ "${QUIET}" -eq 0 ]; then
        echo -e "${YELLOW}xcodebuild runner reported recoverable setup error; retrying via swift test fallback...${NC}"
    fi

    FALLBACK_START_TIME=$(date +%s)
    run_swift_fallback_tests "${FALLBACK_LOG_PATH}"
    FALLBACK_EXIT_CODE=$?
    FALLBACK_END_TIME=$(date +%s)
    FALLBACK_DURATION=$((FALLBACK_END_TIME - FALLBACK_START_TIME))
    DURATION=$((DURATION + FALLBACK_DURATION))

    if [ "${FALLBACK_EXIT_CODE}" -eq 0 ]; then
        EXIT_CODE=0
    fi
fi

METRICS_LOG_PATH="${LOG_PATH}"
if [ "${FALLBACK_USED}" -eq 1 ] && [ -f "${FALLBACK_LOG_PATH}" ]; then
    METRICS_LOG_PATH="${FALLBACK_LOG_PATH}"
fi

TEST_TOTAL=""
TEST_PASSED=""
TEST_FAILED=""
if TEST_COUNTS="$(ma_agent_extract_test_counts "${METRICS_LOG_PATH}")"; then
    read -r TEST_TOTAL TEST_PASSED TEST_FAILED <<< "${TEST_COUNTS}"
fi

RESULT_PREFIX="Tests failed"
if [ "${EXIT_CODE}" -eq 0 ]; then
    RESULT_PREFIX="All tests passed"
    if [ "${FALLBACK_USED}" -eq 1 ]; then
        RESULT_PREFIX="xcodebuild runner failed; swift test fallback passed"
    elif [ "${RETRY_USED}" -eq 1 ]; then
        RESULT_PREFIX="xcodebuild runner failed once; retry passed"
    fi
elif [ "${FALLBACK_USED}" -eq 1 ]; then
    RESULT_PREFIX="xcodebuild runner failed; swift test fallback also failed"
elif [ "${RETRY_USED}" -eq 1 ]; then
    RESULT_PREFIX="xcodebuild runner failed twice"
fi

if [ -n "${TEST_TOTAL}" ]; then
    RESULT_LINE="${RESULT_PREFIX} | Total: ${TEST_TOTAL} | Passed: ${TEST_PASSED} | Failed: ${TEST_FAILED}"
else
    RESULT_LINE="${RESULT_PREFIX}"
fi

if [ "${AGENT_MODE}" -eq 1 ]; then
    STATUS="FAIL"
    if [ "${EXIT_CODE}" -eq 0 ]; then
        STATUS="PASS"
    fi

    if [ "${EXIT_CODE}" -ne 0 ]; then
        ma_agent_failure_excerpt "${LOG_PATH}" "error:|fatal error:|Test Case .* failed|Test Suite .* failed|failed" 20 80
        if [ "${FALLBACK_USED}" -eq 1 ] && [ -f "${FALLBACK_LOG_PATH}" ]; then
            ma_agent_failure_excerpt "${FALLBACK_LOG_PATH}" "error:|fatal error:|Test Case .* failed|Test Suite .* failed|failed" 20 80
        fi
    fi

    ERROR_COUNT="$(ma_agent_error_count "${LOG_PATH}")"
    TEST_FAILURE_COUNT="$(grep -Ec "Test Case .* failed|Test Suite .* failed" "${LOG_PATH}" || true)"
    ERROR_COUNT=$((ERROR_COUNT + TEST_FAILURE_COUNT))
    if [ "${FALLBACK_USED}" -eq 1 ] && [ -f "${FALLBACK_LOG_PATH}" ]; then
        FALLBACK_ERROR_COUNT="$(ma_agent_error_count "${FALLBACK_LOG_PATH}")"
        FALLBACK_TEST_FAILURE_COUNT="$(grep -Ec "Test Case .* failed|Test Suite .* failed" "${FALLBACK_LOG_PATH}" || true)"
        ERROR_COUNT=$((ERROR_COUNT + FALLBACK_ERROR_COUNT + FALLBACK_TEST_FAILURE_COUNT))
    fi

    RESULT_LOG_PATH="${LOG_PATH}"
    if [ "${FALLBACK_USED}" -eq 1 ] && [ -f "${FALLBACK_LOG_PATH}" ]; then
        RESULT_LOG_PATH="${LOG_PATH};${FALLBACK_LOG_PATH}"
    fi

    ma_agent_write_result_json "${RESULT_PATH}" "test" "${STATUS}" "${DURATION}" "${RESULT_LOG_PATH}" "${ERROR_COUNT}" "${RESULT_LINE}"
    ma_agent_emit_result "test" "${STATUS}" "${DURATION}" "${LOG_PATH}" "${ERROR_COUNT}" "${RESULT_LINE}" "${RESULT_PATH}"
    
    # Stop progress indicator
    if [ "${STATUS}" = "PASS" ]; then
        ma_agent_progress_stop "success"
    else
        ma_agent_progress_stop "fail"
    fi
    
    exit "${EXIT_CODE}"
fi

if [ "${EXIT_CODE}" -ne 0 ] && [ "${VERBOSE}" -eq 0 ]; then
    echo ""
    cat "${LOG_PATH}"
    if [ "${FALLBACK_USED}" -eq 1 ] && [ -f "${FALLBACK_LOG_PATH}" ]; then
        echo ""
        cat "${FALLBACK_LOG_PATH}"
    fi
fi

if [ "${EXIT_CODE}" -eq 0 ]; then
    echo -e "${GREEN}✓ ${RESULT_LINE}${NC} (${DURATION}s)"
else
    echo -e "${RED}✗ ${RESULT_LINE}${NC} (${DURATION}s)"
    echo -e "${YELLOW}Full output: ${LOG_PATH}${NC}"
fi

exit "${EXIT_CODE}"
