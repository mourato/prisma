#!/bin/bash
# Shared helpers for low-noise script output used by AI agents.

ma_agent_mode_enabled() {
    case "${MA_AGENT_MODE:-0}" in
        1|true|TRUE|yes|YES)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

ma_agent_log_dir() {
    printf '%s\n' "${MA_AGENT_LOG_DIR:-/tmp/ma-agent}"
}

ma_agent_prepare_log_dir() {
    local dir
    dir="$(ma_agent_log_dir)"
    mkdir -p "${dir}"
    printf '%s\n' "${dir}"
}

ma_agent_prepare_sandbox_env() {
    local project_root="$1"
    local sandbox_root="${project_root}/.tmp/agent-env"
    local home_dir="${sandbox_root}/home"
    local tmp_dir="${sandbox_root}/tmp"

    mkdir -p "${home_dir}" "${tmp_dir}"
    mkdir -p "${home_dir}/.cache/clang/ModuleCache"
    mkdir -p "${home_dir}/Library/Caches/org.swift.swiftpm"
    mkdir -p "${home_dir}/Library/org.swift.swiftpm/configuration"
    mkdir -p "${home_dir}/Library/org.swift.swiftpm/security"

    export HOME="${home_dir}"
    export TMPDIR="${tmp_dir}"
    export CLANG_MODULE_CACHE_PATH="${home_dir}/.cache/clang/ModuleCache"
}

ma_agent_json_escape() {
    local value="$1"
    value=${value//\\/\\\\}
    value=${value//\"/\\\"}
    value=${value//$'\n'/\\n}
    value=${value//$'\r'/}
    value=${value//$'\t'/\\t}
    printf '%s' "${value}"
}

ma_agent_error_count() {
    local log_path="$1"
    local count
    if [ ! -f "${log_path}" ]; then
        printf '0\n'
        return
    fi

    count="$(grep -Eic "error:|fatal error:" "${log_path}" 2>/dev/null || true)"
    if [ -z "${count}" ]; then
        count=0
    fi
    printf '%s\n' "${count}"
}

ma_agent_failure_excerpt() {
    local log_path="$1"
    local pattern="${2:-error:|fatal error:|failed}"
    local max_matches="${3:-20}"
    local tail_lines="${4:-60}"

    if [ ! -f "${log_path}" ]; then
        echo "AGENT_FAILURE_SNIPPET=log-missing"
        return
    fi

    echo "AGENT_FAILURE_SNIPPET_BEGIN"
    grep -Ei "${pattern}" "${log_path}" | head -n "${max_matches}" || true
    echo "AGENT_FAILURE_LOG_TAIL_BEGIN"
    tail -n "${tail_lines}" "${log_path}" || true
    echo "AGENT_FAILURE_LOG_TAIL_END"
    echo "AGENT_FAILURE_SNIPPET_END"
}

ma_agent_write_result_json() {
    local result_path="$1"
    local step="$2"
    local status="$3"
    local duration_sec="$4"
    local log_path="$5"
    local error_count="$6"
    local summary="$7"

    cat > "${result_path}" <<JSON
{"step":"$(ma_agent_json_escape "${step}")","status":"$(ma_agent_json_escape "${status}")","durationSec":${duration_sec},"log":"$(ma_agent_json_escape "${log_path}")","errorCount":${error_count},"summary":"$(ma_agent_json_escape "${summary}")"}
JSON
}

ma_agent_emit_result() {
    local step="$1"
    local status="$2"
    local duration_sec="$3"
    local log_path="$4"
    local error_count="$5"
    local summary="$6"
    local result_path="$7"

    echo "AGENT_STEP=${step}"
    echo "AGENT_STATUS=${status}"
    echo "AGENT_DURATION_SEC=${duration_sec}"
    echo "AGENT_LOG=${log_path}"
    echo "AGENT_ERROR_COUNT=${error_count}"
    echo "AGENT_SUMMARY=${summary}"
    echo "AGENT_RESULT_JSON=${result_path}"
}
