import AppKit
import Foundation
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

/// Floating indicator view that shows audio waveforms during recording or processing.
public struct FloatingRecordingIndicatorView: View {
    @ObservedObject var audioMonitor: AudioLevelMonitor
    @ObservedObject private var recordingManager: RecordingManager
    @ObservedObject private var settingsStore: AppSettingsStore
    private let navigationService = NavigationService.shared
    let style: RecordingIndicatorStyle
    let mode: FloatingRecordingIndicatorMode
    let isAnimationActive: Bool
    private let previewForceDictationRecording: Bool
    private let previewLanguageOverride: DictationOutputLanguage?
    let onStop: @Sendable () -> Void
    let onCancel: @Sendable () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false
    @State private var hoverCollapseTask: Task<Void, Never>?
    @State private var isMainRegionHovered = false
    @State private var isPromptRegionHovered = false
    @State private var isPromptSessionArmed = false
    @State private var isSilenceWarningDialogPresented = false

    // Removed IndicatorMetrics in favor of MeetingAssistantDesignSystem.Layout

    public init(
        audioMonitor: AudioLevelMonitor,
        style: RecordingIndicatorStyle,
        mode: FloatingRecordingIndicatorMode,
        isAnimationActive: Bool = true,
        previewForceDictationRecording: Bool = false,
        previewLanguageOverride: DictationOutputLanguage? = nil,
        recordingManager: RecordingManager = .shared,
        settingsStore: AppSettingsStore = .shared,
        onStop: @escaping @Sendable () -> Void,
        onCancel: @escaping @Sendable () -> Void
    ) {
        self.audioMonitor = audioMonitor
        self.style = style
        self.mode = mode
        self.isAnimationActive = isAnimationActive
        self.previewForceDictationRecording = previewForceDictationRecording
        self.previewLanguageOverride = previewLanguageOverride
        self.recordingManager = recordingManager
        self.settingsStore = settingsStore
        self.onStop = onStop
        self.onCancel = onCancel
    }

    public var body: some View {
        switch mode {
        case .error:
            errorView
        case .starting, .recording, .processing:
            switch style {
            case .classic:
                indicatorPill(size: .classic)
            case .mini:
                indicatorPill(size: .mini)
            case .none:
                EmptyView()
            }
        }
    }

    // MARK: - Indicator Pill

    private enum IndicatorSize {
        case classic
        case mini
    }

