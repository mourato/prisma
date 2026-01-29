import AVFoundation
import Combine
import CoreAudio
import Foundation

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
        Task { @MainActor in
            refreshDevices()
        }

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
    @MainActor
    public func refreshDevices() {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        )

        let defaultInput = AVCaptureDevice.default(for: .audio)

        availableInputDevices = discoverySession.devices.map { device in
            AudioInputDevice(
                id: device.uniqueID,
                name: device.localizedName,
                isDefault: device.uniqueID == defaultInput?.uniqueID,
                isAvailable: true
            )
        }

        AppLogger.debug(
            "Refreshed audio input devices",
            category: .health,
            extra: ["count": availableInputDevices.count]
        )
    }

    /// Check if a specific device (by UID) is currently available.
    public func isDeviceAvailable(_ uid: String) -> Bool {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        )
        return discoverySession.devices.contains { $0.uniqueID == uid }
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

            var uidString: CFString = "" as CFString
            var uidSize = UInt32(MemoryLayout<CFString>.size)
            let status = AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &uidSize, &uidString)

            if status == noErr, (uidString as String) == uid {
                return deviceID
            }
        }

        return nil
    }
}
