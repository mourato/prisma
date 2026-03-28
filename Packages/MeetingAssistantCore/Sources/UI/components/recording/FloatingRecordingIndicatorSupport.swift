import AppKit
import Foundation
import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

// MARK: - Pulsing Animation Modifier

/// Modifier that adds a subtle pulsing animation.
struct PulsingModifier: ViewModifier {
    let isActive: Bool
    let speed: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 0.75 : 1.0)
            .scaleEffect(isPulsing ? 1.08 : 1.0)
            .onAppear { updateAnimation() }
            .onChange(of: isActive) { _, _ in updateAnimation() }
            .onChange(of: speed) { _, _ in updateAnimation() }
            .onChange(of: reduceMotion) { _, _ in updateAnimation() }
    }

    private func updateAnimation() {
        guard isActive, !reduceMotion else {
            isPulsing = false
            return
        }
        withAnimation(.easeInOut(duration: speed).repeatForever(autoreverses: true)) {
            isPulsing = true
        }
    }
}

struct ActionIconButton: View {
    enum Style {
        case neutral
        case success
        case warning
    }

    let symbol: String
    let helpKey: String
    let keyboardShortcut: KeyEquivalent?
    let style: Style
    let action: @Sendable () -> Void

    @State private var isHovered = false

    init(
        symbol: String,
        helpKey: String,
        keyboardShortcut: KeyEquivalent? = nil,
        style: Style = .neutral,
        action: @escaping @Sendable () -> Void
    ) {
        self.symbol = symbol
        self.helpKey = helpKey
        self.keyboardShortcut = keyboardShortcut
        self.style = style
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppDesignSystem.Colors.overlayForeground)
                .frame(width: 28, height: 28)
                .background(controlBackground)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .help(helpKey.localized)
        .onHover { hovering in
            isHovered = hovering
        }
        .modifier(KeyboardShortcutModifier(key: keyboardShortcut))
    }

    private var controlBackground: some ShapeStyle {
        switch style {
        case .neutral:
            if isHovered {
                return AnyShapeStyle(Color.white.opacity(0.14))
            }
            return AnyShapeStyle(Color.clear)
        case .success:
            if isHovered {
                return AnyShapeStyle(AppDesignSystem.Colors.success.opacity(0.85))
            }
            return AnyShapeStyle(AppDesignSystem.Colors.success.opacity(0.76))
        case .warning:
            if isHovered {
                return AnyShapeStyle(AppDesignSystem.Colors.error.opacity(0.82))
            }
            return AnyShapeStyle(AppDesignSystem.Colors.error.opacity(0.68))
        }
    }
}

struct KeyboardShortcutModifier: ViewModifier {
    let key: KeyEquivalent?

    func body(content: Content) -> some View {
        if let key {
            content.keyboardShortcut(key, modifiers: [])
        } else {
            content
        }
    }
}

struct RecordingIndicatorPostProcessingWarningDescriptor: Equatable {
    let issue: EnhancementsInferenceReadinessIssue
    let mode: IntelligenceKernelMode

    var settingsSection: String {
        SettingsSection.enhancements.rawValue
    }

    var localizedMessage: String {
        messageKey.localized(with: modeDisplayName)
    }

    var messageKey: String {
        switch issue {
        case .missingModel:
            "recording_indicator.post_processing_warning.missing_model"
        case .missingAPIKey:
            "recording_indicator.post_processing_warning.missing_api_key"
        case .invalidBaseURL:
            "recording_indicator.post_processing_warning.invalid_base_url"
        }
    }

    private var modeDisplayName: String {
        switch mode {
        case .meeting:
            "recording_indicator.post_processing_warning.mode.meeting".localized
        case .dictation:
            "recording_indicator.post_processing_warning.mode.dictation".localized
        case .assistant:
            "recording_indicator.post_processing_warning.mode.assistant".localized
        }
    }

    func openSettings(using openSection: (String) -> Void) {
        openSection(settingsSection)
    }
}

