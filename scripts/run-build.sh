#!/bin/bash
# =============================================================================
# run-build.sh - Build entry point with optional low-noise agent output mode
# =============================================================================

set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=scripts/lib/agent-output.sh
source "${SCRIPT_DIR}/lib/agent-output.sh"

APP_NAME="MeetingAssistant"
XCODEPROJ="${PROJECT_ROOT}/MeetingAssistant.xcodeproj"
DERIVED_DATA="${PROJECT_ROOT}/.xcode-build"

CONFIGURATION="Debug"
AGENT_MODE=0

if ma_agent_mode_enabled; then
    AGENT_MODE=1
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        --configuration|-c)
            CONFIGURATION="$2"
            shift 2
            ;;
        --agent)
            AGENT_MODE=1
            MA_AGENT_MODE=1
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--configuration Debug|Release] [--agent]"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

case "${CONFIGURATION}" in
    Debug|Release)
        ;;
    *)
        echo "Invalid configuration: ${CONFIGURATION}. Use Debug or Release."
        exit 1
        ;;
esac

CONFIG_SLUG="$(echo "${CONFIGURATION}" | tr '[:upper:]' '[:lower:]')"

if [ "${AGENT_MODE}" -eq 1 ]; then
    ma_agent_prepare_sandbox_env "${PROJECT_ROOT}"
    LOG_DIR="$(ma_agent_prepare_log_dir)"
    LOG_PATH="${LOG_DIR}/build-${CONFIG_SLUG}.log"
    RESULT_PATH="${LOG_DIR}/build-${CONFIG_SLUG}.result.json"
else
    LOG_PATH="/tmp/ma-build-${CONFIG_SLUG}.log"
    RESULT_PATH=""
fi

if [ ! -d "${XCODEPROJ}" ]; then
    MSG="Xcode project not found at ${XCODEPROJ}"
    if [ "${AGENT_MODE}" -eq 1 ]; then
        ma_agent_write_result_json "${RESULT_PATH}" "build" "FAIL" 0 "${LOG_PATH}" 1 "${MSG}"
        ma_agent_emit_result "build" "FAIL" 0 "${LOG_PATH}" 1 "${MSG}" "${RESULT_PATH}"
    else
        echo "Error: ${MSG}"
    fi
    exit 1
fi

XCODEBUILD_ARGS=(
    -project "${XCODEPROJ}"
    -scheme "${APP_NAME}"
    -configuration "${CONFIGURATION}"
    -derivedDataPath "${DERIVED_DATA}"
    -destination 'platform=macOS'
)

if [ "${CONFIGURATION}" = "Release" ]; then
    XCODEBUILD_ARGS+=( -enableThreadSanitizer YES )
fi

START_TIME=$(date +%s)
xcodebuild "${XCODEBUILD_ARGS[@]}" build >"${LOG_PATH}" 2>&1
EXIT_CODE=$?
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

ERROR_COUNT="$(ma_agent_error_count "${LOG_PATH}")"
SUMMARY="Build ${CONFIGURATION} failed"
if [ "${EXIT_CODE}" -eq 0 ]; then
    SUMMARY="Build ${CONFIGURATION} succeeded"
elif grep -q "BUILD FAILED" "${LOG_PATH}"; then
    SUMMARY="BUILD FAILED (${CONFIGURATION})"
fi

if [ "${AGENT_MODE}" -eq 1 ]; then
    STATUS="FAIL"
    if [ "${EXIT_CODE}" -eq 0 ]; then
        STATUS="PASS"
    fi

    if [ "${EXIT_CODE}" -ne 0 ]; then
        ma_agent_failure_excerpt "${LOG_PATH}" "error:|fatal error:|BUILD FAILED" 20 80
    fi

    ma_agent_write_result_json "${RESULT_PATH}" "build" "${STATUS}" "${DURATION}" "${LOG_PATH}" "${ERROR_COUNT}" "${SUMMARY}"
    ma_agent_emit_result "build" "${STATUS}" "${DURATION}" "${LOG_PATH}" "${ERROR_COUNT}" "${SUMMARY}" "${RESULT_PATH}"
    exit "${EXIT_CODE}"
fi

echo "Building ${APP_NAME} (${CONFIGURATION})..."
grep -E "(Compiling|Linking|Signing|BUILD|error:|warning:)" "${LOG_PATH}" | head -30 || true
if [ "${EXIT_CODE}" -eq 0 ]; then
    echo "✓ ${CONFIGURATION} build completed"
else
    echo "✗ ${CONFIGURATION} build failed"
    echo "Full output: ${LOG_PATH}"
fi

exit "${EXIT_CODE}"
