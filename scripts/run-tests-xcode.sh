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
BUNDLE_ERROR_PATTERN="Failed to create a bundle instance representing"

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

# Enable progress bar for agent mode (after argument parsing)
ma_agent_progress_enable

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
        test
    )

    # Agent runs are more stable with a single build/test worker in constrained environments.
    if [ "${AGENT_MODE}" -eq 1 ]; then
        xcode_args=(-parallel-testing-enabled NO -jobs 1 "${xcode_args[@]}")
    fi

    xcodebuild \
        "${xcode_args[@]}"
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
    (run_xcode_tests) >"${LOG_PATH}" 2>&1
    EXIT_CODE=$?
fi

# Update progress for fallback if needed
if [ "${AGENT_MODE}" -eq 1 ] && [ "${EXIT_CODE}" -ne 0 ] && grep -q "${BUNDLE_ERROR_PATTERN}" "${LOG_PATH}"; then
    ma_agent_progress_update "Running tests (swift test fallback)"
fi

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

FALLBACK_USED=0
RETRY_USED=0
FALLBACK_LOG_PATH="${LOG_PATH%.log}-swift-fallback.log"
if [ "${EXIT_CODE}" -ne 0 ] && grep -q "${BUNDLE_ERROR_PATTERN}" "${LOG_PATH}"; then
    RETRY_USED=1
    if [ "${AGENT_MODE}" -eq 1 ]; then
        ma_agent_progress_update "Retrying tests (xcodebuild)"
    elif [ "${QUIET}" -eq 0 ]; then
        echo -e "${YELLOW}xcodebuild runner failed to instantiate .xctest bundle; retrying xcodebuild once...${NC}"
    fi

    RETRY_START_TIME=$(date +%s)
    if [ "${VERBOSE}" -eq 1 ] && [ "${AGENT_MODE}" -eq 0 ] && [ "${QUIET}" -eq 0 ]; then
        (run_xcode_tests) 2>&1 | tee "${LOG_PATH}"
        EXIT_CODE=${PIPESTATUS[0]}
    else
        (run_xcode_tests) >"${LOG_PATH}" 2>&1
        EXIT_CODE=$?
    fi
    RETRY_END_TIME=$(date +%s)
    RETRY_DURATION=$((RETRY_END_TIME - RETRY_START_TIME))
    DURATION=$((DURATION + RETRY_DURATION))
fi

if [ "${EXIT_CODE}" -ne 0 ] && grep -q "${BUNDLE_ERROR_PATTERN}" "${LOG_PATH}"; then
    FALLBACK_USED=1
    if [ "${AGENT_MODE}" -eq 0 ] && [ "${QUIET}" -eq 0 ]; then
        echo -e "${YELLOW}xcodebuild runner failed to instantiate .xctest bundle; retrying via swift test fallback...${NC}"
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

if [ "${AGENT_MODE}" -eq 1 ]; then
    STATUS="FAIL"
    RESULT_LINE="Tests failed"
    if [ "${EXIT_CODE}" -eq 0 ]; then
        STATUS="PASS"
        RESULT_LINE="All tests passed"
        if [ "${FALLBACK_USED}" -eq 1 ]; then
            RESULT_LINE="xcodebuild runner failed; swift test fallback passed"
        elif [ "${RETRY_USED}" -eq 1 ]; then
            RESULT_LINE="xcodebuild runner failed once; retry passed"
        fi
    elif [ "${FALLBACK_USED}" -eq 1 ]; then
        RESULT_LINE="xcodebuild runner failed; swift test fallback also failed"
    elif [ "${RETRY_USED}" -eq 1 ]; then
        RESULT_LINE="xcodebuild runner failed twice"
    fi

    if [ "${EXIT_CODE}" -ne 0 ]; then
        ma_agent_failure_excerpt "${LOG_PATH}" "error:|fatal error:|Test Case .* failed|Test Suite .* failed|failed" 20 80
        if [ "${FALLBACK_USED}" -eq 1 ] && [ -f "${FALLBACK_LOG_PATH}" ]; then
            ma_agent_failure_excerpt "${FALLBACK_LOG_PATH}" "error:|fatal error:|Test Case .* failed|Test Suite .* failed|failed" 20 80
        fi
    fi

    ERROR_COUNT="$(ma_agent_error_count "${LOG_PATH}")"
    if [ "${FALLBACK_USED}" -eq 1 ] && [ -f "${FALLBACK_LOG_PATH}" ]; then
        FALLBACK_ERROR_COUNT="$(ma_agent_error_count "${FALLBACK_LOG_PATH}")"
        ERROR_COUNT=$((ERROR_COUNT + FALLBACK_ERROR_COUNT))
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

RESULT_LINE="Tests failed"
if [ "${EXIT_CODE}" -eq 0 ]; then
    RESULT_LINE="All tests passed"
    if [ "${FALLBACK_USED}" -eq 1 ]; then
        RESULT_LINE="xcodebuild runner failed; swift test fallback passed"
    elif [ "${RETRY_USED}" -eq 1 ]; then
        RESULT_LINE="xcodebuild runner failed once; retry passed"
    fi
elif [ "${FALLBACK_USED}" -eq 1 ]; then
    RESULT_LINE="xcodebuild runner failed; swift test fallback also failed"
elif [ "${RETRY_USED}" -eq 1 ]; then
    RESULT_LINE="xcodebuild runner failed twice"
fi

if [ "${EXIT_CODE}" -eq 0 ]; then
    echo -e "${GREEN}✓ ${RESULT_LINE}${NC} (${DURATION}s)"
else
    echo -e "${RED}✗ ${RESULT_LINE}${NC} (${DURATION}s)"
    echo -e "${YELLOW}Full output: ${LOG_PATH}${NC}"
fi

exit "${EXIT_CODE}"
