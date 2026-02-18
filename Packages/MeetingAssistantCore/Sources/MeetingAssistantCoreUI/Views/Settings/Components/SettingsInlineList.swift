import SwiftUI

public struct SettingsInlineList<Item: Identifiable, RowContent: View>: View {
    private let items: [Item]
    private let emptyText: String
    private let rowContent: (Item) -> RowContent

    public init(
        items: [Item],
        emptyText: String,
        @ViewBuilder rowContent: @escaping (Item) -> RowContent
    ) {
        self.items = items
        self.emptyText = emptyText
        self.rowContent = rowContent
    }

    public var body: some View {
        if items.isEmpty {
            Text(emptyText)
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    rowContent(item)

                    if index < items.count - 1 {
                        Divider()
                    }
                }
            }
            .background(MeetingAssistantDesignSystem.Colors.subtleFill2)
            .clipShape(RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.smallCornerRadius))
        }
    }
}
