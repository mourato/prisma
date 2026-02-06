import SwiftUI
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

/// Project-wide design system (tokens + shared components).
///
/// Goals:
/// - Prefer macOS-native semantics (materials + semantic colors)
/// - Centralize spacing/typography/radius/shadows (DRY)
/// - Keep styling consistent across Settings, Menu Bar, and in-app views
public enum MeetingAssistantDesignSystem {
    // MARK: - Colors

    public enum Colors {
        private static var selectedAccentColor: AppThemeColor {
            let rawValue = UserDefaults.standard.string(forKey: "appAccentColor")
            return rawValue.flatMap { AppThemeColor(rawValue: $0) } ?? .system
        }

        public static var accent: Color {
            Color(nsColor: selectedAccentColor.nsColor)
        }

        public static var secondaryAccent: Color {
            accent.opacity(0.8)
        }

        public static var onAccent: Color {
            selectedAccentColor.adaptiveForegroundColor
        }

        public static let success = Color.green
        public static let warning = Color.orange
        public static let error = Color.red
        public static let neutral = Color.gray

        public static var iconHighlight: Color {
            accent
        }

        public static let aiGradient = LinearGradient(
            colors: [Color.orange, Color.red],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        public static var dashboardHeroGradient: LinearGradient {
            LinearGradient(
                colors: [accent.opacity(0.8), accent],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        public static let recording = Color.red
        public static let recordingOverlayBackground = recording.opacity(0.9)
        public static let overlayBackground = Color.black.opacity(0.95)
        public static let overlayDivider = Color.white.opacity(0.25)
        public static let overlayForeground = Color.white
        public static let overlayForegroundMuted = Color.white.opacity(0.85)

        public static let windowBackground = Color(NSColor.windowBackgroundColor)
        public static let controlBackground = Color(NSColor.controlBackgroundColor)
        public static let textBackground = Color(NSColor.textBackgroundColor)
        public static let separator = Color(NSColor.separatorColor)

        public static let glassBackground = windowBackground.opacity(0.7)
        public static let cardBackground = controlBackground.opacity(0.5)
        public static let cardStroke = Color.primary.opacity(0.1)

        public static let subtleFill = Color.primary.opacity(0.05)
        public static let subtleFill2 = Color.primary.opacity(0.03)

        public static let secondaryFill = Color.secondary.opacity(0.1)

        public static var selectionFill: Color {
            accent.opacity(0.08)
        }

        public static var selectionStroke: Color {
            accent.opacity(0.3)
        }
    }

    // MARK: - Layout

    public enum Layout {
        public static let spacing2: CGFloat = 2
        public static let spacing4: CGFloat = 4
        public static let spacing6: CGFloat = 6
        public static let spacing8: CGFloat = 8
        public static let spacing10: CGFloat = 10
        public static let spacing12: CGFloat = 12
        public static let spacing16: CGFloat = 16
        public static let spacing20: CGFloat = 20
        public static let spacing24: CGFloat = 24

        public static let tinyCornerRadius: CGFloat = 4
        public static let chipCornerRadius: CGFloat = 6
        public static let smallCornerRadius: CGFloat = 8
        public static let cardCornerRadius: CGFloat = 12
        public static let largeCornerRadius: CGFloat = 16

        public static let heroCornerRadius: CGFloat = 16
        public static let heroPadding: CGFloat = 24

        public static let cardPadding: CGFloat = 16
        public static let sectionSpacing: CGFloat = 20
        public static let itemSpacing: CGFloat = 12

        public static let controlHeight: CGFloat = 44
        public static let recordingIndicatorMiniHeight: CGFloat = 34
        public static let recordingIndicatorPanelWidth: CGFloat = 380
        public static let recordingIndicatorWaveformMaxHeight: CGFloat = 26
        public static let recordingIndicatorMiniDotSize: CGFloat = 8

        public static let shadowRadius: CGFloat = 10
        public static let shadowX: CGFloat = 0
        public static let shadowY: CGFloat = 5
        public static let shadowRadiusSmall: CGFloat = 6
        public static let shadowYSmall: CGFloat = 3

        public static let maxTextFieldWidth: CGFloat = 300
        public static let maxPickerWidth: CGFloat = 200
        public static let maxCompactTextFieldWidth: CGFloat = 200

        public static let narrowPickerWidth: CGFloat = 140
        public static let smallPickerWidth: CGFloat = 150

        public static let chartHeight: CGFloat = 220
        public static let indentation: CGFloat = 24
        public static let smallPadding: CGFloat = 4

        public static let sidebarContainerCornerRadius: CGFloat = 18
        public static let sidebarItemCornerRadius: CGFloat = 8
        public static let sidebarItemHeight: CGFloat = 44
        public static let sidebarHorizontalPadding: CGFloat = 10
        public static let sidebarVerticalPadding: CGFloat = 12
        public static let sidebarTopInset: CGFloat = 48
        public static let sidebarSectionSpacing: CGFloat = 6
        public static let sidebarItemContentSpacing: CGFloat = 8
        public static let sidebarLabelFontSize: CGFloat = 15
        public static let sidebarSymbolFontSize: CGFloat = 15
    }
}
