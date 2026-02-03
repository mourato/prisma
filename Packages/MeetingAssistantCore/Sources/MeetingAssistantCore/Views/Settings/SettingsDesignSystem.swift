import SwiftUI

/// Design system for the Settings module, following macOS 26 Tahoe aesthetic.
public enum SettingsDesignSystem {
    // MARK: - Colors & Gradients

    @MainActor
    public enum Colors {
        public static var accent: Color {
            Color(nsColor: AppSettingsStore.shared.appAccentColor.nsColor)
        }

        public static var secondaryAccent: Color {
            accent.opacity(0.8)
        }

        public static var onAccent: Color {
            AppSettingsStore.shared.appAccentColor.adaptiveForegroundColor
        }

        public static let glassBackground = Color(NSColor.windowBackgroundColor).opacity(0.7)
        public static let cardBackground = Color(NSColor.controlBackgroundColor).opacity(0.5)

        public static var iconHighlight: Color { accent }

        public static let aiGradient = LinearGradient(
            colors: [Color.orange, Color.red],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Layout Constants

    public enum Layout {
        public static let cardCornerRadius: CGFloat = 12
        public static let cardPadding: CGFloat = 16
        public static let sectionSpacing: CGFloat = 20
        public static let itemSpacing: CGFloat = 12
    }
}

// MARK: - Custom Components

/// A premium card container for settings groups.
public struct SettingsCard<Content: View>: View {
    let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: SettingsDesignSystem.Layout.itemSpacing) {
            content
        }
        .padding(SettingsDesignSystem.Layout.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: SettingsDesignSystem.Layout.cardCornerRadius)
                .fill(SettingsDesignSystem.Colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: SettingsDesignSystem.Layout.cardCornerRadius)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                )
        )
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: SettingsDesignSystem.Layout.cardCornerRadius))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A labeled group of settings with a Tahoe-style header.
public struct SettingsGroup<Content: View>: View {
    let title: String
    let icon: String?
    let content: Content

    public init(_ title: String, icon: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .foregroundStyle(SettingsDesignSystem.Colors.iconHighlight)
                        .symbolEffect(.bounce, value: true)
                }

                Text(title)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.primary)
            }
            .padding(.leading, 4)

            SettingsCard {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A standard toggle row with title on the left and switch on the right.
public struct SettingsToggle: View {
    let title: String
    let description: String?
    @Binding var isOn: Bool

    public init(_ title: String, description: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.description = description
        _isOn = isOn
    }

    public var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
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

/// A theme-aware color picker for settings.
public struct SettingsThemePicker: View {
    @Binding var selection: AppThemeColor

    public init(selection: Binding<AppThemeColor>) {
        _selection = selection
    }

    public var body: some View {
        HStack(spacing: 12) {
            ForEach(AppThemeColor.allCases, id: \.self) { color in
                colorCircle(color)
            }
        }
    }

    @ViewBuilder
    private func colorCircle(_ color: AppThemeColor) -> some View {
        let isSelected = selection == color

        Button {
            selection = color
        } label: {
            ZStack {
                if color == .system {
                    Circle()
                        .fill(
                            AngularGradient(
                                colors: [.red, .orange, .yellow, .green, .blue, .purple, .red],
                                center: .center
                            )
                        )
                } else {
                    Circle()
                        .fill(Color(nsColor: color.nsColor))
                }
            }
            .frame(width: 28, height: 28)
            .overlay {
                if isSelected {
                    Circle()
                        .stroke(color == .system ? Color.primary.opacity(0.3) : Color(nsColor: color.nsColor), lineWidth: 3)
                        .frame(width: 36, height: 36)
                }
            }
            .overlay {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(color == .system ? AnyShapeStyle(.primary) : AnyShapeStyle(Color.white))
                        .shadow(color: .black.opacity(color == .system ? 0.1 : 0.3), radius: 1, x: 0, y: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(width: 40, height: 40)
        .contentShape(Rectangle())
    }
}
