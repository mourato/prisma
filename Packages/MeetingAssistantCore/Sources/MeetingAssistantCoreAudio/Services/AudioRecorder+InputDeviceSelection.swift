import AppKit
import Atomics
@preconcurrency import AVFoundation
import Combine
import CoreAudio
import Foundation
import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import os.log

extension AudioRecorder {
    func selectPreferredInputDevice(engine: AVAudioEngine) async {
        guard let inputUnit = engine.inputNode.audioUnit else {
            AppLogger.warning("Failed to resolve input audio unit for device selection", category: .recordingManager)
            return
        }

        if AppSettingsStore.shared.useSystemDefaultInput {
            applyPreferredSystemDefaultInputDevice(to: inputUnit)
            return
        }

        applyPreferredCustomInputDevice(to: inputUnit)
    }

    private func applyPreferredSystemDefaultInputDevice(to inputUnit: AudioUnit) {
        let resolvedDeviceID: AudioObjectID
        if let defaultDeviceID = deviceManager.getDefaultInputDeviceID() {
            resolvedDeviceID = defaultDeviceID
        } else if let rawDeviceID = deviceManager.getDefaultInputDeviceIDRaw() {
            // Fallback: use raw device ID without usability validation.
            // This prevents silent failures when isUsableInputDeviceID is too strict.
            AppLogger.warning(
                "Validated default input device unavailable; falling back to raw system default",
                category: .recordingManager,
                extra: ["rawDeviceID": rawDeviceID]
            )
            resolvedDeviceID = rawDeviceID
        } else {
            AppLogger.fault(
                "No system default input device found at all — microphone capture will produce silence",
                category: .recordingManager
            )
            return
        }

        var deviceIDToSet = resolvedDeviceID
        let size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioUnitSetProperty(
            inputUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceIDToSet,
            size
        )

        if status != noErr {
            AppLogger.warning(
                "Failed to set system default input device",
                category: .recordingManager,
                extra: ["status": status, "deviceID": resolvedDeviceID]
            )
        } else {
            AppLogger.info(
                "Using system default input device",
                category: .recordingManager,
                extra: ["deviceID": resolvedDeviceID]
            )
        }
        logDeviceDiagnostics(for: resolvedDeviceID, label: "systemDefault")
    }

    private func applyPreferredCustomInputDevice(to inputUnit: AudioUnit) {
        let preferredUID = microphoneInputSelectionResolver.preferredCustomMicrophoneUID()
        guard let id = microphoneInputSelectionResolver.resolveCustomMicrophoneDeviceID() else {
            AppLogger.debug(
                "No usable custom input device for current power state. Using system default.",
                category: .recordingManager,
                extra: [
                    "powerSource": microphoneInputSelectionResolver.currentPowerSourceState().rawValue,
                    "preferredUID": preferredUID ?? "nil",
                ]
            )
            return
        }

        if let systemDefaultInputID = deviceManager.getDefaultInputDeviceIDRaw(),
           id == systemDefaultInputID
        {
            AppLogger.info(
                "Custom input selection matches system default. Skipping explicit device assignment.",
                category: .recordingManager,
                extra: [
                    "deviceID": id,
                    "preferredUID": preferredUID ?? "nil",
                    "powerSource": microphoneInputSelectionResolver.currentPowerSourceState().rawValue,
                ]
            )
            return
        }

        var deviceIDToSet = id
        let size = UInt32(MemoryLayout<AudioObjectID>.size)

        let status = AudioUnitSetProperty(
            inputUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceIDToSet,
            size
        )

        if status != noErr {
            AppLogger.warning(
                "Failed to set preferred input device",
                category: .recordingManager,
                extra: ["status": status, "deviceID": id, "preferredUID": preferredUID ?? "nil"]
            )
            applySystemDefaultInputDevice(to: inputUnit, reason: "priority_device_set_failed")
        } else {
            AppLogger.info(
                "Set preferred input device",
                category: .recordingManager,
                extra: [
                    "deviceID": id,
                    "preferredUID": preferredUID ?? "nil",
                    "powerSource": microphoneInputSelectionResolver.currentPowerSourceState().rawValue,
                ]
            )
        }
        logDeviceDiagnostics(for: id, label: "priority")
    }

    private func applySystemDefaultInputDevice(to inputUnit: AudioUnit, reason: String) {
        guard let defaultDeviceID = deviceManager.getDefaultInputDeviceID() else {
            AppLogger.warning(
                "Fallback to system default input device failed: no valid default device",
                category: .recordingManager,
                extra: ["reason": reason]
            )
            return
        }

        var deviceIDToSet = defaultDeviceID
        let size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioUnitSetProperty(
            inputUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceIDToSet,
            size
        )

        if status == noErr {
            AppLogger.info(
                "Applied fallback to system default input device",
                category: .recordingManager,
                extra: ["reason": reason, "deviceID": defaultDeviceID]
            )
            logDeviceDiagnostics(for: defaultDeviceID, label: "fallbackSystemDefault")
        } else {
            AppLogger.warning(
                "Failed to apply fallback system default input device",
                category: .recordingManager,
                extra: ["reason": reason, "status": status, "deviceID": defaultDeviceID]
            )
        }
    }

    /// Restore the output device to the system default output after input device selection.
    ///
    /// `selectPreferredInputDevice` uses `kAudioOutputUnitProperty_CurrentDevice` which
    /// changes the device for the entire I/O unit (including output). This can redirect
    /// audio output to a USB microphone that has no speakers, breaking the engine's
    /// render cycle and producing zero-filled input buffers.
    func restoreOutputDevice(engine: AVAudioEngine) {
        guard let outputUnit = engine.outputNode.audioUnit else { return }

        guard let defaultOutputID = deviceManager.getDefaultOutputDeviceID() else {
            AppLogger.warning(
                "No system default output device found; cannot restore output device",
                category: .recordingManager
            )
            return
        }

        // Check if output is already correct
        var currentOutputID: AudioObjectID = 0
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let getStatus = AudioUnitGetProperty(
            outputUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &currentOutputID,
            &size
        )

        if getStatus == noErr, currentOutputID == defaultOutputID {
            return // Output device is already the system default
        }

        // Restore to system default output
        var deviceIDToSet = defaultOutputID
        let setStatus = AudioUnitSetProperty(
            outputUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceIDToSet,
            size
        )

        let deviceName = deviceManager.getDeviceName(for: defaultOutputID) ?? "Unknown"
        if setStatus == noErr {
            AppLogger.info(
                "Restored output device to system default",
                category: .recordingManager,
                extra: [
                    "outputDeviceID": defaultOutputID,
                    "outputDeviceName": deviceName,
                    "previousOutputDeviceID": currentOutputID,
                ]
            )
        } else {
            AppLogger.warning(
                "Failed to restore output device to system default",
                category: .recordingManager,
                extra: ["status": setStatus, "targetDeviceID": defaultOutputID]
            )
        }
    }
}
