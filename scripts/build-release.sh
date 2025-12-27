#!/bin/bash
# =============================================================================
# build-release.sh - Builds MeetingAssistant.app using Xcode in Release mode
# =============================================================================
# Uses xcodebuild to create a Release build and exports it to dist/
# =============================================================================

set -e

# Configuration
APP_NAME="MeetingAssistant"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
XCODEPROJ="${PROJECT_DIR}/MeetingAssistant.xcodeproj"
DIST_DIR="${PROJECT_DIR}/dist"
DERIVED_DATA="${PROJECT_DIR}/.xcode-build"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Building ${APP_NAME}.app (Release)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check if xcodeproj exists
if [ ! -d "${XCODEPROJ}" ]; then
    echo -e "${RED}Error: Xcode project not found at ${XCODEPROJ}${NC}"
    echo -e "${YELLOW}Run 'xcodegen generate' first to create the project.${NC}"
    exit 1
fi

# Create dist directory
mkdir -p "${DIST_DIR}"

# Build Release
echo -e "${YELLOW}[1/3]${NC} Building with xcodebuild (Release)..."
xcodebuild -project "${XCODEPROJ}" \
    -scheme "${APP_NAME}" \
    -configuration Release \
    -derivedDataPath "${DERIVED_DATA}" \
    -destination 'platform=macOS' \
    build \
    2>&1 | grep -E "(Compiling|Linking|Signing|BUILD|error:|warning:)" | head -30

# Check build result
BUILD_DIR="${DERIVED_DATA}/Build/Products/Release"
if [ ! -d "${BUILD_DIR}/${APP_NAME}.app" ]; then
    echo -e "${RED}Error: Build failed. App not found at ${BUILD_DIR}/${APP_NAME}.app${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Build completed${NC}"

# Copy to dist
echo -e "${YELLOW}[2/3]${NC} Copying to dist/..."
rm -rf "${DIST_DIR}/${APP_NAME}.app"
cp -R "${BUILD_DIR}/${APP_NAME}.app" "${DIST_DIR}/"
echo -e "${GREEN}✓ App copied to dist/${NC}"

# Code sign (ad-hoc)
echo -e "${YELLOW}[3/3]${NC} Code signing..."
codesign --force --deep --sign - "${DIST_DIR}/${APP_NAME}.app"
echo -e "${GREEN}✓ Code signing completed${NC}"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ Build completed successfully!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "App bundle location:"
echo -e "  ${YELLOW}${DIST_DIR}/${APP_NAME}.app${NC}"
echo ""
echo -e "To run the app:"
echo -e "  ${YELLOW}open \"${DIST_DIR}/${APP_NAME}.app\"${NC}"
echo ""
echo -e "To create a DMG:"
echo -e "  ${YELLOW}./scripts/create-dmg.sh${NC}"
echo ""

# Ask if user wants to run
read -p "Run the app now? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    open "${DIST_DIR}/${APP_NAME}.app"
fi
