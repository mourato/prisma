import SwiftUI

public struct SettingsScrollableContent<Content: View>: View {
    private let spacing: CGFloat
    private let content: Content

    public init(
        spacing: CGFloat = AppDesignSystem.Layout.sectionSpacing,
        @ViewBuilder content: () -> Content,
    ) {
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: spacing) {
                    content
                }
                .padding(EdgeInsets(top: 0, leading: 20, bottom: 20, trailing: 20))
                .frame(
                    minWidth: geometry.size.width,
                    minHeight: geometry.size.height,
                    alignment: .topLeading,
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .settingsScrollEdgeEffect()
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .subtleScrollbars()
        }
    }
}

// MARK: - Surface Contract Previews

private struct SettingsContentSurfacePreview: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            SettingsWindowBackground()

            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                    Text("Settings toolbar boundary")
                        .font(.headline)
                    Spacer()
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .frame(height: 44)
                .background(SettingsTitleBarMaterialBackground())

                SettingsScrollableContent {
                    DSGroup("settings.section.general".localized, icon: "gearshape.fill") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Surface contract demonstration")
                                .font(.headline)
                                .foregroundStyle(.primary)

                            Text("20pt horizontal gutter on both sides, content below the chrome boundary, bottom breathing room, and scrollable content.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                    }

                    DSGroup {
                        VStack(alignment: .leading, spacing: 8) {
                            SettingsRowClickSurface(onSingleClick: {}, content: {
                                HStack {
                                    Text("Row item")
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                            })
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(height: 400)
    }
}

#Preview("Content Surface (Normal)") {
    SettingsContentSurfacePreview()
        .frame(width: 900)
}

#Preview("Content Surface (Narrow)") {
    SettingsContentSurfacePreview()
        .frame(width: 600)
}
