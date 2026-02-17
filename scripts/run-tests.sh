#!/bin/bash
# =============================================================================
# run-tests.sh - Runs tests for MeetingAssistant with formatted output
# =============================================================================

set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
XCODEPROJ="${PROJECT_DIR}/MeetingAssistant.xcodeproj"

# shellcheck source=scripts/lib/agent-output.sh
source "${SCRIPT_DIR}/lib/agent-output.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default values
VERBOSE=0
QUIET=0
STRICT=0
AGENT_MODE=0
SPECIFIC_TEST=""
TEST_FILE=""

if ma_agent_mode_enabled; then
    AGENT_MODE=1
fi

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose|-v)
            VERBOSE=1
            shift
            ;;
        --quiet|-q)
            QUIET=1
            shift
            ;;
        --strict|-s)
            STRICT=1
            shift
            ;;
        --agent)
            AGENT_MODE=1
            MA_AGENT_MODE=1
            shift
            ;;
        --test|-t)
            SPECIFIC_TEST="$2"
            shift 2
            ;;
        --file|-f)
            TEST_FILE="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --verbose, -v    Run tests with verbose output"
            echo "  --quiet, -q      Run tests quietly (no output except final result)"
            echo "  --strict, -s     Run tests with strict concurrency checking"
            echo "  --agent          Emit compact machine-readable result lines"
            echo "  --test, -t TEST  Run specific test (e.g., testInitialState)"
            echo "  --file, -f FILE  Run tests from specific file (e.g., RecordingViewModelTests)"
            echo "  --help, -h       Show this help"
            echo ""
            echo "Examples:"
            echo "  $0"
            echo "  $0 --verbose"
            echo "  $0 --quiet"
            echo "  $0 --agent"
            echo "  $0 --file RecordingViewModelTests"
            echo "  $0 --test testInitialState"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

if [ ! -d "${XCODEPROJ}" ]; then
    MESSAGE="Xcode project not found at ${XCODEPROJ}"
    if [ "${AGENT_MODE}" -eq 1 ]; then
        LOG_DIR="$(ma_agent_prepare_log_dir)"
        LOG_PATH="${LOG_DIR}/test-swift.log"
        RESULT_PATH="${LOG_DIR}/test-swift.result.json"
        ma_agent_write_result_json "${RESULT_PATH}" "test" "FAIL" 0 "${LOG_PATH}" 1 "${MESSAGE}"
        ma_agent_emit_result "test" "FAIL" 0 "${LOG_PATH}" 1 "${MESSAGE}" "${RESULT_PATH}"
    else
        echo -e "${RED}Error: ${MESSAGE}${NC}"
        echo -e "${YELLOW}Ensure you are in the repo root and that MeetingAssistant.xcodeproj exists.${NC}"
    fi
    exit 1
fi

# Auto-enable verbose output in CI for better diagnostics outside agent mode
if [ "${CI:-}" = "true" ] && [ "${VERBOSE}" -eq 0 ] && [ "${AGENT_MODE}" -eq 0 ]; then
    VERBOSE=1
fi

# Enable Swift backtraces on crashes in CI
if [ "${CI:-}" = "true" ]; then
    export SWIFT_BACKTRACE=enable
    export SWIFT_BACKTRACE_MODE=full
fi

# Overlay lifecycle tests rely on AppKit windowing behavior that is unstable in
# Swift Package CLI runners without a fully interactive app host.
export MA_SKIP_OVERLAY_LIFECYCLE_TESTS=1

TEST_ARGS=()
TARGET_DESCRIPTION="all tests"
TARGET_LABEL="all"
if [ -n "${TEST_FILE}" ]; then
    TEST_ARGS+=(--filter "${TEST_FILE}")
    TARGET_DESCRIPTION="tests from file: ${TEST_FILE}"
    TARGET_LABEL="${TEST_FILE}"
elif [ -n "${SPECIFIC_TEST}" ]; then
    TEST_ARGS+=(--filter "${SPECIFIC_TEST}")
    TARGET_DESCRIPTION="specific test: ${SPECIFIC_TEST}"
    TARGET_LABEL="${SPECIFIC_TEST}"
fi

if [ "${VERBOSE}" -eq 1 ]; then
    TEST_ARGS+=(--verbose)
fi

