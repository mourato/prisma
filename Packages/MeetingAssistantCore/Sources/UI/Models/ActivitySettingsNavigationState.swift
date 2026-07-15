import MeetingAssistantCoreDomain

public enum ActivitySettingsRoute: Hashable, Sendable {
    case root
    case history
}

public enum ActivityPendingSheet: Hashable, Sendable {
    case performance
}

public struct ActivitySettingsNavigationState: Equatable {
    public var activeRoute: ActivitySettingsRoute
    public var pendingSheet: ActivityPendingSheet?
    public var transcriptionsNavigationHistory: TranscriptionsNavigationHistory

    public init(
        activeRoute: ActivitySettingsRoute = .root,
        pendingSheet: ActivityPendingSheet? = nil,
        transcriptionsNavigationHistory: TranscriptionsNavigationHistory = TranscriptionsNavigationHistory(),
    ) {
        self.activeRoute = activeRoute
        self.pendingSheet = pendingSheet
        self.transcriptionsNavigationHistory = transcriptionsNavigationHistory
    }

    public var isShowingHistoryList: Bool {
        activeRoute == .history && transcriptionsNavigationHistory.currentRoute == .list
    }

    public var canGoBack: Bool {
        switch activeRoute {
        case .root:
            false
        case .history:
            true
        }
    }

    public mutating func apply(_ route: ActivitySettingsRoute?) {
        guard let route else { return }
        open(route)
    }

    public mutating func open(_ route: ActivitySettingsRoute) {
        guard activeRoute != route else { return }
        activeRoute = route
    }

    public mutating func goBack() {
        switch activeRoute {
        case .root:
            return
        case .history:
            if transcriptionsNavigationHistory.canGoBack {
                _ = transcriptionsNavigationHistory.goBack()
            } else {
                activeRoute = .root
            }
        }
    }
}
