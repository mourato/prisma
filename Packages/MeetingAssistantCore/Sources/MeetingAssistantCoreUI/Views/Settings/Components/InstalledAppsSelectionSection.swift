import MeetingAssistantCoreCommon
import MeetingAssistantCoreInfrastructure
import SwiftUI

public struct InstalledAppsSelectionSection: View {
    private let titleKey: String
    private let descriptionKey: String
    private let emptyKey: String
    private let addButtonKey: String
    private let icon: String
    @ObservedObject private var viewModel: InstalledAppsSelectionViewModel

    public init(
        titleKey: String,
        descriptionKey: String,
        emptyKey: String,
        addButtonKey: String,
        icon: String,
        viewModel: InstalledAppsSelectionViewModel
    ) {
        self.titleKey = titleKey
        self.descriptionKey = descriptionKey
        self.emptyKey = emptyKey
        self.addButtonKey = addButtonKey
        self.icon = icon
        self.viewModel = viewModel
    }

    public var body: some View {
        MAGroup(titleKey.localized, icon: icon) {
            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
                Text(descriptionKey.localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if viewModel.installedApps.isEmpty {
                    Text(emptyKey.localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.installedApps.enumerated()), id: \.element.id) { index, app in
                            appRow(app)

                            if index < viewModel.installedApps.count - 1 {
                                Divider()
                            }
                        }
                    }
                    .background(MeetingAssistantDesignSystem.Colors.subtleFill2)
                    .clipShape(RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.smallCornerRadius))
                }

                HStack {
                    Spacer()
                    Button {
                        viewModel.addApp()
                    } label: {
                        Label(addButtonKey.localized, systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .onAppear {
            viewModel.refreshTargets()
        }
    }

    private func appRow(_ app: InstalledAppItem) -> some View {
        HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing12) {
            Image(nsImage: app.icon)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .padding(6)
                .background(MeetingAssistantDesignSystem.Colors.subtleFill)
                .clipShape(RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.smallCornerRadius))

            VStack(alignment: .leading, spacing: 2) {
                Text(app.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(app.bundleIdentifier)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(role: .destructive) {
                viewModel.removeApp(bundleIdentifier: app.bundleIdentifier)
            } label: {
                Image(systemName: "minus.circle")
                    .accessibilityLabel("settings.markdown_targets.remove".localized)
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
        }
        .padding(.horizontal, MeetingAssistantDesignSystem.Layout.spacing12)
        .padding(.vertical, MeetingAssistantDesignSystem.Layout.spacing8)
    }
}

#Preview {
    PreviewStateContainer(AppSettingsStore.defaultMarkdownTargetBundleIdentifiers) { identifiers in
        InstalledAppsSelectionSection(
            titleKey: "settings.markdown_targets.title",
            descriptionKey: "settings.markdown_targets.description",
            emptyKey: "settings.markdown_targets.empty",
            addButtonKey: "settings.markdown_targets.add",
            icon: "textformat",
            viewModel: InstalledAppsSelectionViewModel(
                defaultBundleIdentifiers: identifiers.wrappedValue,
                hasConfigured: { true },
                loadBundleIdentifiers: { identifiers.wrappedValue },
                saveBundleIdentifiers: { identifiers.wrappedValue = $0 }
            )
        )
        .padding()
    }
}