enum FloatingRecordingIndicatorViewUtilities {
    enum MainContentMode: Equatable {
        case waveform
        case processingStatus
    }

    static let actionButtonSize: CGFloat = 28
    static let dividerWidth: CGFloat = 1

    static func mainContentMode(for renderState: RecordingIndicatorRenderState) -> MainContentMode {
        renderState.mode == .processing ? .processingStatus : .waveform
    }

    static func controlHeight(for size: FloatingRecordingIndicatorView.IndicatorSize) -> CGFloat {
        switch size {
        case .classic:
            AppDesignSystem.Layout.recordingIndicatorClassicHeight
        case .mini:
            AppDesignSystem.Layout.recordingIndicatorMiniHeight
        }
    }

    static func contentSpacing(for size: FloatingRecordingIndicatorView.IndicatorSize) -> CGFloat {
        switch size {
        case .classic:
            AppDesignSystem.Layout.recordingIndicatorClassicInnerSpacing
        case .mini:
            AppDesignSystem.Layout.recordingIndicatorMiniInnerSpacing
        }
    }

    static func controlSpacing(for size: FloatingRecordingIndicatorView.IndicatorSize) -> CGFloat {
        contentSpacing(for: size)
    }

    static func promptSize(for size: FloatingRecordingIndicatorView.IndicatorSize) -> CGFloat {
        switch size {
        case .classic:
            AppDesignSystem.Layout.recordingIndicatorClassicPromptSize
        case .mini:
            AppDesignSystem.Layout.recordingIndicatorMiniPromptSize
        }
    }

    static func waveformHeight(for size: FloatingRecordingIndicatorView.IndicatorSize) -> CGFloat {
        switch size {
        case .classic:
            AppDesignSystem.Layout.recordingIndicatorClassicWaveHeight
        case .mini:
            AppDesignSystem.Layout.recordingIndicatorMiniWaveHeight
        }
    }

    static func waveCount(for size: FloatingRecordingIndicatorView.IndicatorSize) -> Int {
        switch size {
        case .classic:
            AppDesignSystem.Layout.recordingIndicatorClassicWaveCount
        case .mini:
            AppDesignSystem.Layout.recordingIndicatorMiniWaveCount
        }
    }

    static func formatRecordingDuration(startTime: Date?, at date: Date) -> String {
        guard let startTime else { return "00:00" }

        let duration = max(0, date.timeIntervalSince(startTime))
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = duration >= 3_600 ? [.hour, .minute, .second] : [.minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration) ?? "00:00"
    }

    static func waveformWidth(for size: FloatingRecordingIndicatorView.IndicatorSize) -> CGFloat {
        let count = CGFloat(waveCount(for: size))
        guard count > 0 else { return 0 }

        let totalBarWidth = count * AppDesignSystem.Layout.recordingIndicatorWaveformBarWidth
        let totalSpacing = max(0, count - 1) * AppDesignSystem.Layout.recordingIndicatorWaveformBarSpacing
        return totalBarWidth + totalSpacing
    }

    static func timerReservedWidth(for size: FloatingRecordingIndicatorView.IndicatorSize) -> CGFloat {
        switch size {
        case .classic:
            56
        case .mini:
            48
        }
    }

    static func processingProgressReservedWidth(for size: FloatingRecordingIndicatorView.IndicatorSize) -> CGFloat {
        switch size {
        case .classic:
            176
        case .mini:
            136
        }
    }

    static func horizontalPadding(for size: FloatingRecordingIndicatorView.IndicatorSize, expanded: Bool) -> CGFloat {
        if expanded {
            return AppDesignSystem.Layout.recordingIndicatorSidePadding
        }

        switch size {
        case .classic, .mini:
            return max(AppDesignSystem.Layout.recordingIndicatorSidePadding, 16)
        }
    }

