import SwiftUI
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

public struct MAGroup<Content: View>: View {
    private let title: String
    private let icon: String?
    private let content: Content

    public init(_ title: String, icon: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing10) {
            HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
                if let icon {
                    Image(systemName: icon)
                        .foregroundStyle(MeetingAssistantDesignSystem.Colors.accent)
                }

                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            .padding(.leading, MeetingAssistantDesignSystem.Layout.spacing4)

            MACard {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
