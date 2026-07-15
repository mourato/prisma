#!/bin/bash
# Configure local Git core.hooksPath to the tracked repository hooks.

set -euo pipefail

configure_git_hooks() {
    local project_root="${1:-}"
    local hooks_relative="scripts/hooks"

    if [[ -z "${project_root}" ]]; then
        project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    fi

    if ! git -C "${project_root}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "Error: not inside a Git worktree (${project_root})" >&2
        return 1
    fi

    local current_path=""
    current_path="$(git -C "${project_root}" config --local --get core.hooksPath 2>/dev/null || true)"

    if [[ -n "${current_path}" && "${current_path}" != "${hooks_relative}" ]]; then
        if [[ "${MA_KEEP_HOOKS_PATH:-0}" == "1" ]]; then
            echo "Skipping hooksPath configuration (MA_KEEP_HOOKS_PATH=1)" >&2
            return 0
        fi
        echo "Warning: overwriting core.hooksPath '${current_path}' with '${hooks_relative}'" >&2
    fi

    git -C "${project_root}" config --local core.hooksPath "${hooks_relative}"

    local hook_file
    for hook_file in pre-commit pre-push first-commit-version-bump.sh; do
        chmod +x "${project_root}/${hooks_relative}/${hook_file}"
    done

    local verified=""
    verified="$(git -C "${project_root}" config --local --get core.hooksPath)"
    if [[ "${verified}" != "${hooks_relative}" ]]; then
        echo "Error: core.hooksPath verification failed (got '${verified}')" >&2
        return 1
    fi

    local non_executable=""
    non_executable="$(find "${project_root}/${hooks_relative}" -maxdepth 1 -type f ! -perm -u+x -print 2>/dev/null || true)"
    if [[ -n "${non_executable}" ]]; then
        echo "Error: hook files lack execute bit:" >&2
        printf '%s\n' "${non_executable}" >&2
        return 1
    fi

    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    configure_git_hooks "${1:-}"
fi
