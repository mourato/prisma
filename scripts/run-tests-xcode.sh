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
        --help|-h)
            echo "Usage: $0 [--agent] [--quiet] [--verbose]"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

export MA_SKIP_OVERLAY_LIFECYCLE_TESTS=1

LOG_PATH="/tmp/test-output.log"
RESULT_PATH=""
if [ "${AGENT_MODE}" -eq 1 ]; then
    LOG_DIR="$(ma_agent_prepare_log_dir)"
    LOG_PATH="${LOG_DIR}/test-xcode.log"
    RESULT_PATH="${LOG_DIR}/test-xcode.result.json"
fi

if [ "${AGENT_MODE}" -eq 0 ]; then
    echo -e "${BLUE}Running tests (xcodebuild)...${NC}"
    echo -e "${YELLOW}Uses same build system as Xcode IDE for guaranteed parity${NC}"
fi

run_xcode_tests() {
    cd "${PACKAGE_DIR}"
    xcodebuild \
        -scheme MeetingAssistantCore \
        -derivedDataPath "${DERIVED_DATA}" \
        -destination 'platform=macOS' \
        test
}

START_TIME=$(date +%s)
if [ "${VERBOSE}" -eq 1 ] && [ "${AGENT_MODE}" -eq 0 ] && [ "${QUIET}" -eq 0 ]; then
    (run_xcode_tests) 2>&1 | tee "${LOG_PATH}"
    EXIT_CODE=${PIPESTATUS[0]}
else
    (run_xcode_tests) >"${LOG_PATH}" 2>&1
    EXIT_CODE=$?
fi
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

if [ "${AGENT_MODE}" -eq 1 ]; then
    STATUS="FAIL"
    RESULT_LINE="Tests failed"
    if [ "${EXIT_CODE}" -eq 0 ]; then
        STATUS="PASS"
        RESULT_LINE="All tests passed"
    fi

    if [ "${EXIT_CODE}" -ne 0 ]; then
        ma_agent_failure_excerpt "${LOG_PATH}" "error:|fatal error:|Test Case .* failed|Test Suite .* failed|failed" 20 80
    fi

    ERROR_COUNT="$(ma_agent_error_count "${LOG_PATH}")"
    ma_agent_write_result_json "${RESULT_PATH}" "test" "${STATUS}" "${DURATION}" "${LOG_PATH}" "${ERROR_COUNT}" "${RESULT_LINE}"
    ma_agent_emit_result "test" "${STATUS}" "${DURATION}" "${LOG_PATH}" "${ERROR_COUNT}" "${RESULT_LINE}" "${RESULT_PATH}"
    exit "${EXIT_CODE}"
fi

if [ "${EXIT_CODE}" -ne 0 ] && [ "${VERBOSE}" -eq 0 ]; then
    echo ""
    cat "${LOG_PATH}"
fi

RESULT_LINE="Tests failed"
if [ "${EXIT_CODE}" -eq 0 ]; then
    RESULT_LINE="All tests passed"
fi

if [ "${EXIT_CODE}" -eq 0 ]; then
    echo -e "${GREEN}✓ ${RESULT_LINE}${NC} (${DURATION}s)"
else
    echo -e "${RED}✗ ${RESULT_LINE}${NC} (${DURATION}s)"
    echo -e "${YELLOW}Full output: ${LOG_PATH}${NC}"
fi

exit "${EXIT_CODE}"
