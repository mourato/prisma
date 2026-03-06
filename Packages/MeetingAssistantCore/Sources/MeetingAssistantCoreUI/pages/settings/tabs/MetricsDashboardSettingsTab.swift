import Combine
import MeetingAssistantCoreCommon
import SwiftUI

enum MetricsDashboardRoute: Hashable {
    case moreInsights
}

public struct MetricsDashboardSettingsTab: View {
    @StateObject private var viewModel = MetricsDashboardViewModel()

    @MainActor
    public init() {}

    public var body: some View {
        NavigationStack {
            MetricsDashboardIndexPage(viewModel: viewModel)
                .navigationDestination(for: MetricsDashboardRoute.self) { route in
                    switch route {
                    case .moreInsights:
                        MetricsDashboardMoreInsightsPage(viewModel: viewModel)
                    }
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
