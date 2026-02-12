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

cd "${PROJECT_ROOT}"

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
