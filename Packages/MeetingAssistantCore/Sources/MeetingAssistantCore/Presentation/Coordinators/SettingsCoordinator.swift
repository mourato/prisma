import SwiftUI

/// Coordinator responsável pela navegação dentro das configurações.
/// Gerencia as abas de configurações e navegação entre elas.
@MainActor
public final class SettingsCoordinator: Coordinator {
    // MARK: - Properties

    public weak var parentCoordinator: Coordinator?
    public var childCoordinators: [Coordinator] = []

    private let repositoryFactory: RepositoryFactory
    private let recordingManager: RecordingManager
    private let initialTab: AppRoute.SettingsTab

    /// Estado da navegação
    @Published private var selectedTab: AppRoute.SettingsTab

    // MARK: - Initialization

    public init(
        repositoryFactory: RepositoryFactory,
        recordingManager: RecordingManager,
        initialTab: AppRoute.SettingsTab = .general
    ) {
        self.repositoryFactory = repositoryFactory
        self.recordingManager = recordingManager
        self.initialTab = initialTab
        selectedTab = initialTab
    }

    // MARK: - Coordinator Protocol

    public func start() -> AnyView {
        let settingsView = SettingsView()
        return AnyView(settingsView)
    }

    public func navigate(to route: AppRoute) {
        switch route {
        case let .settings(tab):
            selectedTab = tab
        default:
            // Delegar para coordinator pai
            parentCoordinator?.navigate(to: route)
        }
    }

    public func goBack() {
        // Voltar para tela principal
        parentCoordinator?.navigate(to: .main)
    }

    public func dismiss() {
        // Notificar coordinator pai
        if let parent = parentCoordinator as? AppCoordinator {
            parent.childCoordinatorDidFinish(self)
        }
    }

    // MARK: - Navigation Methods

    /// Navega para uma aba específica das configurações
    func navigateToTab(_ tab: AppRoute.SettingsTab) {
        selectedTab = tab
    }

    /// Retorna a aba atualmente selecionada
    var currentTab: AppRoute.SettingsTab {
        selectedTab
    }
}

/// ViewModel que conecta o coordinator com a view de configurações
@MainActor
public final class SettingsCoordinatorViewModel: ObservableObject {
    // MARK: - Properties

    @Published var selectedTab: AppRoute.SettingsTab

    private let repositoryFactory: RepositoryFactory
    private let recordingManager: RecordingManager
    private weak var coordinator: SettingsCoordinator?

    // MARK: - Initialization

    init(
        repositoryFactory: RepositoryFactory,
        recordingManager: RecordingManager,
        coordinator: SettingsCoordinator
    ) {
        self.repositoryFactory = repositoryFactory
        self.recordingManager = recordingManager
        self.coordinator = coordinator
        selectedTab = coordinator.currentTab
    }

    // MARK: - Tab Navigation

    func selectTab(_ tab: AppRoute.SettingsTab) {
        selectedTab = tab
        coordinator?.navigateToTab(tab)
    }

    // MARK: - View Models for Tabs

    func generalSettingsViewModel() -> GeneralSettingsViewModel {
        GeneralSettingsViewModel()
    }

    func audioSettingsViewModel() -> AISettingsViewModel {
        AISettingsViewModel(settings: .shared)
    }

    func transcriptionSettingsViewModel() -> TranscriptionSettingsViewModel {
        TranscriptionSettingsViewModel(recordingManager: recordingManager)
    }

    func shortcutsSettingsViewModel() -> ShortcutSettingsViewModel {
        ShortcutSettingsViewModel()
    }

    func postProcessingSettingsViewModel() -> PostProcessingSettingsViewModel {
        PostProcessingSettingsViewModel()
    }

    // MARK: - Actions

    func dismiss() {
        coordinator?.dismiss()
    }
}
