#!/bin/bash
# =============================================================================
# profile-performance.sh - Performance profiling workflow for MeetingAssistant
# =============================================================================
# Uses xctrace to profile CPU, Memory, and Animation performance
# CLI-first approach for CI/CD integration
# =============================================================================

set -e

# Configuration
APP_NAME="MeetingAssistant"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
XCODEPROJ="${PROJECT_DIR}/MeetingAssistant.xcodeproj"
DERIVED_DATA="${PROJECT_DIR}/.xcode-build"
APP_PATH="${DERIVED_DATA}/Build/Products/Debug/${APP_NAME}.app"
OUTPUT_DIR="${PROJECT_DIR}/performance-reports"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default values
PROFILE_TYPE="cpu"
DURATION=30
VERBOSE=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --cpu)
            PROFILE_TYPE="cpu"
            shift
            ;;
        --memory)
            PROFILE_TYPE="memory"
            shift
            ;;
        --animation)
            PROFILE_TYPE="animation"
            shift
            ;;
        --all)
            PROFILE_TYPE="all"
            shift
            ;;
        --duration|-d)
            DURATION="$2"
            shift 2
            ;;
        --verbose|-v)
            VERBOSE=1
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo ""
            echo "Performance profiling for ${APP_NAME}"
            echo ""
            echo "Profile Types:"
            echo "  --cpu       Profile CPU usage (default)"
            echo "  --memory    Profile memory usage"
            echo "  --animation Profile Core Animation"
            echo "  --all       Run all profile types sequentially"
            echo ""
            echo "Options:"
            echo "  --duration, -d SECS  Profile duration in seconds (default: 30)"
            echo "  --verbose, -v        Verbose output"
            echo "  --help, -h           Show this help"
            echo ""
            echo "Examples:"
            echo "  $0 --cpu --duration 60    # Profile CPU for 60 seconds"
            echo "  $0 --all                  # Run all profile types"
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
echo -e "${BLUE}  Performance Profiling - ${APP_NAME}${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check if app exists
if [ ! -d "${APP_PATH}" ]; then
    echo -e "${RED}Error: App not found at ${APP_PATH}${NC}"
    echo -e "${YELLOW}Run 'make build-debug' first to build the app.${NC}"
    exit 1
fi

# Create output directory
mkdir -p "${OUTPUT_DIR}"
REPORT_PREFIX="${OUTPUT_DIR}/profile_${TIMESTAMP}"

echo -e "${YELLOW}App: ${APP_PATH}${NC}"
echo -e "${YELLOW}Output: ${OUTPUT_DIR}${NC}"
echo -e "${YELLOW}Duration: ${DURATION}s${NC}"
echo ""

# Function to run single profile
run_profile() {
    local profile_type=$1
    local template_name=$2
    local output_file="${REPORT_PREFIX}_${profile_type}.trace"

    echo -e "${BLUE}Starting ${profile_type} profiling...${NC}"

    # Launch app and start profiling
    local xctrace_cmd=(
        xcrun xctrace record
        --template "${template_name}"
        --time-limit "${DURATION}s"
        --output "${output_file}"
        --launch -- "${APP_PATH}"
    )

    if [ $VERBOSE -eq 1 ]; then
        echo -e "${YELLOW}Command: ${xctrace_cmd[*]}${NC}"
    fi

    # xctrace may return non-zero after timed recording even when trace is saved.
    set +e
    "${xctrace_cmd[@]}" >/dev/null 2>&1
    local exit_code=$?
    set -e

    if [ -e "${output_file}" ]; then
        echo -e "${GREEN}✓ ${profile_type} profile saved: ${output_file}${NC}"
        if [ $VERBOSE -eq 1 ] && [ $exit_code -ne 0 ]; then
            echo -e "${YELLOW}xctrace exited with code ${exit_code}, but trace output exists.${NC}"
        fi
    else
        echo -e "${RED}✗ Failed to create ${profile_type} profile${NC}"
    fi
    echo ""
}

# Run profiles based on type
case $PROFILE_TYPE in
    "cpu")
        run_profile "cpu" "Time Profiler"
        ;;
    "memory")
        run_profile "memory" "Allocations"
        ;;
    "animation")
        run_profile "animation" "Animation Hitches"
        ;;
    "all")
        run_profile "cpu" "Time Profiler"
        run_profile "memory" "Allocations"
        run_profile "animation" "Animation Hitches"
        ;;
    *)
        echo -e "${RED}Invalid profile type: ${PROFILE_TYPE}${NC}"
        exit 1
        ;;
esac

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ Profiling completed${NC}"
echo ""
echo -e "${YELLOW}Reports saved in: ${OUTPUT_DIR}${NC}"
echo -e "${YELLOW}Open with: open ${REPORT_PREFIX}_*.trace${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"