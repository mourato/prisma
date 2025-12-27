#!/bin/bash
# =============================================================================
# build-app.sh - Builds MeetingAssistant.app bundle from Swift Package Manager
# =============================================================================
# This script creates a proper macOS app bundle with Info.plist and entitlements,
# which is required for TCC permissions (Screen Recording, Microphone) to work.
# =============================================================================

set -e  # Exit on any error

# Configuration
APP_NAME="MeetingAssistant"
BUNDLE_ID="com.meetingassistant.app"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/.build/release"
DIST_DIR="${PROJECT_DIR}/dist"
APP_BUNDLE="${DIST_DIR}/${APP_NAME}.app"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Building ${APP_NAME}.app Bundle${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Step 1: Build the Swift package in release mode
echo -e "${YELLOW}[1/5]${NC} Building Swift package (release mode)..."
cd "${PROJECT_DIR}"
swift build -c release

if [ ! -f "${BUILD_DIR}/${APP_NAME}" ]; then
    echo -e "${RED}Error: Build failed. Executable not found at ${BUILD_DIR}/${APP_NAME}${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Build completed${NC}"

# Step 2: Create app bundle structure
echo -e "${YELLOW}[2/5]${NC} Creating app bundle structure..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

echo -e "${GREEN}✓ Bundle structure created${NC}"

# Step 3: Copy executable
echo -e "${YELLOW}[3/5]${NC} Copying executable..."
cp "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
echo -e "${GREEN}✓ Executable copied${NC}"

# Step 3.5: Copy resources (bundles)
# IMPORTANT: SPM's Bundle.module looks for bundles at Bundle.main.bundleURL (the .app root)
# NOT in Contents/Resources. We must copy bundles to the root of the app bundle.
echo -e "${YELLOW}[3.5/5]${NC} Copying resources..."
cp -R "${BUILD_DIR}/"*.bundle "${APP_BUNDLE}/" 2>/dev/null || true
echo -e "${GREEN}✓ Resources copied${NC}"

# Step 4: Create Info.plist with resolved variables
echo -e "${YELLOW}[4/5]${NC} Creating Info.plist..."
cat > "${APP_BUNDLE}/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>pt-BR</string>
    
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    
    <key>CFBundleDisplayName</key>
    <string>Meeting Assistant</string>
    
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    
    <key>CFBundleVersion</key>
    <string>1</string>
    
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.productivity</string>
    
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    
    <key>LSUIElement</key>
    <true/>
    
    <key>NSHighResolutionCapable</key>
    <true/>
    
    <!-- Privacy Usage Descriptions (Required for TCC) -->
    <key>NSMicrophoneUsageDescription</key>
    <string>O Meeting Assistant precisa acessar o microfone para capturar áudio quando a captura de tela não estiver disponível.</string>
    
    <key>NSScreenCaptureUsageDescription</key>
    <string>O Meeting Assistant precisa capturar áudio do sistema para gravar suas reuniões por videochamada.</string>
    
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2024. Todos os direitos reservados.</string>
    
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF
echo -e "${GREEN}✓ Info.plist created${NC}"

# Step 5: Code sign the app (ad-hoc for local development)
echo -e "${YELLOW}[5/5]${NC} Code signing app bundle..."

# Create entitlements file for signing
ENTITLEMENTS_FILE="${PROJECT_DIR}/MeetingAssistant.entitlements"
if [ -f "${ENTITLEMENTS_FILE}" ]; then
    codesign --force --deep --sign - --entitlements "${ENTITLEMENTS_FILE}" "${APP_BUNDLE}"
else
    # Create inline entitlements if file doesn't exist
    TEMP_ENTITLEMENTS=$(mktemp)
    cat > "${TEMP_ENTITLEMENTS}" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
    
    <key>com.apple.security.device.audio-input</key>
    <true/>
</dict>
</plist>
EOF
    codesign --force --deep --sign - --entitlements "${TEMP_ENTITLEMENTS}" "${APP_BUNDLE}"
    rm "${TEMP_ENTITLEMENTS}"
fi

echo -e "${GREEN}✓ Code signing completed${NC}"

# Summary
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ Build completed successfully!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "App bundle location:"
echo -e "  ${YELLOW}${APP_BUNDLE}${NC}"
echo ""
echo -e "To run the app:"
echo -e "  ${YELLOW}open \"${APP_BUNDLE}\"${NC}"
echo ""
echo -e "To view in Finder:"
echo -e "  ${YELLOW}open \"${DIST_DIR}\"${NC}"
echo ""

# Optional: Reset permissions for testing (Development only)
echo -e "${YELLOW}Resetting permissions for ${BUNDLE_ID} to ensure clean test state...${NC}"
tccutil reset All "${BUNDLE_ID}" 2>/dev/null || true
echo -e "${GREEN}✓ Permissions reset${NC}"
echo ""

# Ask if user wants to run the app
read -p "Do you want to run the app now? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Launching ${APP_NAME}...${NC}"
    open "${APP_BUNDLE}"
fi