    static func clusterWidth(
        for size: FloatingRecordingIndicatorView.IndicatorSize,
        renderState: RecordingIndicatorRenderState
    ) -> CGFloat {
        var width = AppDesignSystem.Layout.recordingIndicatorDotSize + contentSpacing(for: size)

        switch mainContentMode(for: renderState) {
        case .waveform:
            width += waveformWidth(for: size)
        case .processingStatus:
            width += processingProgressReservedWidth(for: size)
        }

        return width
    }

    static func buttonGroupWidth(for size: FloatingRecordingIndicatorView.IndicatorSize) -> CGFloat {
        actionButtonSize + controlSpacing(for: size) + dividerWidth
    }

    static func mainPillWidth(
        for size: FloatingRecordingIndicatorView.IndicatorSize,
        renderState: RecordingIndicatorRenderState,
        layout: RecordingIndicatorOverlayLayout,
        expanded: Bool
    ) -> CGFloat {
        var elementWidths: [CGFloat] = [
            clusterWidth(for: size, renderState: renderState),
        ]

        if renderState.kind == .meeting, renderState.mode == .recording {
            elementWidths.append(actionButtonSize)
            elementWidths.append(dividerWidth)
            elementWidths.append(actionButtonSize)

            if layout.showsMeetingTimer {
                elementWidths.append(dividerWidth)
                elementWidths.append(timerReservedWidth(for: size))
            }
        }

        if expanded, renderState.mode == .recording {
            elementWidths.insert(buttonGroupWidth(for: size), at: 0)
            elementWidths.append(buttonGroupWidth(for: size))
        }

        let spacingCount = max(0, elementWidths.count - 1)
        return (horizontalPadding(for: size, expanded: expanded) * 2)
            + elementWidths.reduce(0, +)
            + (CGFloat(spacingCount) * contentSpacing(for: size))
    }

    static func promptIconImage(
        symbolName: String,
        size: FloatingRecordingIndicatorView.IndicatorSize
    ) -> NSImage {
        let fallbackName = "doc.text"
        let symbolConfig = NSImage.SymbolConfiguration(pointSize: promptIconSize(for: size), weight: .medium)
            .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))

        let rawImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
            ?? NSImage(systemSymbolName: fallbackName, accessibilityDescription: nil)
            ?? NSImage()
        let configured = rawImage.withSymbolConfiguration(symbolConfig) ?? rawImage
        configured.isTemplate = false
        return configured
    }

    static func languageFlagImage(
        _ emoji: String,
        size: FloatingRecordingIndicatorView.IndicatorSize
    ) -> NSImage {
        emojiImage(emoji, pointSize: languageFlagPointSize(for: size))
    }

    private static func promptIconSize(for size: FloatingRecordingIndicatorView.IndicatorSize) -> CGFloat {
        switch size {
        case .classic:
            14
        case .mini:
            14
        }
    }

    private static func languageFlagPointSize(for size: FloatingRecordingIndicatorView.IndicatorSize) -> CGFloat {
        switch size {
        case .classic:
            18
        case .mini:
            13
        }
    }

    private static func emojiImage(_ emoji: String, pointSize: CGFloat) -> NSImage {
        let imageSize = NSSize(width: 24, height: 24)
        let image = NSImage(size: imageSize)
        image.lockFocus()

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: pointSize),
            .paragraphStyle: paragraphStyle,
        ]

        let attributed = NSAttributedString(string: emoji, attributes: attributes)
        let drawRect = NSRect(
            x: 0,
            y: (imageSize.height - pointSize) / 2,
            width: imageSize.width * 1.06,
            height: pointSize * 1.06
        )
        attributed.draw(in: drawRect)

        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}

#Preview("Action Icon Button", traits: .sizeThatFitsLayout) {
    ActionIconButton(
        symbol: "arrow.up",
        helpKey: "recording_indicator.stop.help",
        keyboardShortcut: nil,
        style: .neutral
    ) {
        // Preview only
    }
    .padding()
    .background(AppDesignSystem.Colors.neutral.opacity(0.8))
}
