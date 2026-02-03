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
            "permission.state.granted".localized
        case .denied:
            "permission.state.denied".localized
        case .notDetermined:
            "permission.state.not_determined".localized
        case .restricted:
            "permission.state.restricted".localized
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
    case accessibility

    /// Localized display name for the permission type.
    public var displayName: String {
        switch self {
        case .microphone:
            "permission.type.microphone".localized
        case .screenRecording:
            "permission.type.screen_recording".localized
        case .accessibility:
            "permission.type.accessibility".localized
        }
    }

    /// SF Symbol icon name representing the permission type.
    public var iconName: String {
        switch self {
        case .microphone:
            "mic.fill"
        case .screenRecording:
            "tv.fill"
        case .accessibility:
            "accessibility"
        }
    }

    /// Description explaining why the permission is needed.
    public var permissionDescription: String {
        switch self {
        case .microphone:
            "permission.type.microphone.desc".localized
        case .screenRecording:
            "permission.type.screen_recording.desc".localized
        case .accessibility:
            "permission.type.accessibility.desc".localized
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
        state = newState
        lastChecked = Date()
    }
}

/// Observable container for all application permissions.
@MainActor
public class PermissionStatusManager: ObservableObject {
    @Published public private(set) var microphonePermission: PermissionInfo
    @Published public private(set) var screenRecordingPermission: PermissionInfo
    @Published public private(set) var accessibilityPermission: PermissionInfo

    /// Returns true if all required permissions are granted.
    public var allPermissionsGranted: Bool {
        microphonePermission.state.isAuthorized
            && screenRecordingPermission.state.isAuthorized
            && accessibilityPermission.state.isAuthorized
    }

    /// Returns the count of granted permissions.
    public var grantedCount: Int {
        var count = 0
        if microphonePermission.state.isAuthorized { count += 1 }
        if screenRecordingPermission.state.isAuthorized { count += 1 }
        if accessibilityPermission.state.isAuthorized { count += 1 }
        return count
    }

    /// Total number of required permissions.
    public let totalPermissions = 3

    public init() {
        microphonePermission = PermissionInfo(type: .microphone)
        screenRecordingPermission = PermissionInfo(type: .screenRecording)
        accessibilityPermission = PermissionInfo(type: .accessibility)
    }

    /// Updates the microphone permission state.
    public func updateMicrophoneState(_ state: PermissionState) {
        microphonePermission.updateState(state)
    }

    /// Updates the screen recording permission state.
    public func updateScreenRecordingState(_ state: PermissionState) {
        screenRecordingPermission.updateState(state)
    }

    public func updateAccessibilityState(_ state: PermissionState) {
        accessibilityPermission.updateState(state)
    }
}
