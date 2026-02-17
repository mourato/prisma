# Makefile for MeetingAssistant - CLI-first development workflow
# =============================================================================
# This Makefile provides common development commands for the MeetingAssistant
# project. All commands use xcodebuild CLI tools for maximum compatibility
# with CI/CD pipelines and headless environments.
# =============================================================================

.PHONY: help build build-debug build-release build-agent test test-agent test-swift test-verbose test-strict lint lint-agent lint-fix arch-check preview-check preflight preflight-agent clean run run-release dmg setup docs docs-preview docs-clean

# Default target
help:
	@echo "MeetingAssistant Development Commands"
	@echo "===================================="
	@echo ""
	@echo "Build Commands:"
	@echo "  make build          - Build debug version (default)"
	@echo "  make build-debug    - Build debug version explicitly"
	@echo "  make build-release  - Build release version"
	@echo "  make build-agent    - Build debug with compact machine-readable output"
	@echo ""
	@echo "Test Commands:"
	@echo "  make test           - Run all tests (xcodebuild - IDE compatible)"
	@echo "  make test-agent     - Run compact swift test output for AI agents"
	@echo "  make test-swift     - Run tests with swift test (faster, no IDE parity)"
	@echo "  make test-verbose   - Run tests with verbose output"
	@echo "  make test-strict    - Run tests with strict concurrency checking"
	@echo ""
	@echo "Code Quality:"
	@echo "  make lint           - Run linting checks"
	@echo "  make lint-agent     - Run lint with compact machine-readable output"
	@echo "  make lint-fix       - Auto-fix linting issues"
	@echo "  make arch-check     - Run architecture boundary checks"
	@echo "  make preview-check  - Verify all SwiftUI views have previews"
	@echo "  make preflight      - Run preflight script (build + test + lint)"
	@echo "  make preflight-agent - Run preflight in compact machine-readable mode"
	@echo "  make health         - Run comprehensive code health check"
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
	@echo ""
	@echo "CI/CD Commands:"
	@echo "  make ci-build       - Full CI build (lint + test + build-release)"
	@echo "  make ci-test        - CI test run (no user interaction)"
	@echo ""
	@echo "Documentation:"
	@echo "  make docs           - Build DocC documentation"
	@echo "  make docs-preview   - Preview documentation locally"
	@echo "  make docs-clean     - Clean documentation artifacts"

# Configuration
APP_NAME = MeetingAssistant
PROJECT_DIR = $(shell pwd)
XCODEPROJ = $(PROJECT_DIR)/MeetingAssistant.xcodeproj
DERIVED_DATA = $(PROJECT_DIR)/.xcode-build
DIST_DIR = $(PROJECT_DIR)/dist
AGENT_LOG_DIR ?= /tmp/ma-agent

# Colors for output
RED = \033[0;31m
GREEN = \033[0;32m
YELLOW = \033[1;33m
BLUE = \033[0;34m
NC = \033[0m

# Build Commands
build: build-debug

build-debug:
	@./scripts/run-build.sh --configuration Debug

build-release:
	@./scripts/run-build.sh --configuration Release

build-agent:
	@MA_AGENT_MODE=1 MA_AGENT_LOG_DIR="$(AGENT_LOG_DIR)" ./scripts/run-build.sh --configuration Debug --agent

# Test Commands
test:
	@echo -e "$(BLUE)Running tests (xcodebuild)...$(NC)"
	@echo -e "$(YELLOW)Uses same build system as Xcode IDE for guaranteed parity$(NC)"
	@cd "$(PROJECT_DIR)/Packages/MeetingAssistantCore" && \
	xcodebuild -scheme MeetingAssistantCore \
		-derivedDataPath "$(DERIVED_DATA)" \
		-destination 'platform=macOS' \
		test \
		2>&1 | tee /tmp/test-output.log; \
	EXIT_CODE=$${PIPESTATUS[0]}; \
	if [ $$EXIT_CODE -eq 0 ]; then \
		echo -e "$(GREEN)✓ All tests passed!$(NC)"; \
	else \
		echo -e "$(RED)✗ Tests failed!$(NC)"; \
		echo -e "$(YELLOW)Full output: /tmp/test-output.log$(NC)"; \
	fi; \
	exit $$EXIT_CODE

test-agent:
	@MA_AGENT_MODE=1 MA_AGENT_LOG_DIR="$(AGENT_LOG_DIR)" ./scripts/run-tests.sh --agent

test-swift:
	@echo -e "$(BLUE)Running tests (swift test)...$(NC)"
	@echo -e "$(YELLOW)Warning: Faster but may differ from Xcode IDE results$(NC)"
	@./scripts/run-tests.sh

test-verbose:
	@echo -e "$(BLUE)Running tests (verbose)...$(NC)"
	@./scripts/run-tests.sh --verbose

test-strict:
	@echo -e "$(BLUE)Running tests (Strict Concurrency)...$(NC)"
	@./scripts/run-tests.sh --strict

# Code Quality
lint:
	@echo -e "$(BLUE)Running SwiftLint...$(NC)"
	@./scripts/lint.sh

lint-agent:
	@MA_AGENT_MODE=1 MA_AGENT_LOG_DIR="$(AGENT_LOG_DIR)" ./scripts/lint.sh --agent

lint-fix:
	@echo -e "$(BLUE)Auto-fixing lint issues...$(NC)"
	@./scripts/lint-fix.sh

arch-check:
	@echo -e "$(BLUE)Running architecture checks...$(NC)"
	@./scripts/architecture-check.sh

preview-check:
	@echo -e "$(BLUE)Checking SwiftUI preview coverage...$(NC)"
	@./scripts/preview-check.sh

preflight:
	@echo -e "$(BLUE)Running preflight checks...$(NC)"
	@./scripts/preflight.sh

preflight-agent:
	@MA_AGENT_MODE=1 MA_AGENT_LOG_DIR="$(AGENT_LOG_DIR)" ./scripts/preflight.sh --agent

format:
	@echo -e "$(BLUE)Running SwiftFormat...$(NC)"
	@if ! command -v swiftformat &> /dev/null; then \
		echo "❌ SwiftFormat not installed. Install with: brew install swiftformat"; \
		exit 1; \
	fi
	@swiftformat --config .swiftformat App Packages/MeetingAssistantCore/Sources
	@echo -e "$(GREEN)✓ Code formatted$(NC)"

health:
	@echo -e "$(BLUE)Running code health check...$(NC)"
	@./scripts/code-health-check.sh

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


# CI/CD Commands
ci-build: arch-check lint test build-release
	@echo -e "$(GREEN)✓ CI build completed successfully$(NC)"

ci-test: test
	@echo -e "$(GREEN)✓ CI tests completed$(NC)"
# Documentation
docs:
	@echo -e "$(BLUE)Building DocC documentation...$(NC)"
	@cd Packages/MeetingAssistantCore && \
		swift package --allow-writing-to-directory "$(PROJECT_DIR)/docs/api" \
		generate-documentation \
		--target MeetingAssistantCore \
		--transform-for-static-hosting \
		--output-path "$(PROJECT_DIR)/docs/api"
	@echo -e "$(GREEN)✓ Documentation built at docs/api$(NC)"

docs-preview:
	@echo -e "$(BLUE)Previewing documentation...$(NC)"
	@cd Packages/MeetingAssistantCore && swift package --disable-sandbox preview-documentation --target MeetingAssistantCore

docs-clean:
	@echo -e "$(YELLOW)Cleaning documentation...$(NC)"
	@rm -rf "$(PROJECT_DIR)/docs/api"
	@echo -e "$(GREEN)✓ Documentation cleaned$(NC)"
