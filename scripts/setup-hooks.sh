#!/bin/bash
# MARK: - Install Git Hooks for MeetingAssistant
# Installs project hooks into .git/hooks

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
HOOKS_DIR="${PROJECT_ROOT}/scripts/hooks"
GIT_HOOKS_DIR="${PROJECT_ROOT}/.git/hooks"

if [ ! -d "${GIT_HOOKS_DIR}" ]; then
    echo "❌ .git/hooks not found. Are you in a git repo?"
    exit 1
fi

install_hook() {
    local name="$1"
    if [ -f "${HOOKS_DIR}/${name}" ]; then
        cp "${HOOKS_DIR}/${name}" "${GIT_HOOKS_DIR}/${name}"
        chmod +x "${GIT_HOOKS_DIR}/${name}"
        echo "✅ Installed ${name}"
    fi
}

install_hook "pre-commit"
install_hook "pre-push"

echo ""
echo "🎉 Git hooks installed."
