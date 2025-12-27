#!/bin/bash
# =============================================================================
# debug-app.sh - Builds and runs MeetingAssistant in debug mode
# =============================================================================
# Fast development build with debug symbols. Does not create full app bundle.
# =============================================================================

set -e  # Exit on any error

# Configuration
APP_NAME="MeetingAssistant"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/.build/debug"

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

# Step 1: Build the Swift package in debug mode
echo -e "${YELLOW}[1/2]${NC} Building Swift package (debug mode)..."
cd "${PROJECT_DIR}"
swift build

if [ ! -f "${BUILD_DIR}/${APP_NAME}" ]; then
    echo -e "${RED}Error: Build failed. Executable not found at ${BUILD_DIR}/${APP_NAME}${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Build completed${NC}"

# Step 2: Run the app (optional, controlled by argument)
if [[ "$1" == "--run" || "$1" == "-r" ]]; then
    echo -e "${YELLOW}[2/2]${NC} Running ${APP_NAME}..."
    echo ""
    "${BUILD_DIR}/${APP_NAME}"
else
    echo ""
    echo -e "${GREEN}✓ Build successful!${NC}"
    echo ""
    echo -e "Executable location:"
    echo -e "  ${YELLOW}${BUILD_DIR}/${APP_NAME}${NC}"
    echo ""
    echo -e "To run the app:"
    echo -e "  ${YELLOW}${BUILD_DIR}/${APP_NAME}${NC}"
    echo -e "  or: ${YELLOW}$0 --run${NC}"
    echo ""
fi
