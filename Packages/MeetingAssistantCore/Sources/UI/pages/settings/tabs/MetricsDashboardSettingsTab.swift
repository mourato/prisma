import Combine
import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain
import SwiftUI

public enum MetricsDashboardRoute: Hashable {
    case moreInsights
    case eventDetail(MeetingCalendarEventSnapshot)
}

public struct MetricsDashboardSettingsTab: View {
    @StateObject private var viewModel = MetricsDashboardViewModel()
    @Binding private var navigationState: SettingsSubpageNavigationState<MetricsDashboardRoute>

    @MainActor
    public init(
        navigationState: Binding<SettingsSubpageNavigationState<MetricsDashboardRoute>> = .constant(SettingsSubpageNavigationState())
    ) {
        _navigationState = navigationState
    }

    public var body: some View {
        Group {
            switch navigationState.currentRoute {
            case nil:
                MetricsDashboardIndexPage(viewModel: viewModel) {
                    navigationState.open(.moreInsights)
                } openEventDetail: { event in
                    navigationState.open(.eventDetail(event))
                }
            case .some(.moreInsights):
                MetricsDashboardMoreInsightsPage(viewModel: viewModel)
            case let .some(.eventDetail(event)):
                MetricsDashboardEventDetailPage(event: event, viewModel: viewModel)
            }
        }
        .task {
            await viewModel.load()
        }
        .onReceive(NotificationCenter.default.publisher(for: .meetingAssistantTranscriptionSaved)) { notification in
            Task { await viewModel.handleTranscriptionSaved(notification) }
        }
    }
}

#Preview {
    MetricsDashboardSettingsTab()
}
