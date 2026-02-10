import SwiftUI
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

public struct MAToggleRow: View {
    private let title: String
    private let description: String?
    private let tooltip: String?
    @Binding private var isOn: Bool

    public init(_ title: String, description: String? = nil, tooltip: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.description = description
        self.tooltip = tooltip
        _isOn = isOn
    }

    public var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing4) {
                if let tooltip {
                    Text(title)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                        .help(tooltip)
                } else {
                    Text(title)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isOn.toggle()
        }
    }
}
