import SwiftUI

public struct SettingsInlineList<Item: Identifiable, RowContent: View>: View {
    public enum State {
        case ready
        case loading(title: String, message: String? = nil)
        case warning(title: String, message: String? = nil)
    }

    private let items: [Item]
    private let emptyText: String
    private let state: State
    private let rowContent: (Item) -> RowContent

    public init(
        items: [Item],
        emptyText: String,
        state: State = .ready,
        @ViewBuilder rowContent: @escaping (Item) -> RowContent
    ) {
        self.items = items
        self.emptyText = emptyText
        self.state = state
        self.rowContent = rowContent
    }

    public var body: some View {
        switch state {
        case let .loading(title, message):
            SettingsStateBlock(kind: .loading, title: title, message: message)
        case let .warning(title, message):
            SettingsStateBlock(kind: .warning, title: title, message: message)
        case .ready:
            content
        }
    }

    @ViewBuilder
    private var content: some View {
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
            .background(AppDesignSystem.Colors.subtleFill2)
            .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.Layout.smallCornerRadius))
        }
    }
}
