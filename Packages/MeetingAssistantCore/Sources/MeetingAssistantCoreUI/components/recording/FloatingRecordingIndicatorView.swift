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

    // Removed IndicatorMetrics in favor of AppDesignSystem.Layout

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

    enum IndicatorSize {
        case classic
        case mini
    }

    private func indicatorPill(size: IndicatorSize) -> some View {
        HStack(spacing: AppDesignSystem.Layout.recordingIndicatorPromptGap) {
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
        // Keep warning overlays out of layout sizing to prevent NSPanel constraint loops
        // when warnings appear/disappear while the panel uses a fixed content size.
        .overlay(alignment: .top) {
            VStack(spacing: 4) {
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
        .shadow(
            color: .black.opacity(0.15),
            radius: AppDesignSystem.Layout.recordingIndicatorMainShadowRadius,
            x: AppDesignSystem.Layout.shadowX,
            y: AppDesignSystem.Layout.recordingIndicatorMainShadowY
        )
    }

    // MARK: - Shared Components

    private var leadingControls: some View {
        HStack(spacing: controlSpacing(for: currentIndicatorSize)) {
            ActionIconButton(
                symbol: "trash",
                helpKey: "recording_indicator.cancel.help",
                keyboardShortcut: .escape
            ) {
                onCancel()
            }

            divider
        }
    }

    /// Warning overlay shown when microphone input appears silent.
    private var silenceWarningOverlay: some View {
        RecordingSilenceWarningOverlay(
            isDialogPresented: $isSilenceWarningDialogPresented,
            onContinue: { audioMonitor.dismissSilenceWarning() },
            onStop: {
                onStop()
                audioMonitor.dismissSilenceWarning()
            },
            onDiscard: {
                onCancel()
                audioMonitor.dismissSilenceWarning()
            }
        )
    }

    private func postProcessingReadinessWarningOverlay(
        _ descriptor: RecordingIndicatorPostProcessingWarningDescriptor
    ) -> some View {
        RecordingPostProcessingWarningOverlay(descriptor: descriptor) { section in
            navigationService.openSettings(section: section)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(AppDesignSystem.Colors.overlayDivider)
            .frame(width: 1, height: 20)
    }

    private var trailingControl: some View {
        HStack(spacing: controlSpacing(for: currentIndicatorSize)) {
            divider

            ActionIconButton(
                symbol: "arrow.up",
                helpKey: "recording_indicator.stop.help",
                keyboardShortcut: nil,
                style: .success
            ) {
                onStop()
            }
        }
    }

    /// Dot indicating recording or processing (Figma uses 12x12).
    private func statusDot(for size: IndicatorSize) -> some View {
        Circle()
            .fill(isRecordingMode ? AppDesignSystem.Colors.recording : AppDesignSystem.Colors.accent)
            .frame(width: AppDesignSystem.Layout.recordingIndicatorDotSize, height: AppDesignSystem.Layout.recordingIndicatorDotSize)
            .modifier(
                PulsingModifier(
                    isActive: isAnimationActive && (isRecordingMode || isStartingMode),
                    speed: isRecordingMode ? 0.9 : 1.2
                )
            )
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

        return HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.white)
                .font(.caption.weight(.bold))

            Text(message)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(AppDesignSystem.Colors.error.opacity(0.95))
        .clipShape(Capsule())
        .shadow(
            color: .black.opacity(0.2),
            radius: AppDesignSystem.Layout.shadowRadiusSmall,
            x: AppDesignSystem.Layout.shadowX,
            y: AppDesignSystem.Layout.shadowYSmall
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
        HStack(spacing: FloatingRecordingIndicatorViewUtilities.contentSpacing(for: size)) {
            statusDot(for: size)

            AudioVisualizer(
                audioMeter: audioMonitor.audioMeter,
                mode: visualizerModeForIndicator,
                isAnimationActive: isAnimationActive,
                animationSpeed: settingsStore.recordingIndicatorAnimationSpeed,
                barCount: FloatingRecordingIndicatorViewUtilities.waveCount(for: size),
                maxHeight: FloatingRecordingIndicatorViewUtilities.waveformHeight(for: size),
                barWidth: AppDesignSystem.Layout.recordingIndicatorWaveformBarWidth,
                barSpacing: AppDesignSystem.Layout.recordingIndicatorWaveformBarSpacing,
                minHeight: AppDesignSystem.Layout.recordingIndicatorWaveformMinHeight
            )

            if isRecordingMode, isMeetingRecording {
                Group {
                    if isAnimationActive {
                        TimelineView(.periodic(from: .now, by: 1.0)) { context in
                            let durationText = FloatingRecordingIndicatorViewUtilities.formatRecordingDuration(
                                startTime: recordingManager.currentMeeting?.startTime,
                                at: context.date
                            )
                            Text(durationText)
                                .font(.system(size: 13, weight: .medium))
                                .monospacedDigit()
                                .contentTransition(.numericText())
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .layoutPriority(1)
                                .foregroundStyle(AppDesignSystem.Colors.overlayForegroundMuted)
                        }
                    } else {
                        let durationText = FloatingRecordingIndicatorViewUtilities.formatRecordingDuration(
                            startTime: recordingManager.currentMeeting?.startTime,
                            at: Date()
                        )
                        Text(durationText)
                            .font(.system(size: 13, weight: .medium))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .layoutPriority(1)
                            .foregroundStyle(AppDesignSystem.Colors.overlayForegroundMuted)
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
            let promptIcon = FloatingRecordingIndicatorViewUtilities.promptIconImage(
                symbolName: currentPromptIconName,
                size: size
            )
            Image(nsImage: promptIcon)
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
            let flagIcon = FloatingRecordingIndicatorViewUtilities.languageFlagImage(
                currentDictationOutputLanguage.flagEmoji,
                size: size
            )
            Image(nsImage: flagIcon)
                .renderingMode(.original)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 24, height: 24, alignment: .center)
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

    private var mainPillHorizontalPadding: CGFloat {
        if isRecordingMode, isHovering {
            return AppDesignSystem.Layout.recordingIndicatorSidePadding
        }
        return max(AppDesignSystem.Layout.recordingIndicatorSidePadding, 16)
    }

    private func mainPill(size: IndicatorSize) -> some View {
        HStack(spacing: FloatingRecordingIndicatorViewUtilities.contentSpacing(for: size)) {
            if isRecordingMode, isHovering {
                leadingControls
            }

            recordingCluster(size: size)

            if isRecordingMode, isHovering {
                trailingControl
            }
        }
        .padding(.horizontal, mainPillHorizontalPadding)
        .frame(height: FloatingRecordingIndicatorViewUtilities.controlHeight(for: size))
        .background(.ultraThinMaterial)
        .background(AppDesignSystem.Colors.recordingIndicatorMaterialTint)
        .overlay(
            Capsule()
                .strokeBorder(AppDesignSystem.Colors.recordingIndicatorStroke, lineWidth: 1.2)
        )
        .clipShape(Capsule())
        .contentShape(Capsule())
        .onHover { hovering in
            handleMainRegionHover(hovering)
        }
    }

    private func promptSelectionPill(size: IndicatorSize) -> some View {
        promptPickerControl(size: size)
            .frame(
                width: FloatingRecordingIndicatorViewUtilities.promptSize(for: size),
                height: FloatingRecordingIndicatorViewUtilities.controlHeight(for: size)
            )
            .background(.ultraThinMaterial)
            .background(AppDesignSystem.Colors.recordingIndicatorAuxiliaryBackground)
            .overlay(
                Capsule()
                    .strokeBorder(AppDesignSystem.Colors.recordingIndicatorStroke, lineWidth: 1)
            )
            .clipShape(Capsule())
            .onHover { hovering in
                handlePromptRegionHover(hovering)
            }
    }

    private func languageSelectionPill(size: IndicatorSize) -> some View {
        languagePickerControl(size: size)
            .frame(
                width: FloatingRecordingIndicatorViewUtilities.promptSize(for: size),
                height: FloatingRecordingIndicatorViewUtilities.controlHeight(for: size)
            )
            .background(.ultraThinMaterial)
            .background(AppDesignSystem.Colors.recordingIndicatorAuxiliaryBackground)
            .overlay(
                Capsule()
                    .strokeBorder(AppDesignSystem.Colors.recordingIndicatorStroke, lineWidth: 1)
            )
            .clipShape(Capsule())
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
                        response: AppDesignSystem.Layout.recordingIndicatorHoverEnterResponse,
                        dampingFraction: AppDesignSystem.Layout.recordingIndicatorHoverEnterDamping
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
                        response: AppDesignSystem.Layout.recordingIndicatorHoverExitResponse,
                        dampingFraction: AppDesignSystem.Layout.recordingIndicatorHoverExitDamping
                    )
                ) {
                    isHovering = false
                }
            }
            isPromptSessionArmed = false
        }
    }

    private func controlSpacing(for size: IndicatorSize) -> CGFloat {
        FloatingRecordingIndicatorViewUtilities.controlSpacing(for: size)
    }

    private var currentDictationOutputLanguage: DictationOutputLanguage {
        if let previewLanguageOverride {
            return previewLanguageOverride
        }
        return recordingManager.effectiveDictationOutputLanguageForCurrentRecording
    }

}

#Preview("Classic recording") {
    let monitor = AudioLevelMonitor()
    FloatingRecordingIndicatorView(
        audioMonitor: monitor,
        style: .classic,
        mode: .recording,
        previewForceDictationRecording: true,
        previewLanguageOverride: .portuguese,
        onStop: {},
        onCancel: {}
    )
    .padding()
    .frame(width: 520, height: 120)
    .background(AppDesignSystem.Colors.neutral.opacity(0.8))
}

#Preview("Mini error") {
    let monitor = AudioLevelMonitor()
    FloatingRecordingIndicatorView(
        audioMonitor: monitor,
        style: .mini,
        mode: .error(message: "recording_indicator.error_message".localized),
        previewForceDictationRecording: true,
        onStop: {},
        onCancel: {}
    )
    .padding()
    .frame(width: 320, height: 120)
    .background(AppDesignSystem.Colors.neutral.opacity(0.8))
}
