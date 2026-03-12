import AudioToolbox
import Foundation
import MeetingAssistantCoreCommon

/// Controller for muting/unmuting system audio output using Core Audio.
public final class SystemAudioMuteController: Sendable {
    public static let shared = SystemAudioMuteController()

    private init() {}

    struct OutputMuteSession {
        let deviceID: AudioObjectID
        let wasMuted: Bool?
        let previousVolume: Float?
        let canMute: Bool
        let canSetVolume: Bool
        var appliedStrategy: OutputMuteStrategy?
    }

    enum OutputMuteStrategy: String {
        case muteProperty
        case volumeProperty
    }

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

    func prepareOutputMuteSession() -> OutputMuteSession? {
        guard let deviceID = getDefaultOutputDeviceID() else { return nil }

        let muteState = getOutputMuteState(for: deviceID)
        let volumeState = getOutputVolume(for: deviceID)
        let canMute = isMuteSettable(for: deviceID) && muteState != nil
        let canSetVolume = isVolumeSettable(for: deviceID) && volumeState != nil

        guard canMute || canSetVolume else {
            AppLogger.warning(
                "System output mute skipped due to missing restore state",
                category: .recordingManager,
                extra: ["canMute": canMute, "canSetVolume": canSetVolume]
            )
            return nil
        }

        return OutputMuteSession(
            deviceID: deviceID,
            wasMuted: muteState,
            previousVolume: volumeState,
            canMute: canMute,
            canSetVolume: canSetVolume,
            appliedStrategy: nil
        )
    }

    func applyMute(to session: inout OutputMuteSession) throws {
        var lastError: Error?

        if session.canMute {
            do {
                try setOutputMuted(true, for: session.deviceID)
                session.appliedStrategy = .muteProperty
                return
            } catch {
                lastError = error
            }
        }

        if session.canSetVolume {
            do {
                try setOutputVolume(0.0, for: session.deviceID)
                session.appliedStrategy = .volumeProperty
                return
            } catch {
                lastError = error
            }
        }

        if let lastError {
            throw lastError
        }

        throw AudioError.coreAudioError(OSStatus(paramErr))
    }

    func restoreOutputState(from session: OutputMuteSession) {
        guard let strategy = session.appliedStrategy else { return }

        switch strategy {
        case .muteProperty:
            guard let wasMuted = session.wasMuted else { return }
            try? setOutputMuted(wasMuted, for: session.deviceID)
        case .volumeProperty:
            guard let previousVolume = session.previousVolume else { return }
            try? setOutputVolume(previousVolume, for: session.deviceID)
        }
    }

    private func getDefaultOutputDeviceID() -> AudioObjectID? {
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

        guard status == noErr else { return nil }
        return deviceID
    }

    private func isMuteSettable(for deviceID: AudioObjectID) -> Bool {
        isPropertySettable(
            deviceID,
            selector: kAudioDevicePropertyMute,
            scope: kAudioDevicePropertyScopeOutput,
            element: kAudioObjectPropertyElementMain
        )
    }

    private func isVolumeSettable(for deviceID: AudioObjectID) -> Bool {
        isPropertySettable(
            deviceID,
            selector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            scope: kAudioDevicePropertyScopeOutput,
            element: kAudioObjectPropertyElementMain
        )
    }

    private func isPropertySettable(
        _ deviceID: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope,
        element: AudioObjectPropertyElement
    ) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: element
        )

        guard AudioObjectHasProperty(deviceID, &address) else { return false }

        var isSettable: DarwinBoolean = false
        let status = AudioObjectIsPropertySettable(deviceID, &address, &isSettable)
        return status == noErr && isSettable.boolValue
    }

    private func getOutputMuteState(for deviceID: AudioObjectID) -> Bool? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        guard AudioObjectHasProperty(deviceID, &address) else { return nil }

        var muteValue: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &muteValue)
        guard status == noErr else { return nil }
        return muteValue != 0
    }

    private func setOutputMuted(_ muted: Bool, for deviceID: AudioObjectID) throws {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        guard AudioObjectHasProperty(deviceID, &address) else {
            throw AudioError.coreAudioError(kAudioHardwareBadObjectError)
        }

        var muteValue: UInt32 = muted ? 1 : 0
        let size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &muteValue)
        guard status == noErr else { throw AudioError.coreAudioError(status) }
    }

    private func getOutputVolume(for deviceID: AudioObjectID) -> Float? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        guard AudioObjectHasProperty(deviceID, &address) else { return nil }

        var volume: Float = 0
        var size = UInt32(MemoryLayout<Float>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &volume)
        guard status == noErr else { return nil }
        return volume
    }

    private func setOutputVolume(_ volume: Float, for deviceID: AudioObjectID) throws {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        guard AudioObjectHasProperty(deviceID, &address) else {
            throw AudioError.coreAudioError(kAudioHardwareBadObjectError)
        }

        var scalar = max(0.0, min(1.0, volume))
        let size = UInt32(MemoryLayout<Float>.size)
        let status = AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &scalar)
        guard status == noErr else { throw AudioError.coreAudioError(status) }
    }
}

/// Custom audio errors
public enum AudioError: Error {
    case coreAudioError(OSStatus)
}
