#!/bin/bash

set -euo pipefail

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/prisma-hooks-setup-test.XXXXXX")"
trap 'rm -rf "${TMP_ROOT}"' EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

fixture="${TMP_ROOT}/repo"
mkdir -p "${fixture}/scripts/lib" "${fixture}/scripts/hooks"
cp "${SCRIPT_ROOT}/scripts/lib/configure-git-hooks.sh" "${fixture}/scripts/lib/"
touch "${fixture}/scripts/hooks/pre-commit" \
    "${fixture}/scripts/hooks/pre-push" \
    "${fixture}/scripts/hooks/first-commit-version-bump.sh"

git -C "${fixture}" init -q
git -C "${fixture}" config user.email hooks-setup-test@example.invalid
git -C "${fixture}" config user.name hooks-setup-test

# shellcheck source=/dev/null
source "${fixture}/scripts/lib/configure-git-hooks.sh"
configure_git_hooks "${fixture}" || fail "configure_git_hooks failed"

hooks_path="$(git -C "${fixture}" config --local --get core.hooksPath)"
test "${hooks_path}" = "scripts/hooks" || fail "expected scripts/hooks, got ${hooks_path}"

non_exec="$(find "${fixture}/scripts/hooks" -maxdepth 1 -type f ! -perm -u+x -print)"
test -z "${non_exec}" || fail "non-executable hooks: ${non_exec}"

echo "HOOKS_SETUP_TEST_STATUS=PASS"
