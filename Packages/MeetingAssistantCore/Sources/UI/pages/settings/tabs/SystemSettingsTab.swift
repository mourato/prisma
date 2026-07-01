import MeetingAssistantCoreCommon
import SwiftUI

public enum SystemSettingsRoute: Hashable {
    case general
    case sound
    case permissions
}

public struct SystemSettingsTab: View {
    @Binding private var route: SystemSettingsRoute

    public init(route: Binding<SystemSettingsRoute> = .constant(.general)) {
        _route = route
    }

    public var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text("settings.section.system".localized)
                    .font(.headline.weight(.semibold))
                Text("settings.system.description".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Picker("", selection: $route) {
                Text("settings.section.general".localized)
                    .tag(SystemSettingsRoute.general)
                Text("settings.section.audio".localized)
                    .tag(SystemSettingsRoute.sound)
                Text("settings.section.permissions".localized)
                    .tag(SystemSettingsRoute.permissions)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 360)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    @MainActor
    @ViewBuilder
    private var content: some View {
        switch route {
        case .general:
            GeneralSettingsTab(showsHeader: false)
        case .sound:
            AudioSettingsTab(showsHeader: false)
        case .permissions:
            PermissionsSettingsTab(showsHeader: false)
        }
    }
}

#Preview {
    SystemSettingsTab()
        .frame(width: 900, height: 620)
}
