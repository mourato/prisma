import Foundation

// MARK: - Permission Status Model

/// Represents the authorization status of a specific permission.
public enum PermissionState: String, Sendable {
    case granted
    case denied
    case notDetermined
    case restricted

    /// Localized display name for the permission state.
    public var displayName: String {
        switch self {
        case .granted:
            NSLocalizedString("permission.state.granted", bundle: .safeModule, comment: "")
        case .denied:
            NSLocalizedString("permission.state.denied", bundle: .safeModule, comment: "")
        case .notDetermined:
            NSLocalizedString("permission.state.not_determined", bundle: .safeModule, comment: "")
        case .restricted:
            NSLocalizedString("permission.state.restricted", bundle: .safeModule, comment: "")
        }
    }

    /// SF Symbol icon name for the permission state.
    public var iconName: String {
        switch self {
        case .granted:
            "checkmark.circle.fill"
        case .denied:
            "xmark.circle.fill"
        case .notDetermined:
            "questionmark.circle.fill"
        case .restricted:
            "lock.circle.fill"
        }
    }

    /// Whether operations requiring this permission can proceed.
    public var isAuthorized: Bool {
        self == .granted
    }
}

/// Represents a specific permission type in the application.
public enum PermissionType: String, CaseIterable, Sendable {
    case microphone
    case screenRecording

    /// Localized display name for the permission type.
    public var displayName: String {
        switch self {
        case .microphone:
            NSLocalizedString("permission.type.microphone", bundle: .safeModule, comment: "")
        case .screenRecording:
            NSLocalizedString("permission.type.screen_recording", bundle: .safeModule, comment: "")
        }
    }

    /// SF Symbol icon name representing the permission type.
    public var iconName: String {
        switch self {
        case .microphone:
            "mic.fill"
        case .screenRecording:
            "tv.fill"
        }
    }

    /// Description explaining why the permission is needed.
    public var permissionDescription: String {
        switch self {
        case .microphone:
            NSLocalizedString("permission.type.microphone.desc", bundle: .safeModule, comment: "")
        case .screenRecording:
            NSLocalizedString("permission.type.screen_recording.desc", bundle: .safeModule, comment: "")
        }
    }
}

/// Container for the status of a specific permission.
public struct PermissionInfo: Sendable {
    public let type: PermissionType
    public var state: PermissionState
    public var lastChecked: Date?

    public init(
        type: PermissionType,
        state: PermissionState = .notDetermined,
        lastChecked: Date? = nil
    ) {
        self.type = type
        self.state = state
        self.lastChecked = lastChecked
    }

    /// Updates the permission state with current timestamp.
    public mutating func updateState(_ newState: PermissionState) {
        self.state = newState
        self.lastChecked = Date()
    }
}

/// Observable container for all application permissions.
@MainActor
public class PermissionStatusManager: ObservableObject {
    @Published public private(set) var microphonePermission: PermissionInfo
    @Published public private(set) var screenRecordingPermission: PermissionInfo

    /// Returns true if all required permissions are granted.
    public var allPermissionsGranted: Bool {
        self.microphonePermission.state.isAuthorized
            && self.screenRecordingPermission.state.isAuthorized
    }

    /// Returns the count of granted permissions.
    public var grantedCount: Int {
        var count = 0
        if self.microphonePermission.state.isAuthorized { count += 1 }
        if self.screenRecordingPermission.state.isAuthorized { count += 1 }
        return count
    }

    /// Total number of required permissions.
    public let totalPermissions = 2

    public init() {
        self.microphonePermission = PermissionInfo(type: .microphone)
        self.screenRecordingPermission = PermissionInfo(type: .screenRecording)
    }

    /// Updates the microphone permission state.
    public func updateMicrophoneState(_ state: PermissionState) {
        self.microphonePermission.updateState(state)
    }

    /// Updates the screen recording permission state.
    public func updateScreenRecordingState(_ state: PermissionState) {
        self.screenRecordingPermission.updateState(state)
    }
}
