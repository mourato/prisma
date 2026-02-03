#!/bin/bash
# MARK: - Lint Script for MeetingAssistant
# Runs SwiftLint with the project configuration

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "🔍 Running SwiftLint..."
echo ""

cd "${PROJECT_ROOT}"

if ! command -v swiftlint &> /dev/null; then
    echo "❌ SwiftLint not installed. Install with: brew install swiftlint"
    exit 1
fi

if ! command -v swiftformat &> /dev/null; then
    echo "❌ SwiftFormat not installed. Install with: brew install swiftformat"
    exit 1
fi

SWIFTLINT_CACHE_PATH="${PROJECT_ROOT}/.swiftlint-cache"
mkdir -p "${SWIFTLINT_CACHE_PATH}"
export SWIFTLINT_CACHE_PATH

TMPDIR="${PROJECT_ROOT}/.tmp"
mkdir -p "${TMPDIR}"
export TMPDIR

# Lint App and Packages sources
SOURCES="App Packages/MeetingAssistantCore/Sources"

swiftlint lint --config .swiftlint.yml ${SOURCES}
swiftformat --lint --config .swiftformat ${SOURCES}

# Get counts
WARNINGS=$(swiftlint lint --config .swiftlint.yml ${SOURCES} 2>/dev/null | grep -c "warning:" || echo "0")

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Total warnings: ${WARNINGS}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
