#!/usr/bin/env bash
set -euo pipefail

# Determine repo locations before performing updates.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_VERSION_FILE="$REPO_ROOT/Packages/MeetingAssistantCore/Sources/Common/AppVersion.swift"
INFO_PLISTS=(
  "$REPO_ROOT/App/Info.plist"
  "$REPO_ROOT/MeetingAssistantAI/Resources/Info.plist"
)

usage() {
  cat <<'EOF' >&2
Usage: bump-version.sh --version <semantic> --build <number>
  -v | --version  New CFBundleShortVersionString value (e.g. 1.2.3)
  -b | --build    New CFBundleVersion value (e.g. 42)
  -h | --help     Show this help text
EOF
  exit 1
}

version=""
build=""

while [[ $# -gt 0 ]]; do
  case $1 in
    -v|--version)
      if [[ $# -lt 2 ]]; then
        usage
      fi
      version="$2"
      shift 2
      ;;
    -b|--build)
      if [[ $# -lt 2 ]]; then
        usage
      fi
      build="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      ;;
  esac
done

if [[ -z "$version" || -z "$build" ]]; then
  usage
fi

update_app_version_constants() {
  python3 - "$APP_VERSION_FILE" "$version" "$build" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
if not path.is_file():
    raise SystemExit(f"Missing AppVersion file: {path}")
content = path.read_text()
content, version_count = re.subn(r'private static let hardcodedVersion = "[^"]*"',
                                     f'private static let hardcodedVersion = "{sys.argv[2]}"',
                                     content,
                                     count=1)
content, build_count = re.subn(r'private static let hardcodedBuild = "[^"]*"',
                                   f'private static let hardcodedBuild = "{sys.argv[3]}"',
                                   content,
                                   count=1)
if version_count != 1 or build_count != 1:
    raise SystemExit("AppVersion.swift pattern mismatch while updating constants")
path.write_text(content)
PY
}

update_plist_versions() {
  for plist in "${INFO_PLISTS[@]}"; do
    if [[ ! -f "$plist" ]]; then
      echo "Missing plist: $plist" >&2
      exit 1
    fi
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" "$plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build" "$plist"
  done
}

main() {
  update_app_version_constants
  update_plist_versions
  echo "Synchronized version to $version (build $build)"
}

main
