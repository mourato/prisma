import AudioToolbox
import Foundation
import MeetingAssistantCoreCommon

/// Controller for muting/unmuting system audio output using Core Audio.
public final class SystemAudioMuteController: Sendable {
    public static let shared = SystemAudioMuteController()

    private init() {}

    /// Set the mute status of the default system audio output device.
    /// - Parameter muted: True to mute, false to unmute.
    public func setMuted(_ muted: Bool) throws {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceID: AudioObjectID = kAudioObjectUnknown
        var size = UInt32(MemoryLayout<AudioObjectID>.size)

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )

        guard status == noErr else {
            throw AudioError.coreAudioError(status)
        }

        address.mSelector = kAudioDevicePropertyMute
        address.mScope = kAudioDevicePropertyScopeOutput
        address.mElement = kAudioObjectPropertyElementMain

        var muteValue: UInt32 = muted ? 1 : 0
        let muteSize = UInt32(MemoryLayout<UInt32>.size)

        let muteStatus = AudioObjectSetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            muteSize,
            &muteValue
        )

        if muteStatus != noErr {
            AppLogger.warning(
                "Failed to set system mute status",
                category: .recordingManager,
                extra: ["status": muteStatus, "muted": muted]
            )
            throw AudioError.coreAudioError(muteStatus)
        }

        AppLogger.debug(
            "System mute status changed",
            category: .recordingManager,
            extra: ["muted": muted]
        )
    }

    /// Get the current mute status of the default system audio output device.
    public func isMuted() -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceID: AudioObjectID = kAudioObjectUnknown
        var size = UInt32(MemoryLayout<AudioObjectID>.size)

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )

        guard status == noErr else { return false }

        address.mSelector = kAudioDevicePropertyMute
        address.mScope = kAudioDevicePropertyScopeOutput
        address.mElement = kAudioObjectPropertyElementMain

        var muteValue: UInt32 = 0
        var muteSize = UInt32(MemoryLayout<UInt32>.size)

        let muteStatus = AudioObjectGetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            &muteSize,
            &muteValue
        )

        return muteStatus == noErr && muteValue != 0
    }
}

/// Custom audio errors
public enum AudioError: Error {
    case coreAudioError(OSStatus)
}
