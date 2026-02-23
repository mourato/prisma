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
    let symbol: String
    let helpKey: String
    let keyboardShortcut: KeyEquivalent?
    let action: @Sendable () -> Void

    @State private var isHovered = false
    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(MeetingAssistantDesignSystem.Colors.overlayForeground)
                .frame(width: 20, height: 20)
                .padding(4)
                .background(controlBackground)
                .clipShape(RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.smallCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .focusable(true)
        .focused($isFocused)
        .help(helpKey.localized)
        .onHover { hovering in
            isHovered = hovering
        }
        .modifier(KeyboardShortcutModifier(key: keyboardShortcut))
    }

    private var controlBackground: some ShapeStyle {
        if isFocused {
            return AnyShapeStyle(MeetingAssistantDesignSystem.Colors.accent.opacity(0.35))
        }
        if isHovered {
            return AnyShapeStyle(Color.white.opacity(0.14))
        }
        return AnyShapeStyle(Color.clear)
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
    static func controlHeight(for size: FloatingRecordingIndicatorView.IndicatorSize) -> CGFloat {
        switch size {
        case .classic:
            MeetingAssistantDesignSystem.Layout.recordingIndicatorClassicHeight
        case .mini:
            MeetingAssistantDesignSystem.Layout.recordingIndicatorMiniHeight
        }
    }

    static func contentSpacing(for size: FloatingRecordingIndicatorView.IndicatorSize) -> CGFloat {
        switch size {
        case .classic:
            MeetingAssistantDesignSystem.Layout.recordingIndicatorClassicInnerSpacing
        case .mini:
            MeetingAssistantDesignSystem.Layout.recordingIndicatorMiniInnerSpacing
        }
    }

    static func controlSpacing(for size: FloatingRecordingIndicatorView.IndicatorSize) -> CGFloat {
        contentSpacing(for: size)
    }

    static func promptSize(for size: FloatingRecordingIndicatorView.IndicatorSize) -> CGFloat {
        switch size {
        case .classic:
            MeetingAssistantDesignSystem.Layout.recordingIndicatorClassicPromptSize
        case .mini:
            MeetingAssistantDesignSystem.Layout.recordingIndicatorMiniPromptSize
        }
    }

    static func waveformHeight(for size: FloatingRecordingIndicatorView.IndicatorSize) -> CGFloat {
        switch size {
        case .classic:
            MeetingAssistantDesignSystem.Layout.recordingIndicatorClassicWaveHeight
        case .mini:
            MeetingAssistantDesignSystem.Layout.recordingIndicatorMiniWaveHeight
        }
    }

    static func waveCount(for size: FloatingRecordingIndicatorView.IndicatorSize) -> Int {
        switch size {
        case .classic:
            MeetingAssistantDesignSystem.Layout.recordingIndicatorClassicWaveCount
        case .mini:
            MeetingAssistantDesignSystem.Layout.recordingIndicatorMiniWaveCount
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

    static func promptIconImage(
        symbolName: String,
        size: FloatingRecordingIndicatorView.IndicatorSize
    ) -> NSImage {
        let fallbackName = "doc.text"
        let symbolConfig = NSImage.SymbolConfiguration(pointSize: promptIconSize(for: size), weight: .regular)
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
            15
        case .mini:
            13
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
        let imageSize = NSSize(width: 20, height: 20)
        let image = NSImage(size: imageSize)
        image.lockFocus()

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: pointSize),
            .paragraphStyle: paragraphStyle,
        ]

        let attributed = NSAttributedString(string: emoji, attributes: attributes)
        let measuredRect = attributed.boundingRect(
            with: NSSize(width: imageSize.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        let drawRect = NSRect(
            x: 0,
            y: floor((imageSize.height - measuredRect.height) / 2),
            width: imageSize.width,
            height: measuredRect.height
        )
        attributed.draw(in: drawRect)

        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}

#Preview("Action Icon Button", traits: .sizeThatFitsLayout) {
    ActionIconButton(
        symbol: "checkmark",
        helpKey: "recording_indicator.stop.help",
        keyboardShortcut: nil
    ) {
        // Preview only
    }
    .padding()
    .background(MeetingAssistantDesignSystem.Colors.neutral.opacity(0.8))
}
