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

    enum IndicatorSize {
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
        HStack(spacing: FloatingRecordingIndicatorViewUtilities.contentSpacing(for: size)) {
            statusDot(for: size)

            AudioVisualizer(
                audioMeter: audioMonitor.audioMeter,
                mode: visualizerModeForIndicator,
                isAnimationActive: isAnimationActive,
                animationSpeed: settingsStore.recordingIndicatorAnimationSpeed,
                barCount: FloatingRecordingIndicatorViewUtilities.waveCount(for: size),
                maxHeight: FloatingRecordingIndicatorViewUtilities.waveformHeight(for: size),
                barWidth: MeetingAssistantDesignSystem.Layout.recordingIndicatorWaveformBarWidth,
                barSpacing: MeetingAssistantDesignSystem.Layout.recordingIndicatorWaveformBarSpacing,
                minHeight: MeetingAssistantDesignSystem.Layout.recordingIndicatorWaveformMinHeight
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
                                .foregroundStyle(MeetingAssistantDesignSystem.Colors.overlayForegroundMuted)
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
        .padding(.horizontal, MeetingAssistantDesignSystem.Layout.recordingIndicatorSidePadding)
        .frame(height: FloatingRecordingIndicatorViewUtilities.controlHeight(for: size))
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
            .frame(
                width: FloatingRecordingIndicatorViewUtilities.promptSize(for: size),
                height: FloatingRecordingIndicatorViewUtilities.controlHeight(for: size)
            )
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
            .frame(
                width: FloatingRecordingIndicatorViewUtilities.promptSize(for: size),
                height: FloatingRecordingIndicatorViewUtilities.controlHeight(for: size)
            )
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

// MARK: - Preview

#Preview("Classic", traits: .sizeThatFitsLayout) {
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
    .background(MeetingAssistantDesignSystem.Colors.neutral.opacity(0.8))
}
