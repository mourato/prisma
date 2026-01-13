# Makefile for MeetingAssistant - CLI-first development workflow
# =============================================================================
# This Makefile provides common development commands for the MeetingAssistant
# project. All commands use xcodebuild CLI tools for maximum compatibility
# with CI/CD pipelines and headless environments.
# =============================================================================

.PHONY: help build build-debug build-release test test-verbose lint lint-fix clean run run-release dmg setup xcodegen

# Default target
help:
	@echo "MeetingAssistant Development Commands"
	@echo "===================================="
	@echo ""
	@echo "Build Commands:"
	@echo "  make build          - Build debug version (default)"
	@echo "  make build-debug    - Build debug version explicitly"
	@echo "  make build-release  - Build release version"
	@echo ""
	@echo "Test Commands:"
	@echo "  make test           - Run all tests"
	@echo "  make test-verbose   - Run tests with verbose output"
	@echo ""
	@echo "Code Quality:"
	@echo "  make lint           - Run linting checks"
	@echo "  make lint-fix       - Auto-fix linting issues"
	@echo ""
	@echo "Run Commands:"
	@echo "  make run            - Build and run debug version"
	@echo "  make run-release    - Build and run release version"
	@echo ""
	@echo "Distribution:"
	@echo "  make dmg            - Create DMG installer"
	@echo ""
	@echo "Performance Profiling:"
	@echo "  make profile        - Run all performance profiling (CPU, Memory, Animation)"
	@echo "  make profile-cpu    - Profile CPU usage with Time Profiler"
	@echo "  make profile-memory - Profile memory usage with Allocations"
	@echo "  make profile-animation - Profile Core Animation performance"
	@echo ""
	@echo "Maintenance:"
	@echo "  make clean          - Clean build artifacts"
	@echo "  make setup          - Install development dependencies"
	@echo "  make xcodegen       - Generate Xcode project from project.yml"
	@echo ""
	@echo "CI/CD Commands:"
	@echo "  make ci-build       - Full CI build (lint + test + build-release)"
	@echo "  make ci-test        - CI test run (no user interaction)"

# Configuration
APP_NAME = MeetingAssistant
PROJECT_DIR = $(shell pwd)
XCODEPROJ = $(PROJECT_DIR)/MeetingAssistant.xcodeproj
DERIVED_DATA = $(PROJECT_DIR)/.xcode-build
DIST_DIR = $(PROJECT_DIR)/dist

# Colors for output
RED = \033[0;31m
GREEN = \033[0;32m
YELLOW = \033[1;33m
BLUE = \033[0;34m
NC = \033[0m

# Build Commands
build: build-debug

build-debug:
	@echo -e "$(BLUE)Building $(APP_NAME) (Debug)...$(NC)"
	@xcodebuild -project "$(XCODEPROJ)" \
		-scheme "$(APP_NAME)" \
		-configuration Debug \
		-derivedDataPath "$(DERIVED_DATA)" \
		-destination 'platform=macOS' \
		build \
		2>&1 | grep -E "(Compiling|Linking|Signing|BUILD|error:|warning:)" | head -20
	@echo -e "$(GREEN)✓ Debug build completed$(NC)"

build-release:
	@echo -e "$(BLUE)Building $(APP_NAME) (Release)...$(NC)"
	@xcodebuild -project "$(XCODEPROJ)" \
		-scheme "$(APP_NAME)" \
		-configuration Release \
		-derivedDataPath "$(DERIVED_DATA)" \
		-destination 'platform=macOS' \
		-enableThreadSanitizer YES \
		build \
		2>&1 | grep -E "(Compiling|Linking|Signing|BUILD|error:|warning:)" | head -30
	@echo -e "$(GREEN)✓ Release build completed$(NC)"

# Test Commands
test:
	@echo -e "$(BLUE)Running tests...$(NC)"
	@./scripts/run-tests.sh

test-verbose:
	@echo -e "$(BLUE)Running tests (verbose)...$(NC)"
	@./scripts/run-tests.sh --verbose

# Code Quality
lint:
	@echo -e "$(BLUE)Running SwiftLint...$(NC)"
	@./scripts/lint.sh

lint-fix:
	@echo -e "$(BLUE)Auto-fixing lint issues...$(NC)"
	@./scripts/lint-fix.sh

# Run Commands
run: build-debug
	@echo -e "$(YELLOW)Launching $(APP_NAME) (Debug)...$(NC)"
	@open "$(DERIVED_DATA)/Build/Products/Debug/$(APP_NAME).app"

run-release: build-release
	@echo -e "$(YELLOW)Launching $(APP_NAME) (Release)...$(NC)"
	@open "$(DERIVED_DATA)/Build/Products/Release/$(APP_NAME).app"

# Distribution
dmg:
	@echo -e "$(BLUE)Creating DMG installer...$(NC)"
	@./scripts/create-dmg.sh --ci

# Maintenance
clean:
	@echo -e "$(YELLOW)Cleaning build artifacts...$(NC)"
	@rm -rf "$(DERIVED_DATA)"
	@rm -rf "$(DIST_DIR)"
	@echo -e "$(GREEN)✓ Clean completed$(NC)"

setup:
	@echo -e "$(BLUE)Setting up development environment...$(NC)"
	@echo "Installing SwiftLint..."
	@brew install swiftlint || echo "SwiftLint already installed"
	@echo "Installing SwiftFormat..."
	@brew install swiftformat || echo "SwiftFormat already installed"
	@echo -e "$(GREEN)✓ Setup completed$(NC)"

xcodegen:
	@echo -e "$(BLUE)Generating Xcode project...$(NC)"
	@xcodegen generate
	@echo -e "$(GREEN)✓ Xcode project generated$(NC)"

# Profiling Commands
profile: build-debug
	@echo -e "$(BLUE)Running performance profiling (all)...$(NC)"
	@./scripts/profile-performance.sh --all

profile-cpu: build-debug
	@echo -e "$(BLUE)Running CPU profiling...$(NC)"
	@./scripts/profile-performance.sh --cpu

profile-memory: build-debug
	@echo -e "$(BLUE)Running memory profiling...$(NC)"
	@./scripts/profile-performance.sh --memory

profile-animation: build-debug
	@echo -e "$(BLUE)Running animation profiling...$(NC)"
	@./scripts/profile-performance.sh --animation

# Mock Generation
mocks:
	@echo -e "$(BLUE)Generating Cuckoo mocks...$(NC)"
	@cd Packages/MeetingAssistantCore && \
	if [ -f "/tmp/Cuckoo/.build/debug/CuckooGenerator" ]; then \
		/tmp/Cuckoo/.build/debug/CuckooGenerator --configuration Cuckoofile.toml; \
		echo -e "$(GREEN)✓ Cuckoo mocks generated$(NC)"; \
	else \
		echo -e "$(YELLOW)⚠️  CuckooGenerator not found$(NC)"; \
		echo -e "$(YELLOW)   Run: mint install Brightify/Cuckoo CuckooGenerator && swift run --package-path /tmp/Cuckoo CuckooGenerator$(NC)"; \
	fi

# CI/CD Commands
ci-build: lint test build-release
	@echo -e "$(GREEN)✓ CI build completed successfully$(NC)"

ci-test: test
	@echo -e "$(GREEN)✓ CI tests completed$(NC)"