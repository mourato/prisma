#!/bin/bash
# =============================================================================
# preflight.sh - Standard local pre-merge validation checks
# =============================================================================
# Runs the canonical quality gates in sequence:
# 1) build
# 2) test
# 3) lint
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=scripts/lib/agent-output.sh
source "${SCRIPT_DIR}/lib/agent-output.sh"

AGENT_MODE=0
if ma_agent_mode_enabled; then
    AGENT_MODE=1
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        --agent)
            AGENT_MODE=1
            MA_AGENT_MODE=1
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--agent]"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

cd "${PROJECT_ROOT}"

if [ "${AGENT_MODE}" -eq 0 ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Preflight: build + test + lint"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    echo "[1/3] make build"
    make build

    echo "[2/3] make test"
    if ! make test; then
        echo "make test failed; falling back to ./scripts/run-tests.sh"
        ./scripts/run-tests.sh
    fi

    echo "[3/3] make lint"
    make lint

    echo "✓ Preflight completed successfully"
    exit 0
fi

LOG_DIR="$(ma_agent_prepare_log_dir)"
RESULT_PATH="${LOG_DIR}/preflight.result.json"
START_TIME=$(date +%s)

SUMMARY="Preflight completed successfully"
if ! make build-agent; then
    SUMMARY="Preflight failed during build"
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    ma_agent_write_result_json "${RESULT_PATH}" "preflight" "FAIL" "${DURATION}" "${LOG_DIR}" 1 "${SUMMARY}"
    ma_agent_emit_result "preflight" "FAIL" "${DURATION}" "${LOG_DIR}" 1 "${SUMMARY}" "${RESULT_PATH}"
    exit 1
fi

if ! make test-agent; then
    echo "AGENT_NOTE=make test-agent failed; falling back to ./scripts/run-tests.sh --agent"
    if ! MA_AGENT_MODE=1 ./scripts/run-tests.sh --agent; then
        SUMMARY="Preflight failed during test"
        END_TIME=$(date +%s)
        DURATION=$((END_TIME - START_TIME))
        ma_agent_write_result_json "${RESULT_PATH}" "preflight" "FAIL" "${DURATION}" "${LOG_DIR}" 1 "${SUMMARY}"
        ma_agent_emit_result "preflight" "FAIL" "${DURATION}" "${LOG_DIR}" 1 "${SUMMARY}" "${RESULT_PATH}"
        exit 1
    fi
fi

if ! make lint-agent; then
    SUMMARY="Preflight failed during lint"
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    ma_agent_write_result_json "${RESULT_PATH}" "preflight" "FAIL" "${DURATION}" "${LOG_DIR}" 1 "${SUMMARY}"
    ma_agent_emit_result "preflight" "FAIL" "${DURATION}" "${LOG_DIR}" 1 "${SUMMARY}" "${RESULT_PATH}"
    exit 1
fi

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
ma_agent_write_result_json "${RESULT_PATH}" "preflight" "PASS" "${DURATION}" "${LOG_DIR}" 0 "${SUMMARY}"
ma_agent_emit_result "preflight" "PASS" "${DURATION}" "${LOG_DIR}" 0 "${SUMMARY}" "${RESULT_PATH}"
