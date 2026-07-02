import MeetingAssistantCoreCommon
import SwiftUI

public enum SystemSettingsRoute: Hashable, Sendable {
    case root
    case permissions
}

public struct SystemSettingsTab: View {
    @Binding private var route: SystemSettingsRoute

    public init(route: Binding<SystemSettingsRoute> = .constant(.root)) {
        _route = route
    }

    public var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @MainActor
    @ViewBuilder
    private var content: some View {
        switch route {
        case .root:
            GeneralSettingsTab(
                showsHeader: true,
                headerTitleKey: "settings.section.system",
                headerDescriptionKey: "settings.system.description",
                openPermissions: { route = .permissions }
            )
        case .permissions:
            PermissionsSettingsTab()
        }
    }
}

#Preview {
    SystemSettingsTab()
        .frame(width: 900, height: 620)
}
