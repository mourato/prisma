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
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .foregroundStyle(AppDesignSystem.Colors.accent)
                }

                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                headerAccessory
            }
            .padding(.leading, 4)

            DSCard {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("DSGroup") {
    DSGroup("Design Group", icon: "cube.fill", headerAccessory: {
        DSBadge("Preview", kind: .neutral)
    }) {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reusable layout container.")
                .foregroundStyle(.secondary)
            Text("Contains a title, optional icon, and accessory.")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
    .padding()
}
