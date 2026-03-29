import AppKit
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

/// Project-wide design system (tokens + shared components).
///
/// Goals:
/// - Prefer macOS-native semantics (materials + semantic colors)
/// - Centralize spacing/typography/radius/shadows (DRY)
/// - Keep styling consistent across Settings, Menu Bar, and in-app views
public enum AppDesignSystem {

    public enum Accessibility {
        public static var reduceTransparency: Bool {
            NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        }

        public static var increaseContrast: Bool {
            NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        }
    }

    // MARK: - Colors

    public enum Colors {
        public static var accent: Color {
            Color(nsColor: .controlAccentColor)
        }

        public static var secondaryAccent: Color {
            accent.opacity(0.8)
        }

        public static var onAccent: Color {
            .white
        }

        public static let success = Color(nsColor: .systemGreen)
        public static let warning = Color(nsColor: .systemOrange)
        public static let error = Color(nsColor: .systemRed)
        public static let neutral = Color(nsColor: .systemGray)

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
        public static let overlayBackground = Color.black.opacity(0.9)
        public static let overlayDivider = Color.white.opacity(0.2)
        public static let overlayForeground = Color.white
        public static let overlayForegroundMuted = Color.white.opacity(0.85)
        public static let recordingIndicatorMaterialTint = Color.black.opacity(0.22)
        public static let recordingIndicatorStroke = Color.white.opacity(0.22)
        public static let recordingIndicatorAuxiliaryBackground = Color.black.opacity(0.14)

        public static let windowBackground = Color(NSColor.windowBackgroundColor)
        public static let controlBackground = Color(NSColor.controlBackgroundColor)
        public static let textBackground = Color(NSColor.textBackgroundColor)
        public static let separator = Color(NSColor.separatorColor)

        public static var glassBackground: Color {
            Accessibility.reduceTransparency ? windowBackground : windowBackground.opacity(0.82)
        }

        public static var cardBackground: Color {
            if Accessibility.reduceTransparency {
                return controlBackground
            }
            return controlBackground.opacity(Accessibility.increaseContrast ? 0.9 : 0.72)
        }

        public static var cardStroke: Color {
            Color.primary.opacity(Accessibility.increaseContrast ? 0.22 : 0.1)
        }

        public static var subtleFill: Color {
            Color.primary.opacity(Accessibility.increaseContrast ? 0.11 : 0.05)
        }

        public static var subtleFill2: Color {
            Color.primary.opacity(Accessibility.increaseContrast ? 0.08 : 0.03)
        }

        public static var secondaryFill: Color {
            Color.secondary.opacity(Accessibility.increaseContrast ? 0.16 : 0.1)
        }

        public static var selectionFill: Color {
            accent.opacity(Accessibility.increaseContrast ? 0.16 : 0.08)
        }

        public static var selectionStroke: Color {
            accent.opacity(Accessibility.increaseContrast ? 0.55 : 0.3)
        }

        public static var topFadeLeading: Color {
            windowBackground
        }

        public static var topFadeTrailing: Color {
            windowBackground.opacity(Accessibility.reduceTransparency ? 1 : 0)
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

        public static let cardPadding: CGFloat = 14
        public static let sectionSpacing: CGFloat = 16
        public static let itemSpacing: CGFloat = 10

        public static let controlHeight: CGFloat = 34
        public static let compactButtonHeight: CGFloat = 30
        public static let recordingIndicatorMiniHeight: CGFloat = 38
        public static let recordingIndicatorClassicHeight: CGFloat = 42

        public static let recordingIndicatorPanelWidth: CGFloat = 380

        // Recording Indicator Metrics
        public static let recordingIndicatorClassicPromptSize: CGFloat = 42
        public static let recordingIndicatorMiniPromptSize: CGFloat = 38

        public static let recordingIndicatorClassicInnerSpacing: CGFloat = 12
        public static let recordingIndicatorMiniInnerSpacing: CGFloat = 8

        public static let recordingIndicatorClassicWaveCount: Int = 18
        public static let recordingIndicatorMiniWaveCount: Int = 9

        public static let recordingIndicatorClassicWaveHeight: CGFloat = 24
        public static let recordingIndicatorMiniWaveHeight: CGFloat = 20

        public static let recordingIndicatorWaveformBarWidth: CGFloat = 2
        public static let recordingIndicatorWaveformBarSpacing: CGFloat = 2
        public static let recordingIndicatorWaveformMinHeight: CGFloat = 2
        public static let recordingIndicatorWaveformMaxHeight: CGFloat = 24

        public static let recordingIndicatorDotSize: CGFloat = 8
        public static let recordingIndicatorMiniDotSize: CGFloat = 8
        public static let recordingIndicatorPromptGap: CGFloat = 2
        public static let recordingIndicatorSidePadding: CGFloat = 8

        public static let shadowRadius: CGFloat = 10
        public static let shadowX: CGFloat = 0
        public static let shadowY: CGFloat = 5
        public static let shadowRadiusSmall: CGFloat = 6
        public static let shadowYSmall: CGFloat = 3
        public static let recordingIndicatorMainShadowRadius: CGFloat = 10
        public static let recordingIndicatorMainShadowY: CGFloat = 5
        public static let recordingIndicatorAuxShadowRadius: CGFloat = 6
        public static let recordingIndicatorAuxShadowY: CGFloat = 3
        public static let recordingIndicatorHoverEnterResponse: CGFloat = 0.22
        public static let recordingIndicatorHoverEnterDamping: CGFloat = 0.86
        public static let recordingIndicatorHoverExitResponse: CGFloat = 0.26
        public static let recordingIndicatorHoverExitDamping: CGFloat = 0.9

        public static let maxCompactTextFieldWidth: CGFloat = 200
        public static let textAreaPadding: CGFloat = spacing8

        public static let narrowPickerWidth: CGFloat = 140
        public static let smallPickerWidth: CGFloat = 150

        public static let chartHeight: CGFloat = 220
        public static let indentation: CGFloat = 24
        public static let smallPadding: CGFloat = 4
        public static let compactInset: CGFloat = spacing6

        public static let sidebarContainerCornerRadius: CGFloat = 18
        public static let sidebarItemCornerRadius: CGFloat = 8
        public static let sidebarItemHeight: CGFloat = 36
        public static let sidebarHorizontalPadding: CGFloat = 8
        public static let sidebarVerticalPadding: CGFloat = 10
        public static let sidebarTopInset: CGFloat = 36
        public static let sidebarSectionSpacing: CGFloat = 6
        public static let sidebarItemContentSpacing: CGFloat = 8
        public static let sidebarLabelFontSize: CGFloat = 12
        public static let sidebarSymbolFontSize: CGFloat = 14
    }
}
