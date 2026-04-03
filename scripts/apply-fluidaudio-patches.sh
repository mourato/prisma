#!/bin/bash
# =============================================================================
# apply-fluidaudio-patches.sh - Idempotent local patches for FluidAudio checkouts
# =============================================================================

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

patch_checkout() {
    local checkout_root="$1"
    local asr_manager_path="${checkout_root}/Sources/FluidAudio/ASR/AsrManager.swift"
    local streaming_asr_manager_path="${checkout_root}/Sources/FluidAudio/ASR/Streaming/StreamingAsrManager.swift"

    if [ ! -f "${asr_manager_path}" ]; then
        return 0
    fi

    chmod u+w "${asr_manager_path}" 2>/dev/null || true
    chmod u+w "${streaming_asr_manager_path}" 2>/dev/null || true

    if ! grep -q "public final class AsrManager: @unchecked Sendable {" "${asr_manager_path}"; then
        perl -0pi -e 's/public final class AsrManager(?::\s+Sendable)? \{/public final class AsrManager: \@unchecked Sendable {/g' "${asr_manager_path}"
    fi

    if ! grep -q "public final class AsrManager: @unchecked Sendable {" "${asr_manager_path}"; then
        echo "Failed to patch FluidAudio checkout at ${checkout_root}" >&2
        exit 1
    fi

    if [ -f "${streaming_asr_manager_path}" ]; then
        perl -0pi -e 's/nonisolated\(unsafe\) private var asrManager: AsrManager\?/private var asrManager: AsrManager?/g' "${streaming_asr_manager_path}"
        perl -0pi -e 's/nonisolated\(unsafe\) private var ctcSpotter: CtcKeywordSpotter\?/private var ctcSpotter: CtcKeywordSpotter?/g' "${streaming_asr_manager_path}"
        perl -0pi -e 's/nonisolated\(unsafe\) private var vocabularyRescorer: VocabularyRescorer\?/private var vocabularyRescorer: VocabularyRescorer?/g' "${streaming_asr_manager_path}"

        if grep -q "nonisolated(unsafe) private var asrManager: AsrManager?" "${streaming_asr_manager_path}"; then
            echo "Failed to patch StreamingAsrManager concurrency state at ${checkout_root}" >&2
            exit 1
        fi
    fi
}

checkout_roots=("$@")
if [ "${#checkout_roots[@]}" -eq 0 ]; then
    checkout_roots=(
        "${PROJECT_DIR}/Packages/MeetingAssistantCore/.build/checkouts/FluidAudio"
        "${PROJECT_DIR}/.xcode-build/SourcePackages/checkouts/FluidAudio"
        "${PROJECT_DIR}/.xcode-build-tests/SourcePackages/checkouts/FluidAudio"
        "${PROJECT_DIR}/.xcode-build-ci-parity/SourcePackages/checkouts/FluidAudio"
        "${PROJECT_DIR}/build/DerivedData/SourcePackages/checkouts/FluidAudio"
    )

    if [ -d "${HOME}/Library/Developer/Xcode/DerivedData" ]; then
        while IFS= read -r derived_checkout; do
            checkout_roots+=("${derived_checkout}")
        done < <(
            find "${HOME}/Library/Developer/Xcode/DerivedData" \
                -type d \
                -path '*/SourcePackages/checkouts/FluidAudio' \
                2>/dev/null
        )
    fi
fi

for checkout_root in "${checkout_roots[@]}"; do
    patch_checkout "${checkout_root}"
done
