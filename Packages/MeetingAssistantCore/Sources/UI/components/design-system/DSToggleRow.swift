import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

public struct DSToggleRow: View {
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
            VStack(alignment: .leading, spacing: 4) {
                if let tooltip, !tooltip.isEmpty {
                    SettingsTitleWithPopover(
                        title: title,
                        helperMessage: description
                    )
                    .help(tooltip)
                } else {
                    SettingsTitleWithPopover(
                        title: title,
                        helperMessage: description
                    )
                }
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isOn.toggle()
        }
    }
}

#Preview("Toggle Row") {
    PreviewStateContainer(true) { isOn in
        DSToggleRow(
            "Enable smart post-processing",
            description: "Automatically format transcript output after each recording.",
            tooltip: "This can increase processing time for larger meetings.",
            isOn: isOn
        )
        .padding()
        .frame(width: 520)
    }
}
