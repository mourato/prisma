#!/bin/bash
# =============================================================================
# create-dmg.sh - Packages MeetingAssistant.app into a .dmg file
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

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Creating ${DMG_NAME}${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check if App Bundle exists
if [ ! -d "${APP_BUNDLE}" ]; then
    echo -e "${YELLOW}App bundle not found at ${APP_BUNDLE}${NC}"
    echo -e "${YELLOW}Building app first...${NC}"
    "${PROJECT_DIR}/scripts/build-app.sh"
fi

# Prepare staging area
echo -e "${YELLOW}[1/3]${NC} Preparing staging area..."
rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"

# Copy App Bundle
echo -e "      Copying ${APP_NAME}.app..."
cp -R "${APP_BUNDLE}" "${STAGING_DIR}/"

# Create Applications symlink
echo -e "      Creating /Applications link..."
ln -s /Applications "${STAGING_DIR}/Applications"

# Create DMG
echo -e "${YELLOW}[2/3]${NC} Creating DMG file..."
rm -f "${DMG_PATH}"
hdiutil create -volname "${APP_NAME}" \
    -srcfolder "${STAGING_DIR}" \
    -ov -format UDZO \
    "${DMG_PATH}"

# Cleanup
echo -e "${YELLOW}[3/3]${NC} Cleaning up..."
rm -rf "${STAGING_DIR}"

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
