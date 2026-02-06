import SwiftUI

public struct MAToggleRow: View {
    private let title: String
    private let description: String?
    @Binding private var isOn: Bool

    public init(_ title: String, description: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.description = description
        _isOn = isOn
    }

    public var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing4) {
                Text(title)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)

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
