import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

public struct DSGroup<Content: View, HeaderAccessory: View>: View {
    private let title: String
    private let icon: String?
    private let headerAccessory: HeaderAccessory
    private let content: Content

    public init(_ title: String, icon: String? = nil, @ViewBuilder content: () -> Content)
        where HeaderAccessory == EmptyView
    {
        self.title = title
        self.icon = icon
        headerAccessory = EmptyView()
        self.content = content()
    }

    public init(
        _ title: String,
        icon: String? = nil,
        @ViewBuilder headerAccessory: () -> HeaderAccessory,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.headerAccessory = headerAccessory()
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.Layout.spacing10) {
            HStack(spacing: AppDesignSystem.Layout.spacing8) {
                if let icon {
                    Image(systemName: icon)
                        .foregroundStyle(AppDesignSystem.Colors.accent)
                }

                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                headerAccessory
            }
            .padding(.leading, AppDesignSystem.Layout.spacing4)

            DSCard {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
