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

# Lint App and Packages sources
SOURCES="App Packages/MeetingAssistantCore/Sources"

swiftlint lint --config .swiftlint.yml ${SOURCES}

# Get counts
WARNINGS=$(swiftlint lint --config .swiftlint.yml ${SOURCES} 2>/dev/null | grep -c "warning:" || echo "0")

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Total warnings: ${WARNINGS}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
