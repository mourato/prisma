import SwiftUI

// MARK: - Presentation Layer Protocols

/// Protocolo base para objetos que podem apresentar views
@MainActor
public protocol Presenter {
    associatedtype ViewType: View

    /// Retorna a view a ser apresentada
    func present() -> ViewType
}

/// Protocolo para objetos que coordenam navegação
@MainActor
public protocol NavigationCoordinator: AnyObject {
    /// Coordinator pai (opcional)
    var parentCoordinator: NavigationCoordinator? { get set }

    /// Coordinators filhos
    var childCoordinators: [NavigationCoordinator] { get set }

    /// Inicia o coordinator
    func start()

    /// Navega para uma rota específica
    func navigate(to route: AppRoute)

    /// Volta para a tela anterior
    func goBack()

    /// Fecha o coordinator atual
    func dismiss()
}

/// Protocolo para view models que suportam navegação
@MainActor
public protocol NavigableViewModel: ObservableObject {
    associatedtype CoordinatorType: NavigationCoordinator

    /// Coordinator associado para navegação
    var coordinator: CoordinatorType? { get set }

    /// Ações de navegação disponíveis
    func navigate(to route: AppRoute)
    func goBack()
    func dismiss()
}

/// Protocolo para views que têm coordinators
@MainActor
public protocol CoordinatableView: View {
    associatedtype CoordinatorType: Coordinator

    /// Coordinator da view
    var coordinator: CoordinatorType { get }
}

// MARK: - Route Definitions

/// Rotas principais da aplicação
public enum AppRoute {
    case main
    case settings(SettingsTab)
    case transcriptionDetails(Transcription)
    case permissionSetup

    /// Sub-rotas para configurações
    public enum SettingsTab {
        case general
        case audio
        case transcription
        case shortcuts
        case postProcessing
    }
}

// MARK: - Type Aliases

/// Type alias para facilitar uso do Coordinator base
public typealias AppCoordinator = Coordinator