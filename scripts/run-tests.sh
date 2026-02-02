#!/bin/bash
# =============================================================================
# run-tests.sh - Runs tests for MeetingAssistant with formatted output
# =============================================================================
# CLI-first test runner with support for different test configurations
# =============================================================================

# Don't exit on error - we handle exit codes manually

# Configuration
APP_NAME="MeetingAssistant"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
XCODEPROJ="${PROJECT_DIR}/MeetingAssistant.xcodeproj"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default values
VERBOSE=0
QUIET=0
SPECIFIC_TEST=""
TEST_FILE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose|-v)
            VERBOSE=1
            shift
            ;;
        --quiet|-q)
            QUIET=1
            shift
            ;;
        --test|-t)
            SPECIFIC_TEST="$2"
            shift 2
            ;;
        --file|-f)
            TEST_FILE="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --verbose, -v    Run tests with verbose output"
            echo "  --quiet, -q      Run tests quietly (no output except final result)"
            echo "  --test, -t TEST  Run specific test (e.g., testInitialState)"
            echo "  --file, -f FILE  Run tests from specific file (e.g., RecordingViewModelTests)"
            echo "  --help, -h       Show this help"
            echo ""
            echo "Examples:"
            echo "  $0                          # Run all tests"
            echo "  $0 --verbose                # Run all tests with verbose output"
            echo "  $0 --quiet                  # Run all tests quietly"
            echo "  $0 --file RecordingViewModelTests  # Run tests from specific file"
            echo "  $0 --test testInitialState  # Run specific test"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Running Tests for ${APP_NAME}${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check if xcodeproj exists
if [ ! -d "${XCODEPROJ}" ]; then
    echo -e "${RED}Error: Xcode project not found at ${XCODEPROJ}${NC}"
    echo -e "${YELLOW}Run 'make xcodegen' first to create the project.${NC}"
    exit 1
fi

# Build test command - use swift test for package tests
if [ -n "$TEST_FILE" ]; then
    TEST_CMD="cd \"${PROJECT_DIR}/Packages/MeetingAssistantCore\" && swift test --filter ${TEST_FILE}"
    echo -e "${YELLOW}Running tests from file: ${TEST_FILE}${NC}"
elif [ -n "$SPECIFIC_TEST" ]; then
    TEST_CMD="cd \"${PROJECT_DIR}/Packages/MeetingAssistantCore\" && swift test --filter ${SPECIFIC_TEST}"
    echo -e "${YELLOW}Running specific test: ${SPECIFIC_TEST}${NC}"
else
    TEST_CMD="cd \"${PROJECT_DIR}/Packages/MeetingAssistantCore\" && swift test"
    echo -e "${YELLOW}Running all tests...${NC}"
fi

if [ $VERBOSE -eq 1 ]; then
    TEST_CMD="$TEST_CMD --verbose"
fi

echo ""

# Run tests
START_TIME=$(date +%s)
TEST_OUTPUT=$(eval "$TEST_CMD" 2>&1)
EXIT_CODE=$?

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Print output in verbose mode or on failure for CI visibility
if [ $VERBOSE -eq 1 ] || [ $EXIT_CODE -ne 0 ]; then
    echo ""
    echo "$TEST_OUTPUT"
fi

# Rely on exit code for pass/fail
if [ $EXIT_CODE -ne 0 ]; then
    echo -e "${RED}✗ Tests failed!${NC} (${DURATION}s)"
    exit $EXIT_CODE
else
    echo -e "${GREEN}✓ All tests passed!${NC} (${DURATION}s)"
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
