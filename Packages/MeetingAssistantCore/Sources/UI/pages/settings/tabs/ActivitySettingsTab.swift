import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain
import SwiftUI

public struct ActivitySettingsTab: View {
    @Binding private var navigationState: ActivitySettingsNavigationState
    @Binding private var transcriptionsSearchText: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @MainActor
    public init(
        navigationState: Binding<ActivitySettingsNavigationState> = .constant(ActivitySettingsNavigationState()),
        transcriptionsSearchText: Binding<String> = .constant("")
    ) {
        _navigationState = navigationState
        _transcriptionsSearchText = transcriptionsSearchText
    }

    public var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var header: some View {
        HStack {
            Picker("", selection: $navigationState.activeRoute) {
                Text("settings.section.metrics".localized)
                    .tag(ActivitySettingsRoute.dashboard)
                Text("settings.section.history".localized)
                    .tag(ActivitySettingsRoute.history)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 260)
            .padding(.leading, 24)

            Spacer()
        }
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var content: some View {
        switch navigationState.activeRoute {
        case .dashboard:
            MetricsDashboardSettingsTab(navigationState: $navigationState.metricsNavigationState)
        case .history:
            TranscriptionsSettingsTab(
                searchText: $transcriptionsSearchText,
                navigationHistory: $navigationState.transcriptionsNavigationHistory
            )
        }
    }
}

#Preview {
    ActivitySettingsTab()
        .frame(width: 900, height: 620)
}
