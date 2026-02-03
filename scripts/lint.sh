#!/bin/bash
# MARK: - Lint Script for MeetingAssistant
# Runs SwiftLint with the project configuration (non-blocking by default)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

STRICT_LINT="${STRICT_LINT:-0}"

echo "🔍 Running SwiftLint..."
echo ""

cd "${PROJECT_ROOT}"

if ! command -v swiftlint &> /dev/null; then
    echo "⚠️  SwiftLint not installed. Install with: brew install swiftlint"
    if [ "$STRICT_LINT" -eq 1 ]; then
        exit 1
    fi
fi

if ! command -v swiftformat &> /dev/null; then
    echo "⚠️  SwiftFormat not installed. Install with: brew install swiftformat"
    if [ "$STRICT_LINT" -eq 1 ]; then
        exit 1
    fi
fi

SWIFTLINT_CACHE_PATH="${PROJECT_ROOT}/.swiftlint-cache"
mkdir -p "${SWIFTLINT_CACHE_PATH}"
export SWIFTLINT_CACHE_PATH

TMPDIR="${PROJECT_ROOT}/.tmp"
mkdir -p "${TMPDIR}"
export TMPDIR

# Lint App and Packages sources
SOURCES="App Packages/MeetingAssistantCore/Sources"

LINT_EXIT=0
FORMAT_EXIT=0

if command -v swiftlint &> /dev/null; then
    swiftlint lint --config .swiftlint.yml ${SOURCES} || LINT_EXIT=$?
fi

if command -v swiftformat &> /dev/null; then
    swiftformat --lint --config .swiftformat ${SOURCES} || FORMAT_EXIT=$?
fi

# Get counts (best-effort)
WARNINGS="0"
if command -v swiftlint &> /dev/null; then
    WARNINGS=$(swiftlint lint --config .swiftlint.yml ${SOURCES} 2>/dev/null | grep -c "warning:" || echo "0")
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Total warnings: ${WARNINGS}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $LINT_EXIT -ne 0 ] || [ $FORMAT_EXIT -ne 0 ]; then
    if [ "$STRICT_LINT" -eq 1 ]; then
        exit 1
    fi
    echo "⚠️  Lint/format issues detected (non-blocking)."
fi