    private func indicatorPill(size: IndicatorSize) -> some View {
        ZStack(alignment: .top) {
            HStack(spacing: MeetingAssistantDesignSystem.Layout.recordingIndicatorPromptGap) {
                mainPill(size: size)

                if isRecordingMode {
                    promptSelectionPill(size: size)

                    if isDictationRecording {
                        languageSelectionPill(size: size)
                    }
                }
            }
            .onDisappear {
                hoverCollapseTask?.cancel()
                hoverCollapseTask = nil
                isMainRegionHovered = false
                isPromptRegionHovered = false
                isPromptSessionArmed = false
            }

            VStack(spacing: MeetingAssistantDesignSystem.Layout.spacing4) {
                if let warningDescriptor = postProcessingWarningDescriptor {
                    postProcessingReadinessWarningOverlay(warningDescriptor)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                if isRecordingMode, audioMonitor.isSilenceWarningVisible {
                    silenceWarningOverlay
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .padding(.top, 2)
        }
    }

    // MARK: - Shared Components

    private var leadingControls: some View {
        HStack(spacing: controlSpacing(for: currentIndicatorSize)) {
            ActionIconButton(
                symbol: "checkmark",
                helpKey: "recording_indicator.stop.help",
                keyboardShortcut: nil
            ) {
                onStop()
            }

            divider
        }
    }

    /// Warning overlay shown when microphone input appears silent.
    private var silenceWarningOverlay: some View {
        Text("recording_indicator.silence_warning".localized)
            .font(.caption.bold())
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .lineLimit(nil)
            .fixedSize(horizontal: true, vertical: true)
            .padding(.horizontal, MeetingAssistantDesignSystem.Layout.spacing10)
            .padding(.vertical, MeetingAssistantDesignSystem.Layout.spacing4)
            .background(MeetingAssistantDesignSystem.Colors.recordingOverlayBackground)
            .clipShape(Capsule())
            .shadow(
                color: .black.opacity(0.2),
                radius: MeetingAssistantDesignSystem.Layout.shadowRadiusSmall,
                x: MeetingAssistantDesignSystem.Layout.shadowX,
                y: MeetingAssistantDesignSystem.Layout.shadowYSmall
            )
            .overlay(
                Capsule()
                    .strokeBorder(MeetingAssistantDesignSystem.Colors.recordingIndicatorStroke, lineWidth: 1)
            )
            .contentShape(Capsule())
            .onTapGesture {
                isSilenceWarningDialogPresented = true
            }
            .confirmationDialog(
                "recording_indicator.silence_warning.confirmation.title".localized,
                isPresented: $isSilenceWarningDialogPresented
            ) {
                Button("recording_indicator.silence_warning.action.continue".localized) {
                    audioMonitor.dismissSilenceWarning()
                }
                Button("recording_indicator.silence_warning.action.stop".localized) {
                    onStop()
                    audioMonitor.dismissSilenceWarning()
                }
                Button("recording_indicator.silence_warning.action.discard".localized, role: .destructive) {
                    onCancel()
                    audioMonitor.dismissSilenceWarning()
                }
            }
    }

    private func postProcessingReadinessWarningOverlay(
        _ descriptor: RecordingIndicatorPostProcessingWarningDescriptor
    ) -> some View {
        HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)

            Text(descriptor.localizedMessage)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Button("recording_indicator.post_processing_warning.open_settings".localized) {
                descriptor.openSettings { section in
                    navigationService.openSettings(section: section)
                }
            }
            .buttonStyle(.plain)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .underline()
        }
        .padding(.horizontal, MeetingAssistantDesignSystem.Layout.spacing10)
        .padding(.vertical, MeetingAssistantDesignSystem.Layout.spacing6)
        .background(MeetingAssistantDesignSystem.Colors.warning.opacity(0.95))
        .clipShape(Capsule())
        .shadow(
            color: .black.opacity(0.2),
            radius: MeetingAssistantDesignSystem.Layout.shadowRadiusSmall,
            x: MeetingAssistantDesignSystem.Layout.shadowX,
            y: MeetingAssistantDesignSystem.Layout.shadowYSmall
        )
        .overlay(
            Capsule()
                .strokeBorder(MeetingAssistantDesignSystem.Colors.recordingIndicatorStroke, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityHint("recording_indicator.post_processing_warning.open_settings".localized)
    }

    private var divider: some View {
        Rectangle()
            .fill(MeetingAssistantDesignSystem.Colors.overlayDivider)
            .frame(width: 1, height: 20)
    }

    private var trailingControl: some View {
        HStack(spacing: controlSpacing(for: currentIndicatorSize)) {
            divider

            ActionIconButton(
                symbol: "trash",
                helpKey: "recording_indicator.cancel.help",
                keyboardShortcut: .escape
            ) {
                onCancel()
            }
        }
    }

    /// Dot indicating recording or processing (Figma uses 12x12).
    private func statusDot(for size: IndicatorSize) -> some View {
        Circle()
            .fill(isRecordingMode ? MeetingAssistantDesignSystem.Colors.recording : MeetingAssistantDesignSystem.Colors.accent)
            .frame(width: MeetingAssistantDesignSystem.Layout.recordingIndicatorDotSize, height: MeetingAssistantDesignSystem.Layout.recordingIndicatorDotSize)
            .modifier(
                PulsingModifier(
                    isActive: isAnimationActive && (isRecordingMode || isStartingMode),
                    speed: isRecordingMode ? 0.9 : 1.2
                )
            )
    }

    private func controlHeight(for size: IndicatorSize) -> CGFloat {
        switch size {
        case .classic:
            MeetingAssistantDesignSystem.Layout.recordingIndicatorClassicHeight
        case .mini:
            MeetingAssistantDesignSystem.Layout.recordingIndicatorMiniHeight
        }
    }

    private var isRecordingMode: Bool {
        if case .recording = mode {
            return true
        }
        return false
    }

    private var isStartingMode: Bool {
        if case .starting = mode {
            return true
        }
        return false
    }

    private var isProcessingMode: Bool {
        if case .processing = mode {
            return true
        }
        return false
    }

    private var postProcessingWarningDescriptor: RecordingIndicatorPostProcessingWarningDescriptor? {
        guard isRecordingMode || isProcessingMode else { return nil }
        guard settingsStore.postProcessingEnabled else { return nil }
        guard let issue = recordingManager.postProcessingReadinessWarningIssue,
              let warningMode = recordingManager.postProcessingReadinessWarningMode
        else {
            return nil
        }

        return RecordingIndicatorPostProcessingWarningDescriptor(issue: issue, mode: warningMode)
    }

    private var visualizerModeForIndicator: AudioVisualizerMode {
        if case .recording = mode {
            return .recording
        }
        return .processing
    }

    private var errorView: some View {
        let message = errorMessage ?? "Error"

        return HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.white)
                .font(.caption.weight(.bold))

            Text(message)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, MeetingAssistantDesignSystem.Layout.spacing16)
        .padding(.vertical, MeetingAssistantDesignSystem.Layout.spacing8)
        .background(MeetingAssistantDesignSystem.Colors.error.opacity(0.95))
        .clipShape(Capsule())
        .shadow(
            color: .black.opacity(0.2),
            radius: MeetingAssistantDesignSystem.Layout.shadowRadiusSmall,
            x: MeetingAssistantDesignSystem.Layout.shadowX,
            y: MeetingAssistantDesignSystem.Layout.shadowYSmall
        )
    }

    private var errorMessage: String? {
        guard case let .error(message) = mode else {
            return nil
        }
        return message
    }

    private var isDictationRecording: Bool {
        if previewForceDictationRecording { return true }
        guard recordingManager.isRecording else { return false }
        // Assistant recordings use the shared AudioRecorder directly and do not create a Meeting.
        // In that case we should render the dictation-style indicator (without duration).
        if recordingManager.currentMeeting == nil { return true }
        return recordingManager.recordingSource == .microphone
    }

    private var isMeetingRecording: Bool {
        recordingManager.isRecording && !isDictationRecording
    }

    private func recordingCluster(size: IndicatorSize) -> some View {
        HStack(spacing: contentSpacing(for: size)) {
            statusDot(for: size)

            AudioVisualizer(
                audioMeter: audioMonitor.audioMeter,
                mode: visualizerModeForIndicator,
                isAnimationActive: isAnimationActive,
                barCount: waveCount(for: size),
                maxHeight: waveformHeight(for: size),
                barWidth: MeetingAssistantDesignSystem.Layout.recordingIndicatorWaveformBarWidth,
                barSpacing: MeetingAssistantDesignSystem.Layout.recordingIndicatorWaveformBarSpacing,
                minHeight: MeetingAssistantDesignSystem.Layout.recordingIndicatorWaveformMinHeight
            )

            if isRecordingMode, isMeetingRecording {
                Group {
                    if isAnimationActive {
                        TimelineView(.periodic(from: .now, by: 1.0)) { context in
                            Text(formatRecordingDuration(at: context.date))
                                .font(.system(size: 13, weight: .medium))
                                .monospacedDigit()
                                .contentTransition(.numericText())
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .layoutPriority(1)
                                .foregroundStyle(MeetingAssistantDesignSystem.Colors.overlayForegroundMuted)
                        }
                    } else {
                        Text(formatRecordingDuration(at: Date()))
                            .font(.system(size: 13, weight: .medium))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .layoutPriority(1)
                            .foregroundStyle(MeetingAssistantDesignSystem.Colors.overlayForegroundMuted)
                    }
                }
                .accessibilityLabel("recording_indicator.duration".localized)
            }
        }
    }

    private func promptPickerControl(size: IndicatorSize) -> some View {
        Menu {
            Button {
                applyPostProcessingSelection(nil)
            } label: {
                Label(
                    "recording_indicator.prompt.none".localized,
                    systemImage: "nosign"
                )
            }

            Divider()

            ForEach(promptPickerPrompts) { prompt in
                Button {
                    applyPostProcessingSelection(prompt.id)
                } label: {
                    Label(prompt.title, systemImage: prompt.icon)
                }
            }
        } label: {
            Image(nsImage: promptIconImage(for: size))
                .renderingMode(.original)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .help("recording_indicator.prompt.help".localized)
        .highPriorityGesture(TapGesture())
    }

    private func languagePickerControl(size: IndicatorSize) -> some View {
        Menu {
            ForEach(DictationOutputLanguage.allCases, id: \.self) { language in
                Button {
                    recordingManager.setDictationSessionOutputLanguageOverride(language)
                } label: {
                    Text(language.displayName)
                }
            }
        } label: {
            Image(nsImage: languageFlagImage(for: size))
                .renderingMode(.original)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
                .accessibilityLabel(currentDictationOutputLanguage.localizedName)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .help("settings.rules_per_app.language.title".localized)
        .highPriorityGesture(TapGesture())
    }

    private var promptPickerPrompts: [PostProcessingPrompt] {
        isDictationRecording ? settingsStore.dictationAvailablePrompts : settingsStore.meetingAvailablePrompts
    }

    private var currentPromptIconName: String {
        if isDictationRecording {
            if settingsStore.isDictationPostProcessingDisabled {
                return "nosign"
            }
            return (settingsStore.selectedDictationPrompt ?? .cleanTranscription).icon
        }

        if settingsStore.isMeetingPostProcessingDisabled {
            return "nosign"
        }

        return settingsStore.selectedPrompt?.icon ?? "doc.text"
    }

    private func applyPostProcessingSelection(_ promptId: UUID?) {
        let selectionId = promptId ?? AppSettingsStore.noPostProcessingPromptId

        if isDictationRecording {
            settingsStore.dictationSelectedPromptId = selectionId
            return
        }

        // Meetings
        settingsStore.meetingTypeAutoDetectEnabled = false
        if recordingManager.currentMeeting?.type == .autodetect {
            recordingManager.overrideCurrentMeetingType(.general)
        }

        settingsStore.selectedPromptId = selectionId
    }

    private func formatRecordingDuration(at date: Date) -> String {
        guard let startTime = recordingManager.currentMeeting?.startTime else { return "00:00" }

        let duration = max(0, date.timeIntervalSince(startTime))

        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = duration >= 3_600 ? [.hour, .minute, .second] : [.minute, .second]
        formatter.zeroFormattingBehavior = .pad

        return formatter.string(from: duration) ?? "00:00"
    }

    private var currentIndicatorSize: IndicatorSize {
        switch style {
        case .classic:
            .classic
        case .mini:
            .mini
        case .none:
            .classic
        }
    }

    private func mainPill(size: IndicatorSize) -> some View {
        HStack(spacing: contentSpacing(for: size)) {
            if isRecordingMode, isHovering {
                leadingControls
            }

            recordingCluster(size: size)

            if isRecordingMode, isHovering {
                trailingControl
            }
        }
        .padding(.horizontal, MeetingAssistantDesignSystem.Layout.recordingIndicatorSidePadding)
        .frame(height: controlHeight(for: size))
        .background(.ultraThinMaterial)
        .background(MeetingAssistantDesignSystem.Colors.recordingIndicatorMaterialTint)
        .overlay(
            Capsule()
                .strokeBorder(MeetingAssistantDesignSystem.Colors.recordingIndicatorStroke, lineWidth: 1.2)
        )
        .clipShape(Capsule())
        .shadow(
            color: .black.opacity(0.15),
            radius: MeetingAssistantDesignSystem.Layout.recordingIndicatorMainShadowRadius,
            x: MeetingAssistantDesignSystem.Layout.shadowX,
            y: MeetingAssistantDesignSystem.Layout.recordingIndicatorMainShadowY
        )
        .contentShape(Capsule())
        .onHover { hovering in
            handleMainRegionHover(hovering)
        }
    }

    private func promptSelectionPill(size: IndicatorSize) -> some View {
        promptPickerControl(size: size)
            .frame(width: promptSize(for: size), height: controlHeight(for: size))
            .background(.ultraThinMaterial)
            .background(MeetingAssistantDesignSystem.Colors.recordingIndicatorAuxiliaryBackground)
            .overlay(
                Capsule()
                    .strokeBorder(MeetingAssistantDesignSystem.Colors.recordingIndicatorStroke, lineWidth: 1)
            )
            .clipShape(Capsule())
            .shadow(
                color: .black.opacity(0.12),
                radius: MeetingAssistantDesignSystem.Layout.recordingIndicatorAuxShadowRadius,
                x: MeetingAssistantDesignSystem.Layout.shadowX,
                y: MeetingAssistantDesignSystem.Layout.recordingIndicatorAuxShadowY
            )
            .onHover { hovering in
                handlePromptRegionHover(hovering)
            }
    }

    private func languageSelectionPill(size: IndicatorSize) -> some View {
        languagePickerControl(size: size)
            .frame(width: promptSize(for: size), height: controlHeight(for: size))
            .background(.ultraThinMaterial)
            .background(MeetingAssistantDesignSystem.Colors.recordingIndicatorAuxiliaryBackground)
            .overlay(
                Capsule()
                    .strokeBorder(MeetingAssistantDesignSystem.Colors.recordingIndicatorStroke, lineWidth: 1)
            )
            .clipShape(Capsule())
            .shadow(
                color: .black.opacity(0.12),
                radius: MeetingAssistantDesignSystem.Layout.recordingIndicatorAuxShadowRadius,
                x: MeetingAssistantDesignSystem.Layout.shadowX,
                y: MeetingAssistantDesignSystem.Layout.recordingIndicatorAuxShadowY
            )
            .onHover { hovering in
                handlePromptRegionHover(hovering)
            }
    }

    private func handleMainRegionHover(_ hovering: Bool) {
        guard isRecordingMode else { return }

        isMainRegionHovered = hovering
        if hovering {
            isPromptSessionArmed = true
            hoverCollapseTask?.cancel()
            if reduceMotion {
                isHovering = true
            } else {
                withAnimation(
                    .spring(
                        response: MeetingAssistantDesignSystem.Layout.recordingIndicatorHoverEnterResponse,
                        dampingFraction: MeetingAssistantDesignSystem.Layout.recordingIndicatorHoverEnterDamping
                    )
                ) {
                    isHovering = true
                }
            }
            return
        }

        collapseAfterDelayIfNeeded()
    }

    private func handlePromptRegionHover(_ hovering: Bool) {
        guard isRecordingMode else { return }

        isPromptRegionHovered = hovering
        if hovering, isPromptSessionArmed {
            hoverCollapseTask?.cancel()
            return
        }

        collapseAfterDelayIfNeeded()
    }

    private func collapseAfterDelayIfNeeded() {
        guard isRecordingMode else { return }
        guard !isMainRegionHovered else { return }
        if isPromptRegionHovered, isPromptSessionArmed { return }
        guard isHovering else { return }

        hoverCollapseTask?.cancel()
        hoverCollapseTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 110_000_000)
            guard !Task.isCancelled else { return }
            guard !isMainRegionHovered else { return }
            if isPromptRegionHovered, isPromptSessionArmed { return }

            if reduceMotion {
                isHovering = false
            } else {
                withAnimation(
                    .spring(
                        response: MeetingAssistantDesignSystem.Layout.recordingIndicatorHoverExitResponse,
                        dampingFraction: MeetingAssistantDesignSystem.Layout.recordingIndicatorHoverExitDamping
                    )
                ) {
                    isHovering = false
                }
            }
            isPromptSessionArmed = false
        }
    }

    private func contentSpacing(for size: IndicatorSize) -> CGFloat {
        switch size {
        case .classic:
            MeetingAssistantDesignSystem.Layout.recordingIndicatorClassicInnerSpacing
        case .mini:
            MeetingAssistantDesignSystem.Layout.recordingIndicatorMiniInnerSpacing
        }
    }

    private func controlSpacing(for size: IndicatorSize) -> CGFloat {
        switch size {
        case .classic:
            MeetingAssistantDesignSystem.Layout.recordingIndicatorClassicInnerSpacing
        case .mini:
            MeetingAssistantDesignSystem.Layout.recordingIndicatorMiniInnerSpacing
        }
    }

    private func promptSize(for size: IndicatorSize) -> CGFloat {
        switch size {
        case .classic:
            MeetingAssistantDesignSystem.Layout.recordingIndicatorClassicPromptSize
        case .mini:
            MeetingAssistantDesignSystem.Layout.recordingIndicatorMiniPromptSize
        }
    }

    private func waveformHeight(for size: IndicatorSize) -> CGFloat {
        switch size {
        case .classic:
            MeetingAssistantDesignSystem.Layout.recordingIndicatorClassicWaveHeight
        case .mini:
            MeetingAssistantDesignSystem.Layout.recordingIndicatorMiniWaveHeight
        }
    }

    private func waveCount(for size: IndicatorSize) -> Int {
        switch size {
        case .classic:
            MeetingAssistantDesignSystem.Layout.recordingIndicatorClassicWaveCount
        case .mini:
            MeetingAssistantDesignSystem.Layout.recordingIndicatorMiniWaveCount
        }
    }

    private func promptIconSize(for size: IndicatorSize) -> CGFloat {
        switch size {
        case .classic:
            15
        case .mini:
            13
        }
    }

    private func languageFlagPointSize(for size: IndicatorSize) -> CGFloat {
        switch size {
        case .classic:
            18
        case .mini:
            13
        }
    }

    private var currentDictationOutputLanguage: DictationOutputLanguage {
        if let previewLanguageOverride {
            return previewLanguageOverride
        }
        return recordingManager.effectiveDictationOutputLanguageForCurrentRecording
    }

    private func promptIconImage(for size: IndicatorSize) -> NSImage {
        let fallbackName = "doc.text"
        let symbolName = currentPromptIconName
        let pointSize = promptIconSize(for: size)
        let symbolConfig = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
            .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))

