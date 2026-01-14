import SwiftUI

/// Coordinator principal da aplicação.
/// Gerencia navegação entre telas principais e coordena coordinators filhos.
@MainActor
public final class AppCoordinator: Coordinator {
    // MARK: - Properties

    public weak var parentCoordinator: Coordinator?
    public var childCoordinators: [Coordinator] = []

    private let navigationService: NavigationService
    private let repositoryFactory: RepositoryFactory
    private let recordingManager: RecordingManager

    // MARK: - Initialization

    public init(
        navigationService: NavigationService = .shared,
        repositoryFactory: RepositoryFactory = DefaultRepositoryFactory(),
        recordingManager: RecordingManager
    ) {
        self.navigationService = navigationService
        self.repositoryFactory = repositoryFactory
        self.recordingManager = recordingManager
    }

    // MARK: - Coordinator Protocol

    public func start() -> AnyView {
        self.navigateToMain()
    }

    public func navigate(to route: AppRoute) {
        switch route {
        case .main:
            self.navigateToMain()
        case let .settings(tab):
            self.navigateToSettings(tab: tab)
        case let .transcriptionDetails(transcription):
            self.navigateToTranscriptionDetails(transcription)
        case .permissionSetup:
            self.navigateToPermissionSetup()
        }
    }

    public func goBack() {
        // Implementar navegação para trás se necessário
        // Por enquanto, volta para main
        self.navigate(to: .main)
    }

    public func dismiss() {
        // Coordinator principal não pode ser dispensado
        // Implementar lógica de cleanup se necessário
    }

    // MARK: - Navigation Methods

    private func navigateToMain() -> AnyView {
        let viewModel = RecordingViewModel(recordingManager: recordingManager)

        let mainView = MenuBarView(viewModel: viewModel)
        return AnyView(mainView)
    }

    private func navigateToSettings(tab: AppRoute.SettingsTab) -> AnyView {
        let coordinator = SettingsCoordinator(
            repositoryFactory: repositoryFactory,
            recordingManager: recordingManager,
            initialTab: tab
        )
        coordinator.parentCoordinator = self

        self.childCoordinators.append(coordinator)

        let settingsView = coordinator.start()
        return settingsView
    }

    private func navigateToTranscriptionDetails(_ transcription: Transcription) -> AnyView {
        let detailView = TranscriptionDetailView(transcription: transcription)
        return AnyView(detailView)
    }

    private func navigateToPermissionSetup() -> AnyView {
        let viewModel = PermissionViewModel(
            manager: self.recordingManager.permissionStatus,
            requestMicrophone: { [weak self] in await self?.recordingManager.requestPermission() },
            requestScreen: { [weak self] in await self?.recordingManager.requestPermission() },
            openMicrophoneSettings: { [weak self] in self?.recordingManager.openMicrophoneSettings() },
            openScreenSettings: { [weak self] in self?.recordingManager.openPermissionSettings() }
        )
        let permissionView = PermissionStatusView(viewModel: viewModel)
        return AnyView(permissionView)
    }

    // MARK: - Child Coordinator Management

    /// Remove coordinator filho quando ele for dispensado
    func childCoordinatorDidFinish(_ coordinator: Coordinator) {
        if let index = childCoordinators.firstIndex(where: { $0 === coordinator }) {
            self.childCoordinators.remove(at: index)
        }
    }
}
