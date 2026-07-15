import SwiftUI

public struct ActivitySettingsTab: View {
    @StateObject private var viewModel = MetricsDashboardViewModel()
    @Binding private var navigationState: ActivitySettingsNavigationState
    @State private var presentedSheet: ActivityPresentationSheet?

    @MainActor
    public init(
        navigationState: Binding<ActivitySettingsNavigationState> = .constant(ActivitySettingsNavigationState()),
    ) {
        _navigationState = navigationState
    }

    public var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .sheet(item: $presentedSheet) { sheet in
                switch sheet {
                case .moreInsights:
                    ActivityMoreInsightsSheet(viewModel: viewModel)
                case .performance:
                    ActivityPerformanceSheet(viewModel: viewModel)
                case let .eventDetail(event):
                    ActivityEventDetailSheet(event: event, viewModel: viewModel)
                }
            }
            .onChange(of: navigationState.pendingSheet) { _, pending in
                guard pending != nil else { return }
                presentPendingSheetIfNeeded()
            }
            .onAppear {
                presentPendingSheetIfNeeded()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch navigationState.activeRoute {
        case .root:
            rootPage
        case .history:
            TranscriptionsSettingsTab(
                navigationHistory: $navigationState.transcriptionsNavigationHistory,
                onBackToActivity: {
                    navigationState.goBack()
                },
            )
        }
    }

    private var rootPage: some View {
        ActivityDashboardRootPage(
            viewModel: viewModel,
            openHistory: { navigationState.open(.history) },
            openMoreInsights: { presentedSheet = .moreInsights },
            openPerformance: { presentedSheet = .performance },
            openEventDetail: { presentedSheet = .eventDetail($0) },
        )
        .task {
            await viewModel.load()
            presentPendingSheetIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .meetingAssistantTranscriptionSaved)) { notification in
            Task {
                await viewModel.handleTranscriptionSaved(notification)
            }
        }
    }

    private func presentPendingSheetIfNeeded() {
        guard let pending = navigationState.pendingSheet else { return }
        if navigationState.activeRoute != .root {
            navigationState.open(.root)
        }
        switch pending {
        case .performance:
            presentedSheet = .performance
        }
        navigationState.pendingSheet = nil
    }
}

#Preview {
    ActivitySettingsTab()
        .frame(width: 900, height: 620)
}