        let rawImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
            ?? NSImage(systemSymbolName: fallbackName, accessibilityDescription: nil)
            ?? NSImage()

        let configured = rawImage.withSymbolConfiguration(symbolConfig) ?? rawImage
        configured.isTemplate = false
        return configured
    }

    private func languageFlagImage(for size: IndicatorSize) -> NSImage {
        emojiImage(currentDictationOutputLanguage.flagEmoji, pointSize: languageFlagPointSize(for: size))
    }

    private func emojiImage(_ emoji: String, pointSize: CGFloat) -> NSImage {
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

// MARK: - Audio Visualizer (Native implementation based on VoiceInk)

enum AudioVisualizerMode: Sendable {
    case recording
    case processing
}

struct AudioVisualizer: View {
    let audioMeter: AudioMeter
    let mode: AudioVisualizerMode
    let isAnimationActive: Bool
    let barCount: Int
    let maxHeight: CGFloat
    let barWidth: CGFloat
    let barSpacing: CGFloat
    let minHeight: CGFloat
    let gateStart: Double = 0.35
    let gateWidth: Double = 0.2
    let inputGain: Double = 1.05
    let peakBlendRatio: Double = 0.6
    let compressionKnee: Double = 0.15

    private let sensitivityMultipliers: [Double]
    private let phaseOffsets: [Double]
    private let secondaryOffsets: [Double]
    private let amplitudeScales: [Double]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var barHeights: [CGFloat]

    init(
        audioMeter: AudioMeter,
        mode: AudioVisualizerMode,
        isAnimationActive: Bool = true,
        barCount: Int,
        maxHeight: CGFloat,
        barWidth: CGFloat = MeetingAssistantDesignSystem.Layout.spacing4,
        barSpacing: CGFloat = MeetingAssistantDesignSystem.Layout.spacing2,
        minHeight: CGFloat = MeetingAssistantDesignSystem.Layout.spacing8
    ) {
        self.audioMeter = audioMeter
        self.mode = mode
        self.isAnimationActive = isAnimationActive
        self.barCount = barCount
        self.maxHeight = maxHeight
        self.barWidth = barWidth
        self.barSpacing = barSpacing
        self.minHeight = minHeight

        sensitivityMultipliers = (0..<barCount).map { index in
            Self.deterministicValue(index: index, count: barCount, range: 0.72...1.18, seed: 0.37)
        }
        phaseOffsets = (0..<barCount).map { index in
            Self.deterministicValue(index: index, count: barCount, range: 0...(Double.pi * 2), seed: 0.61)
        }
        secondaryOffsets = (0..<barCount).map { index in
            Self.deterministicValue(index: index, count: barCount, range: 0...(Double.pi * 2), seed: 1.13)
        }
        amplitudeScales = (0..<barCount).map { index in
            Self.deterministicValue(index: index, count: barCount, range: 0.82...1.07, seed: 1.87)
        }

        _barHeights = State(initialValue: Array(repeating: minHeight, count: barCount))
    }

    var body: some View {
        Group {
            switch mode {
            case .recording:
                recordingBars
            case .processing:
                processingBars
            }
        }
    }

    private var recordingBars: some View {
        HStack(spacing: barSpacing) {
            ForEach(0..<barCount, id: \.self) { index in
                Capsule()
                    .fill(Color.white)
                    .frame(width: barWidth, height: barHeights[index])
            }
        }
        .frame(height: maxHeight, alignment: .center)
        .onChange(of: audioMeter) { _, newValue in
            updateBars(with: Float(effectiveLevel(from: newValue)))
        }
    }

    private var processingBars: some View {
        Group {
            if isAnimationActive && !reduceMotion {
                TimelineView(.animation) { timeline in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    HStack(spacing: barSpacing) {
                        ForEach(0..<barCount, id: \.self) { index in
                            Capsule()
                                .fill(Color.white)
                                .frame(width: barWidth, height: processingHeight(for: index, time: time))
                        }
                    }
                    .frame(height: maxHeight, alignment: .center)
                }
            } else {
                HStack(spacing: barSpacing) {
                    ForEach(0..<barCount, id: \.self) { _ in
                        Capsule()
                            .fill(Color.white)
                            .frame(width: barWidth, height: minHeight)
                    }
                }
                .frame(height: maxHeight, alignment: .center)
            }
        }
    }

    private func processingHeight(for index: Int, time: TimeInterval) -> CGFloat {
        let base = (sin(time * 2.4 + phaseOffsets[index]) + 1) / 2
        let modulation = (sin(time * 0.9 + secondaryOffsets[index]) + 1) / 2
        let blended = (0.35 + 0.65 * base) * (0.6 + 0.4 * modulation) * amplitudeScales[index]
        let clamped = min(1.0, max(0.0, blended))
        return minHeight + CGFloat(clamped) * (maxHeight - minHeight)
    }

    private func updateBars(with audioLevel: Float) {
        let boosted = min(1.0, max(0.0, Double(audioLevel) * inputGain))
        let rawLevel = max(0, min(1, boosted))
        let gatedLevel = smoothstep(edge0: gateStart, edge1: gateStart + gateWidth, value: rawLevel)
        let adjustedLevel = softKneeCompressedLevel(gatedLevel)

        let range = maxHeight - minHeight
        let center = barCount / 2

        var targetHeights: [CGFloat] = []

        for i in 0..<barCount {
            let distanceFromCenter = abs(i - center)
            let positionMultiplier = 1.0 - (Double(distanceFromCenter) / Double(center)) * 0.4

            // Apply deterministic per-bar sensitivity for stable visual identity across mounts.
            let sensitivityAdjustedLevel = adjustedLevel * positionMultiplier * sensitivityMultipliers[i]

            // Calculate target height directly
            let targetHeight = minHeight + CGFloat(sensitivityAdjustedLevel) * range
            targetHeights.append(targetHeight)
        }

        if isAnimationActive && !reduceMotion {
            let currentAverage = barHeights.reduce(0, +) / CGFloat(max(barHeights.count, 1))
            let targetAverage = targetHeights.reduce(0, +) / CGFloat(max(targetHeights.count, 1))
            let isRising = targetAverage >= currentAverage
            let duration = isRising ? 0.04 : 0.02
            withAnimation(.easeOut(duration: duration)) {
                barHeights = targetHeights
            }
            return
        }

        barHeights = targetHeights
    }

    private func effectiveLevel(from meter: AudioMeter) -> Double {
        max(meter.averagePower, meter.peakPower * peakBlendRatio)
    }

    private func smoothstep(edge0: Double, edge1: Double, value: Double) -> Double {
        let t = min(1.0, max(0.0, (value - edge0) / (edge1 - edge0)))
        return t * t * (3 - 2 * t)
    }

    private func softKneeCompressedLevel(_ level: Double) -> Double {
        let numerator = level * level
        return numerator / (numerator + compressionKnee)
    }

    private static func deterministicValue(index: Int, count: Int, range: ClosedRange<Double>, seed: Double) -> Double {
        guard count > 0 else { return range.lowerBound }
        let normalized = Double(index + 1) / Double(count + 1)
        let wave = (sin((normalized + seed) * .pi * 2) + 1) / 2
        return range.lowerBound + (range.upperBound - range.lowerBound) * wave
    }
}

// MARK: - Pulsing Animation Modifier

/// Modifier that adds a subtle pulsing animation.
private struct PulsingModifier: ViewModifier {
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

private struct ActionIconButton: View {
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

private struct KeyboardShortcutModifier: ViewModifier {
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

// MARK: - Preview

#Preview("Classic", traits: .sizeThatFitsLayout) {
    let monitor = AudioLevelMonitor()
    FloatingRecordingIndicatorView(
        audioMonitor: monitor,
        style: .classic,
        mode: .recording,
        previewForceDictationRecording: true,
        previewLanguageOverride: .spanish,
        onStop: {},
        onCancel: {}
    )
    .padding()
    .frame(width: 520, height: 120)
    .background(MeetingAssistantDesignSystem.Colors.neutral.opacity(0.8))
}

#Preview("Mini", traits: .sizeThatFitsLayout) {
    let monitor = AudioLevelMonitor()
    FloatingRecordingIndicatorView(
        audioMonitor: monitor,
        style: .mini,
        mode: .recording,
        previewForceDictationRecording: true,
        previewLanguageOverride: .english,
        onStop: {},
        onCancel: {}
    )
    .padding()
    .frame(width: 420, height: 100)
    .background(MeetingAssistantDesignSystem.Colors.neutral.opacity(0.8))
}
