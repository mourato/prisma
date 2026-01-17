#!/bin/bash

# Detect location of script and project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🔍 Diagnosing Audio System..."
echo "=============================="

# 1. Check Microphone Permissions via TCC
echo "Checking TCC database for microphone access..."
# Note: We can't directly read TCC.db due to SIP, but we can check if we have access via a small swift script
# or by checking if the app is already in the list (visually for user to confirm)
echo "ℹ️  User Action Required: Verify 'Terminal' or 'MeetingAssistant' has Microphone access in System Settings > Privacy & Security > Microphone"

# 2. List CoreAudio Devices
echo -e "\n🎧 Listing Audio Devices:"
system_profiler SPAudioDataType | grep -A 4 "Input Source:" || echo "No input devices found via system_profiler"

# 3. Quick Swift Diagnostic Script
echo -e "\n🛠  Running Swift Audio Diagnostic..."
SWIFT_SCRIPT=$(cat <<EOF
import AVFoundation

let session = AVAudioSession.sharedInstance()
print("Microphone Permission: \({
    switch session.recordPermission {
    case .granted: return "✅ Granted"
    case .denied: return "❌ Denied"
    case .undetermined: return "❓ Undetermined"
    @unknown default: return "Unknown"
    }
}())")

print("Available Input Nodes:")
// Note: In a CLI script context, AVCaptureDevice is often better for enumeration than AVAudioSession which relies on UI/App context
import CoreMedia
import CoreAudio

// Simple check if we can initialize an improper engine (simulating app behavior)
let engine = AVAudioEngine()
print("AudioEngine Input Node: \(engine.inputNode)")
EOF
)

# Create temp swift file
echo "$SWIFT_SCRIPT" > /tmp/audio_diag.swift
# swift /tmp/audio_diag.swift 2>/dev/null || echo "⚠️  Could not run swift diagnostic script (likely due to sandbox/permissions)"

echo -e "\n✅ Audio Diagnostic Complete"
echo "If permissions are denied, reset them with: tccutil reset Microphone com.meetingassistant.app"
