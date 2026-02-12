#!/bin/bash
# =============================================================================
# debug-app.sh - Builds and runs MeetingAssistant in debug mode via CLI
# =============================================================================
# Uses xcodebuild for a Debug build. Faster than Release for development.
# CLI-first workflow with optional test execution.
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
    echo -e "${YELLOW}Ensure you are in the repo root and that MeetingAssistant.xcodeproj exists.${NC}"
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

# Handle command line arguments
if [[ "$1" == "--test" || "$1" == "-t" ]]; then
    echo -e "${YELLOW}[2/2]${NC} Running tests..."
    echo ""
    TEST_LOG="${PROJECT_DIR}/.xcode-build/test-output.log"
    mkdir -p "${PROJECT_DIR}/.xcode-build"

    set +e
    xcodebuild test -project "${XCODEPROJ}" \
        -scheme "${APP_NAME}" \
        -destination 'platform=macOS' \
        CODE_SIGN_IDENTITY="-" \
        2>&1 | tee "${TEST_LOG}" | grep -E "(Test Suite|Test Case|error:|warning:|failed|passed)" | head -30
    XCODE_TEST_EXIT=${PIPESTATUS[0]}
    set -e

    if [[ ${XCODE_TEST_EXIT} -ne 0 ]] || grep -q "There are no test bundles available to test" "${TEST_LOG}"; then
        echo -e "${YELLOW}No test bundle configured in app scheme. Falling back to Swift Package tests...${NC}"
        echo ""
        SWIFT_TEST_LOG="${PROJECT_DIR}/.xcode-build/test-output-swift.log"

        set +e
        swift test --package-path "${PROJECT_DIR}/Packages/MeetingAssistantCore" \
            2>&1 | tee "${SWIFT_TEST_LOG}" | grep -E "(Test Suite|Test Case|error:|warning:|failed|passed)" | head -40
        SWIFT_TEST_EXIT=${PIPESTATUS[0]}
        set -e

        if [[ ${SWIFT_TEST_EXIT} -ne 0 ]]; then
            echo -e "${RED}Error: Swift Package fallback tests failed. See ${SWIFT_TEST_LOG}${NC}"
            exit ${SWIFT_TEST_EXIT}
        fi
    fi
    echo -e "${GREEN}✓ Tests completed${NC}"
elif [[ "$1" == "--run" || "$1" == "-r" ]]; then
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
    echo -e "To run tests:"
    echo -e "  ${YELLOW}$0 --test${NC}"
    echo ""
fi
