#!/bin/bash
# Post-build script to fix XPC service embedding

set -e

APP_PATH="${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}"
XPC_NAME="MeetingAssistantAI.xpc"

if [ -d "${APP_PATH}/Contents/PlugIns/${XPC_NAME}" ]; then
    echo "Moving XPC service from PlugIns to XPCServices..."
    mkdir -p "${APP_PATH}/Contents/XPCServices"
    mv "${APP_PATH}/Contents/PlugIns/${XPC_NAME}" "${APP_PATH}/Contents/XPCServices/"
    echo "✓ XPC service moved to correct location"
fi

# Re-sign XPC and app if needed
if [ -d "${APP_PATH}/Contents/XPCServices/${XPC_NAME}" ]; then
    codesign --force --sign - "${APP_PATH}/Contents/XPCServices/${XPC_NAME}" 2>/dev/null || true
fi
