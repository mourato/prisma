import AVFoundation
import Combine
import CoreAudio
import Foundation
import MeetingAssistantCoreCommon

/// Model representing an audio input device.
public struct AudioInputDevice: Identifiable, Codable, Equatable, Sendable {
    public let id: String // Unique device UID
    public let name: String // User-friendly name
    public let isDefault: Bool // Whether it's the system default input
    public var isAvailable: Bool // Whether it's currently connected

    public init(id: String, name: String, isDefault: Bool = false, isAvailable: Bool = true) {
        self.id = id
        self.name = name
        self.isDefault = isDefault
        self.isAvailable = isAvailable
    }
}

/// Service responsible for enumerating and observing audio input devices.
@MainActor
public final class AudioDeviceManager: ObservableObject {
    @Published public private(set) var availableInputDevices: [AudioInputDevice] = []

    public init() {
        refreshDevices()

        // Setup observers for device changes
        NotificationCenter.default.addObserver(
            forName: .AVCaptureDeviceWasConnected,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshDevices()
            }
        }

        NotificationCenter.default.addObserver(
            forName: .AVCaptureDeviceWasDisconnected,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshDevices()
            }
        }
    }

    /// Explicitly refresh the list of available devices.
    /// Performs discovery on a background thread to avoid blocking the UI.
    public func refreshDevices() {
        let task = Task.detached(priority: .userInitiated) {
            let discoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.microphone, .external],
                mediaType: .audio,
                position: .unspecified
            )

            let defaultInput = AVCaptureDevice.default(for: .audio)

            return discoverySession.devices.map { device in
                AudioInputDevice(
                    id: device.uniqueID,
                    name: device.localizedName,
                    isDefault: device.uniqueID == defaultInput?.uniqueID,
                    isAvailable: true
                )
            }
        }

        Task { @MainActor [weak self] in
            let devices = await task.value
            self?.updateDevices(devices)
        }
    }

    @MainActor
    private func updateDevices(_ devices: [AudioInputDevice]) {
        guard availableInputDevices != devices else { return }

        availableInputDevices = devices

        AppLogger.debug(
            "Refreshed audio input devices",
            category: .health,
            extra: ["count": availableInputDevices.count]
        )
    }

    /// Check if a specific device (by UID) is currently available.
    public func isDeviceAvailable(_ uid: String) -> Bool {
        availableInputDevices.contains { $0.id == uid }
    }

    /// Retrieve the Core Audio device ID for a given unique UID.
    public nonisolated func getAudioDeviceID(for uid: String) -> AudioObjectID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var propsize: UInt32 = 0
        AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propsize)

        let nDevices = Int(propsize) / MemoryLayout<AudioObjectID>.size
        var deviceIDs = [AudioObjectID](repeating: 0, count: nDevices)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propsize, &deviceIDs)

        for deviceID in deviceIDs {
            var nameAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )

            var uidString: Unmanaged<CFString>?
            var uidSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            let status = AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &uidSize, &uidString)

            if status == noErr, let deviceUID = uidString?.takeRetainedValue(), (deviceUID as String) == uid {
                return deviceID
            }
        }

        return nil
    }

    /// Retrieve the Core Audio device ID for the system default input device.
    public nonisolated func getDefaultInputDeviceID() -> AudioObjectID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceID: AudioObjectID = 0
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID)

        guard status == noErr else { return nil }
        return deviceID
    }

    public nonisolated func getDeviceName(for id: AudioObjectID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(id, &address, 0, nil, &size, &name)
        guard status == noErr, let name else { return nil }
        return name.takeRetainedValue() as String
    }

    public nonisolated func getDeviceUID(for id: AudioObjectID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var uid: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(id, &address, 0, nil, &size, &uid)
        guard status == noErr, let uid else { return nil }
        return uid.takeRetainedValue() as String
    }

    public nonisolated func getInputChannelCount(for id: AudioObjectID) -> Int? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        let sizeStatus = AudioObjectGetPropertyDataSize(id, &address, 0, nil, &dataSize)
        guard sizeStatus == noErr, dataSize > 0 else { return nil }

        let bufferListPointer = UnsafeMutablePointer<AudioBufferList>.allocate(
            capacity: Int(dataSize) / MemoryLayout<AudioBufferList>.size
        )
        defer { bufferListPointer.deallocate() }

        let dataStatus = AudioObjectGetPropertyData(id, &address, 0, nil, &dataSize, bufferListPointer)
        guard dataStatus == noErr else { return nil }

        let audioBufferList = UnsafeMutableAudioBufferListPointer(bufferListPointer)
        return audioBufferList.reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    public nonisolated func getInputVolume(for id: AudioObjectID) -> Float? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        var volume: Float = 0
        var size = UInt32(MemoryLayout<Float>.size)
        let status = AudioObjectGetPropertyData(id, &address, 0, nil, &size, &volume)
        guard status == noErr else { return nil }
        return volume
    }

    public nonisolated func getInputMute(for id: AudioObjectID) -> Bool? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        var mute: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(id, &address, 0, nil, &size, &mute)
        guard status == noErr else { return nil }
        return mute != 0
    }

    /// Attempts to set the system default input device volume to maximum (1.0).
    /// Returns true when at least one input volume property is successfully updated.
    public nonisolated func setDefaultInputVolumeToMaximum() -> Bool {
        guard let deviceID = getDefaultInputDeviceID() else { return false }
        return setInputVolume(for: deviceID, to: 1.0)
    }

    /// Attempts to set input volume for the provided device.
    /// Returns true when at least one volume property is successfully updated.
    public nonisolated func setInputVolume(for id: AudioObjectID, to scalar: Float) -> Bool {
        let volume = max(0.0, min(1.0, scalar))
        var didSetAny = false

        // Try "master" element first.
        if setInputVolumeScalar(for: id, element: kAudioObjectPropertyElementMain, volume: volume) {
            didSetAny = true
        }

        // If the device exposes per-channel controls, set each channel too.
        if let channelCount = getInputChannelCount(for: id), channelCount > 0 {
            for channel in 1...channelCount {
                if setInputVolumeScalar(for: id, element: UInt32(channel), volume: volume) {
                    didSetAny = true
                }
            }
        }

        return didSetAny
    }

    private nonisolated func setInputVolumeScalar(
        for id: AudioObjectID,
        element: UInt32,
        volume: Float
    ) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: element
        )

        guard AudioObjectHasProperty(id, &address) else { return false }

        var settable = DarwinBoolean(false)
        let settableStatus = AudioObjectIsPropertySettable(id, &address, &settable)
        guard settableStatus == noErr, settable.boolValue else { return false }

        var mutableVolume = volume
        let size = UInt32(MemoryLayout<Float>.size)
        let status = AudioObjectSetPropertyData(id, &address, 0, nil, size, &mutableVolume)
        return status == noErr
    }
}