if [ "${STRICT}" -eq 1 ]; then
    TEST_ARGS+=(-Xswiftc -strict-concurrency=complete)
fi

SAFE_TARGET_LABEL="$(echo "${TARGET_LABEL}" | tr -cs '[:alnum:]' '_' | sed 's/^_//; s/_$//')"
if [ -z "${SAFE_TARGET_LABEL}" ]; then
    SAFE_TARGET_LABEL="all"
fi

if [ "${AGENT_MODE}" -eq 1 ]; then
    ma_agent_prepare_sandbox_env "${PROJECT_DIR}"
    LOG_DIR="$(ma_agent_prepare_log_dir)"
    LOG_PATH="${LOG_DIR}/test-swift-${SAFE_TARGET_LABEL}.log"
    RESULT_PATH="${LOG_DIR}/test-swift-${SAFE_TARGET_LABEL}.result.json"
else
    LOG_PATH="/tmp/ma-test-swift-${SAFE_TARGET_LABEL}.log"
    RESULT_PATH=""
fi

if [ "${QUIET}" -eq 0 ] && [ "${AGENT_MODE}" -eq 0 ]; then
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  Running Tests (${TARGET_DESCRIPTION})${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
fi

run_swift_tests() {
    cd "${PROJECT_DIR}/Packages/MeetingAssistantCore"
    if [ "${#TEST_ARGS[@]}" -gt 0 ]; then
        swift test "${TEST_ARGS[@]}"
    else
        swift test
    fi
}

START_TIME=$(date +%s)
if [ "${VERBOSE}" -eq 1 ] && [ "${AGENT_MODE}" -eq 0 ] && [ "${QUIET}" -eq 0 ]; then
    (run_swift_tests) 2>&1 | tee "${LOG_PATH}"
    EXIT_CODE=${PIPESTATUS[0]}
else
    (run_swift_tests) >"${LOG_PATH}" 2>&1
    EXIT_CODE=$?
fi
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

RESULT_LINE="$(grep -E "Executed [0-9]+ tests?, with [0-9]+ failures?" "${LOG_PATH}" | tail -n 1 || true)"
if [ -z "${RESULT_LINE}" ] && [ "${EXIT_CODE}" -eq 0 ]; then
    RESULT_LINE="All tests passed"
elif [ -z "${RESULT_LINE}" ]; then
    RESULT_LINE="Tests failed"
fi

COMPILER_ERROR_COUNT="$(ma_agent_error_count "${LOG_PATH}")"
TEST_FAILURE_COUNT="$(grep -Eic "Test Case .* failed|Test Suite .* failed" "${LOG_PATH}" || true)"
ERROR_COUNT=$((COMPILER_ERROR_COUNT + TEST_FAILURE_COUNT))

if [ "${AGENT_MODE}" -eq 1 ]; then
    STATUS="FAIL"
    if [ "${EXIT_CODE}" -eq 0 ]; then
        STATUS="PASS"
    fi

    if [ "${EXIT_CODE}" -ne 0 ]; then
        ma_agent_failure_excerpt "${LOG_PATH}" "error:|fatal error:|Test Case .* failed|Test Suite .* failed|failed" 20 80
    fi

    ma_agent_write_result_json "${RESULT_PATH}" "test" "${STATUS}" "${DURATION}" "${LOG_PATH}" "${ERROR_COUNT}" "${RESULT_LINE}"
    ma_agent_emit_result "test" "${STATUS}" "${DURATION}" "${LOG_PATH}" "${ERROR_COUNT}" "${RESULT_LINE}" "${RESULT_PATH}"
    exit "${EXIT_CODE}"
fi

if [ "${EXIT_CODE}" -ne 0 ] && [ "${VERBOSE}" -eq 0 ]; then
    echo ""
    cat "${LOG_PATH}"
fi

if [ "${EXIT_CODE}" -eq 0 ]; then
    echo -e "${GREEN}✓ ${RESULT_LINE}${NC} (${DURATION}s)"
else
    echo -e "${RED}✗ ${RESULT_LINE}${NC} (${DURATION}s)"
    echo -e "${YELLOW}Full output: ${LOG_PATH}${NC}"
fi

if [ "${QUIET}" -eq 0 ]; then
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
fi

exit "${EXIT_CODE}"
