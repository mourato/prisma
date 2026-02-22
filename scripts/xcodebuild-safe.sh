#!/bin/bash
# =============================================================================
# xcodebuild-safe.sh - Canonical xcodebuild entrypoint for this repository
# =============================================================================

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
XCODEPROJ="${PROJECT_DIR}/MeetingAssistant.xcodeproj"
DERIVED_DATA_PATH=""

SCHEME="MeetingAssistant"
CONFIGURATION="Debug"
DESTINATION="platform=macOS"
ACTION="build"

EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --scheme)
            SCHEME="$2"
            shift 2
            ;;
        --project)
            XCODEPROJ="$2"
            shift 2
            ;;
        --configuration|-c)
            CONFIGURATION="$2"
            shift 2
            ;;
        --derived-data)
            DERIVED_DATA_PATH="$2"
            shift 2
            ;;
        --destination)
            DESTINATION="$2"
            shift 2
            ;;
        --action)
            ACTION="$2"
            shift 2
            ;;
        --help|-h)
            cat <<'EOF'
Usage: scripts/xcodebuild-safe.sh [options] [-- <extra xcodebuild args>]

Options:
  --scheme <name>            Xcode scheme (default: MeetingAssistant)
    --project <path>           Xcode project path (default: <repo>/MeetingAssistant.xcodeproj)
  --configuration, -c <cfg>  Build configuration (default: Debug)
    --derived-data <path>      Derived data path (optional)
  --destination <dest>       Destination (default: platform=macOS)
  --action <action>          xcodebuild action (default: build)

Examples:
  scripts/xcodebuild-safe.sh
  scripts/xcodebuild-safe.sh --configuration Release
  scripts/xcodebuild-safe.sh --action test -- --enableCodeCoverage YES
EOF
            exit 0
            ;;
        --)
            shift
            EXTRA_ARGS+=("$@")
            break
            ;;
        *)
            EXTRA_ARGS+=("$1")
            shift
            ;;
    esac
done

if [[ ! -d "${XCODEPROJ}" ]]; then
    echo "Error: Xcode project not found at ${XCODEPROJ}" >&2
    exit 1
fi

CMD=(
    xcodebuild
    -project "${XCODEPROJ}"
    -scheme "${SCHEME}"
    -configuration "${CONFIGURATION}"
)

if [[ -n "${DERIVED_DATA_PATH}" ]]; then
    CMD+=( -derivedDataPath "${DERIVED_DATA_PATH}" )
fi

CMD+=(
    -destination "${DESTINATION}"
    "${ACTION}"
)

if [[ ${#EXTRA_ARGS[@]} -gt 0 ]]; then
    CMD+=("${EXTRA_ARGS[@]}")
fi

"${CMD[@]}"
