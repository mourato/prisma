#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/agent-output.sh"

STEP="${1:?step is required}"
ma_agent_prepare_run_dir >/dev/null
LOG_PATH="${MA_AGENT_RUN_DIR}/fixture-${STEP}.log"
RESULT_PATH="${MA_AGENT_RUN_DIR}/fixture-${STEP}.result.json"
: > "${LOG_PATH}"
if [ -n "${WORKFLOW_STEP_LOG:-}" ]; then
    printf '%s\n' "${STEP}" >> "${WORKFLOW_STEP_LOG}"
fi

STATUS="PASS"
ERROR_COUNT=0
SUMMARY="fixture pass"
if [ "${WORKFLOW_FAIL_STEP:-}" = "${STEP}" ]; then
    STATUS="FAIL"
    ERROR_COUNT=1
    SUMMARY="fixture failure"
fi

if [ "${WORKFLOW_INVALID_RESULT_STEP:-}" = "${STEP}" ]; then
    case "${WORKFLOW_INVALID_RESULT_KIND:-malformed}" in
        fail)
            ma_agent_write_result_json "${RESULT_PATH}" "${STEP}" "FAIL" 0 "${LOG_PATH}" 1 "fixture invalid status"
            ;;
        fingerprint)
            MA_AGENT_VALIDATION_FINGERPRINT="fixture-mismatch" \
                ma_agent_write_result_json "${RESULT_PATH}" "${STEP}" "PASS" 0 "${LOG_PATH}" 0 "fixture invalid fingerprint"
            ;;
        malformed)
            printf '{\n' > "${RESULT_PATH}"
            ;;
        schema)
            ma_agent_write_result_json "${RESULT_PATH}" "${STEP}" "PASS" 0 "${LOG_PATH}" 0 "fixture invalid schema"
            python3 - "${RESULT_PATH}" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    result = json.load(handle)
result["schemaVersion"] = 999
with open(sys.argv[1], "w", encoding="utf-8") as handle:
    json.dump(result, handle, separators=(",", ":"))
    handle.write("\n")
PY
            ;;
        *)
            echo "Unknown WORKFLOW_INVALID_RESULT_KIND: ${WORKFLOW_INVALID_RESULT_KIND}" >&2
            exit 2
            ;;
    esac
else
    ma_agent_write_result_json "${RESULT_PATH}" "${STEP}" "${STATUS}" 0 "${LOG_PATH}" "${ERROR_COUNT}" "${SUMMARY}"
fi
ma_agent_emit_result "${STEP}" "${STATUS}" 0 "${LOG_PATH}" "${ERROR_COUNT}" "${SUMMARY}" "${RESULT_PATH}"
[ "${STATUS}" = "PASS" ]
