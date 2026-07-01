public enum ActivitySettingsRoute: Hashable, Sendable {
    case dashboard
    case history
}

public struct ActivitySettingsNavigationState: Equatable {
    public var activeRoute: ActivitySettingsRoute
    public var metricsNavigationState: SettingsSubpageNavigationState<MetricsDashboardRoute>
    public var transcriptionsNavigationHistory: TranscriptionsNavigationHistory

    public init(
        activeRoute: ActivitySettingsRoute = .dashboard,
        metricsNavigationState: SettingsSubpageNavigationState<MetricsDashboardRoute> = SettingsSubpageNavigationState(),
        transcriptionsNavigationHistory: TranscriptionsNavigationHistory = TranscriptionsNavigationHistory()
    ) {
        self.activeRoute = activeRoute
        self.metricsNavigationState = metricsNavigationState
        self.transcriptionsNavigationHistory = transcriptionsNavigationHistory
    }

    public var isShowingHistoryList: Bool {
        activeRoute == .history && transcriptionsNavigationHistory.currentRoute == .list
    }

    public var canGoBack: Bool {
        switch activeRoute {
        case .dashboard:
            metricsNavigationState.canGoBack
        case .history:
            transcriptionsNavigationHistory.canGoBack
        }
    }

    public var canGoForward: Bool {
        switch activeRoute {
        case .dashboard:
            metricsNavigationState.canGoForward
        case .history:
            transcriptionsNavigationHistory.canGoForward
        }
    }

    public mutating func apply(_ route: ActivitySettingsRoute?) {
        guard let route else { return }
        activeRoute = route
    }

    public mutating func goBack() {
        switch activeRoute {
        case .dashboard:
            _ = metricsNavigationState.goBack()
        case .history:
            _ = transcriptionsNavigationHistory.goBack()
        }
    }

    public mutating func goForward() {
        switch activeRoute {
        case .dashboard:
            _ = metricsNavigationState.goForward()
        case .history:
            _ = transcriptionsNavigationHistory.goForward()
        }
    }
}
