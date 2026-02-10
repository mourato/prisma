import SwiftUI
import MeetingAssistantCoreInfrastructure

/// Backwards-compatible alias for legacy Settings-only naming.
public typealias SettingsDesignSystem = MeetingAssistantDesignSystem

public typealias SettingsCard = MACard

public typealias SettingsGroup = MAGroup

public typealias SettingsToggle = MAToggleRow

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

#Preview("Settings Theme Picker") {
    PreviewStateContainer(AppThemeColor.blue) { selection in
        SettingsThemePicker(selection: selection)
            .padding()
    }
}
