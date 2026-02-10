#!/usr/bin/env bash

set -euo pipefail

TARGET_DIR="${1:-Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI}"

if ! command -v rg >/dev/null 2>&1; then
  echo "error: 'rg' (ripgrep) is required" >&2
  exit 2
fi

view_files="$(rg -l 'struct[[:space:]]+\w+[[:space:]]*:[[:space:]]*View' "$TARGET_DIR" || true)"
preview_files="$(rg -l '#Preview|PreviewProvider' "$TARGET_DIR" || true)"

if [[ -z "$view_files" ]]; then
  echo "No SwiftUI views found under $TARGET_DIR"
  exit 0
fi

missing="$(comm -23 <(printf "%s\n" "$view_files" | sort -u) <(printf "%s\n" "$preview_files" | sort -u) || true)"

if [[ -n "$missing" ]]; then
  echo "Missing previews in:"
  printf "%s\n" "$missing"
  exit 1
fi

echo "All SwiftUI views under $TARGET_DIR have a preview."
