import SwiftUI

public struct SettingsListGroup<Content: View, HeaderAccessory: View>: View {
    private let title: String
    private let icon: String?
    private let surfaceIntensity: AppDesignSystem.SettingsSurfaceIntensity
    private let headerAccessory: HeaderAccessory
    private let content: Content

    public init(
        _ title: String,
        icon: String? = nil,
        surfaceIntensity: AppDesignSystem.SettingsSurfaceIntensity = .regular,
        @ViewBuilder content: () -> Content
    )
        where HeaderAccessory == EmptyView
    {
        self.title = title
        self.icon = icon
        self.surfaceIntensity = surfaceIntensity
        headerAccessory = EmptyView()
        self.content = content()
    }

    public init(
        _ title: String,
        icon: String? = nil,
        surfaceIntensity: AppDesignSystem.SettingsSurfaceIntensity = .regular,
        @ViewBuilder headerAccessory: () -> HeaderAccessory,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.surfaceIntensity = surfaceIntensity
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

                Spacer(minLength: 0)

                headerAccessory
            }
            .padding(.leading, 4)

            DSCard(style: .settings, settingsSurfaceIntensity: surfaceIntensity, padding: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    content
                }
                .padding(.horizontal, AppDesignSystem.Layout.cardPadding)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

public extension View {
    func settingsListRow() -> some View {
        modifier(SettingsListRowModifier())
    }
}

private struct SettingsListRowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
    }
}

#Preview("Settings List Group") {
    SettingsListGroup("Workflow", icon: "bolt.fill") {
        DSToggleRow("Automatically start recording", isOn: .constant(true))

        Divider()

        SettingsDrillDownButtonRow(title: "Configure monitored apps and sites") {}
    }
    .padding()
}
