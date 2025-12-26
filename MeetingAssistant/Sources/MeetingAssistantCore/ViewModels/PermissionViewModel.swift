import Combine
import Foundation
import SwiftUI

@MainActor
public class PermissionViewModel: ObservableObject {
    // MARK: - Dependencies
    private let permissionManager: PermissionStatusManager
    // Optional: We might need a way to trigger requests back to RecordingManager
    // Or we keep requests in RecordingViewModel and just observe state here?
    // Better: Inject a closure or protocol for requests to decouple.
    private let requestMicrophoneAction: () async -> Void
    private let requestScreenAction: () async -> Void
    private let openMicrophoneSettingsAction: () -> Void
    private let openScreenSettingsAction: () -> Void

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Published Properties
    @Published public private(set) var microphoneState: PermissionState = .notDetermined
    @Published public private(set) var screenState: PermissionState = .notDetermined

    // MARK: - Init
    public init(
        manager: PermissionStatusManager,
        requestMicrophone: @escaping () async -> Void,
        requestScreen: @escaping () async -> Void,
        openMicrophoneSettings: @escaping () -> Void,
        openScreenSettings: @escaping () -> Void
    ) {
        self.permissionManager = manager
        self.requestMicrophoneAction = requestMicrophone
        self.requestScreenAction = requestScreen
        self.openMicrophoneSettingsAction = openMicrophoneSettings
        self.openScreenSettingsAction = openScreenSettings

        setupBindings()
    }

    // MARK: - Actions
    public func requestMicrophonePermission() async {
        await requestMicrophoneAction()
    }

    public func requestScreenPermission() async {
        await requestScreenAction()
    }

    public func openMicrophoneSystemSettings() {
        openMicrophoneSettingsAction()
    }

    public func openScreenSystemSettings() {
        openScreenSettingsAction()
    }

    // MARK: - Private
    private func setupBindings() {
        permissionManager.$microphonePermission
            .map { $0.state }
            .receive(on: DispatchQueue.main)
            .assign(to: &$microphoneState)

        permissionManager.$screenRecordingPermission
            .map { $0.state }
            .receive(on: DispatchQueue.main)
            .assign(to: &$screenState)
    }
}
