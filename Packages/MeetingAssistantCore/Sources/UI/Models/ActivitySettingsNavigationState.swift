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
    public var forwardRoute: ActivitySettingsRoute?
    public var pendingSheet: ActivityPendingSheet?
    public var transcriptionsNavigationHistory: TranscriptionsNavigationHistory

    public init(
        activeRoute: ActivitySettingsRoute = .root,
        forwardRoute: ActivitySettingsRoute? = nil,
        pendingSheet: ActivityPendingSheet? = nil,
        transcriptionsNavigationHistory: TranscriptionsNavigationHistory = TranscriptionsNavigationHistory(),
    ) {
        self.activeRoute = activeRoute
        self.forwardRoute = forwardRoute
        self.pendingSheet = pendingSheet
        self.transcriptionsNavigationHistory = transcriptionsNavigationHistory
    }

    public var isShowingHistoryList: Bool {
        activeRoute == .history && transcriptionsNavigationHistory.currentRoute == .list
    }

    public var canGoBack: Bool {
        activeRoute == .history
    }

    public var canGoForward: Bool {
        switch activeRoute {
        case .root:
            forwardRoute != nil
        case .history:
            transcriptionsNavigationHistory.canGoForward
        }
    }

    public mutating func apply(_ route: ActivitySettingsRoute?) {
        guard let route else { return }
        open(route)
    }

    public mutating func open(_ route: ActivitySettingsRoute) {
        guard activeRoute != route else { return }
        activeRoute = route
        forwardRoute = nil
    }

    public mutating func goBack() {
        switch activeRoute {
        case .root:
            return
        case .history:
            if transcriptionsNavigationHistory.canGoBack {
                _ = transcriptionsNavigationHistory.goBack()
            } else {
                forwardRoute = activeRoute
                activeRoute = .root
            }
        }
    }

    public mutating func goForward() {
        switch activeRoute {
        case .root:
            guard let forwardRoute else { return }
            open(forwardRoute)
        case .history:
            _ = transcriptionsNavigationHistory.goForward()
        }
    }
}
