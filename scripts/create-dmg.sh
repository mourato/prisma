#!/bin/bash
# =============================================================================
# create-dmg.sh - Packages MeetingAssistant.app into a .dmg file
# =============================================================================
# Works with the new Xcode project structure. Will build Release if needed.
# =============================================================================

set -e

# Configuration
APP_NAME="MeetingAssistant"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="${PROJECT_DIR}/dist"
APP_BUNDLE="${DIST_DIR}/${APP_NAME}.app"
DMG_NAME="${APP_NAME}.dmg"
DMG_PATH="${DIST_DIR}/${DMG_NAME}"
STAGING_DIR="${DIST_DIR}/dmg_staging"
RW_DMG_PATH="${DIST_DIR}/${APP_NAME}-rw.dmg"
MOUNT_POINT="${DIST_DIR}/dmg_mount"
DMG_ICON_SIZE="${DMG_ICON_SIZE:-160}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

cleanup() {
    set +e
    if mount | grep -Fq "on ${MOUNT_POINT} "; then
        hdiutil detach "${MOUNT_POINT}" -quiet || hdiutil detach "${MOUNT_POINT}" -force -quiet
    fi
    rm -rf "${STAGING_DIR}" "${MOUNT_POINT}"
    rm -f "${RW_DMG_PATH}"
}

apply_finder_layout() {
    local mount_point="$1"
    local icon_size="$2"
    local escaped_mount_point
    local script_output

    escaped_mount_point="${mount_point//\"/\\\"}"
    if ! script_output="$(osascript <<EOF 2>&1
set dmgFolder to POSIX file "${escaped_mount_point}" as alias

tell application "Finder"
    tell folder dmgFolder
        open
        set current view of container window to icon view
        tell icon view options of container window
            set arrangement to not arranged
            set icon size to ${icon_size}
        end tell
        delay 0.5
        close
    end tell
end tell
EOF
)"; then
        echo -e "${YELLOW}Warning: Could not apply Finder layout customization.${NC}"
        echo -e "         Reason: ${script_output}"
        return 1
    fi

    sync
    return 0
}

trap cleanup EXIT

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Creating ${DMG_NAME}${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Always build Release version
echo -e "${YELLOW}Building Release version...${NC}"
echo ""
if [[ "$1" == "--ci" || "$1" == "--no-interactive" ]]; then
    "${PROJECT_DIR}/scripts/build-release.sh" --ci
else
    "${PROJECT_DIR}/scripts/build-release.sh" <<< "n"
fi
echo ""

# Verify app exists after build
if [ ! -d "${APP_BUNDLE}" ]; then
    echo -e "${RED}Error: App bundle still not found after build.${NC}"
    exit 1
fi

# Prepare staging area
echo -e "${YELLOW}[1/5]${NC} Preparing staging area..."
rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"

# Copy App Bundle
echo -e "      Copying ${APP_NAME}.app..."
cp -R "${APP_BUNDLE}" "${STAGING_DIR}/"

# Create Applications symlink
echo -e "      Creating /Applications link..."
ln -s /Applications "${STAGING_DIR}/Applications"

# Create writable DMG
echo -e "${YELLOW}[2/5]${NC} Creating writable DMG..."
rm -f "${DMG_PATH}" "${RW_DMG_PATH}"
hdiutil create -volname "${APP_NAME}" \
    -srcfolder "${STAGING_DIR}" \
    -ov -format UDRW \
    "${RW_DMG_PATH}"

# Mount and customize Finder view options
echo -e "${YELLOW}[3/5]${NC} Customizing Finder view..."
rm -rf "${MOUNT_POINT}"
mkdir -p "${MOUNT_POINT}"
hdiutil attach "${RW_DMG_PATH}" -nobrowse -quiet -mountpoint "${MOUNT_POINT}"
if apply_finder_layout "${MOUNT_POINT}" "${DMG_ICON_SIZE}"; then
    echo -e "      Applied icon size: ${DMG_ICON_SIZE}px"
else
    echo -e "      Continuing with default Finder layout."
fi
hdiutil detach "${MOUNT_POINT}" -quiet || hdiutil detach "${MOUNT_POINT}" -force -quiet
rm -rf "${MOUNT_POINT}"

# Convert writable DMG to compressed DMG
echo -e "${YELLOW}[4/5]${NC} Finalizing compressed DMG..."
hdiutil convert "${RW_DMG_PATH}" \
    -ov -format UDZO \
    -o "${DMG_PATH%.dmg}"

# Cleanup temporary files
echo -e "${YELLOW}[5/5]${NC} Cleaning up temporary files..."
rm -rf "${STAGING_DIR}" "${MOUNT_POINT}"
rm -f "${RW_DMG_PATH}"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ DMG created successfully!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "File location:"
echo -e "  ${YELLOW}${DMG_PATH}${NC}"
echo ""
echo -e "To open in Finder:"
echo -e "  ${YELLOW}open -R \"${DMG_PATH}\"${NC}"
echo ""

# Ask if user wants to open the DMG (skip in CI mode)
if [[ "$1" != "--ci" && "$1" != "--no-interactive" ]]; then
    read -p "Do you want to open the new DMG file? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        open "${DMG_PATH}"
    fi
fi
