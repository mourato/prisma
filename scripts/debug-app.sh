#!/bin/bash
# =============================================================================
# debug-app.sh - Builds and runs MeetingAssistant in debug mode via Xcode
# =============================================================================
# Uses xcodebuild for a Debug build. Faster than Release for development.
# =============================================================================

set -e

# Configuration
APP_NAME="MeetingAssistant"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
XCODEPROJ="${PROJECT_DIR}/MeetingAssistant.xcodeproj"
DERIVED_DATA="${PROJECT_DIR}/.xcode-build"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Building ${APP_NAME} (Debug Mode)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check if xcodeproj exists
if [ ! -d "${XCODEPROJ}" ]; then
    echo -e "${RED}Error: Xcode project not found at ${XCODEPROJ}${NC}"
    echo -e "${YELLOW}Run 'xcodegen generate' first to create the project.${NC}"
    exit 1
fi

# Build Debug
echo -e "${YELLOW}[1/2]${NC} Building with xcodebuild (Debug)..."
xcodebuild -project "${XCODEPROJ}" \
    -scheme "${APP_NAME}" \
    -configuration Debug \
    -derivedDataPath "${DERIVED_DATA}" \
    -destination 'platform=macOS' \
    build \
    2>&1 | grep -E "(Compiling|Linking|Signing|BUILD|error:|warning:)" | head -20

BUILD_DIR="${DERIVED_DATA}/Build/Products/Debug"
APP_PATH="${BUILD_DIR}/${APP_NAME}.app"

if [ ! -d "${APP_PATH}" ]; then
    echo -e "${RED}Error: Build failed. App not found at ${APP_PATH}${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Build completed${NC}"

# Run if requested
if [[ "$1" == "--run" || "$1" == "-r" ]]; then
    echo -e "${YELLOW}[2/2]${NC} Running ${APP_NAME}..."
    echo ""
    open "${APP_PATH}"
else
    echo ""
    echo -e "${GREEN}✓ Build successful!${NC}"
    echo ""
    echo -e "App location:"
    echo -e "  ${YELLOW}${APP_PATH}${NC}"
    echo ""
    echo -e "To run the app:"
    echo -e "  ${YELLOW}open \"${APP_PATH}\"${NC}"
    echo -e "  or: ${YELLOW}$0 --run${NC}"
    echo ""
fi
