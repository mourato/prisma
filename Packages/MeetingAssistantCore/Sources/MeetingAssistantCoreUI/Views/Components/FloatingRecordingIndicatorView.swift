import Foundation
import SwiftUI
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

/// Floating indicator view that shows audio waveforms during recording or processing.
public struct FloatingRecordingIndicatorView: View {
    @ObservedObject var audioMonitor: AudioLevelMonitor
    @ObservedObject private var recordingManager: RecordingManager
    @ObservedObject private var settingsStore: AppSettingsStore
    let style: RecordingIndicatorStyle
    let mode: FloatingRecordingIndicatorMode
    let meetingType: MeetingType? // Added
    let onStop: @Sendable () -> Void
    let onCancel: @Sendable () -> Void

    @State private var isHovering = false
    @State private var hoverCollapseTask: Task<Void, Never>?

    public init(
        audioMonitor: AudioLevelMonitor,
        style: RecordingIndicatorStyle,
        mode: FloatingRecordingIndicatorMode,
        meetingType: MeetingType? = nil, // Added default nil
        recordingManager: RecordingManager = .shared,
        settingsStore: AppSettingsStore = .shared,
        onStop: @escaping @Sendable () -> Void,
        onCancel: @escaping @Sendable () -> Void
    ) {
        self.audioMonitor = audioMonitor
        self.style = style
        self.mode = mode
        self.meetingType = meetingType
        self.recordingManager = recordingManager
        self.settingsStore = settingsStore
        self.onStop = onStop
        self.onCancel = onCancel
    }

    public var body: some View {
        switch mode {
        case .error:
            errorView
        case .recording, .processing:
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

    // MARK: - Indicator Pill (Figma)

    private enum IndicatorSize {
        case classic
        case mini
    }

    private func indicatorPill(size: IndicatorSize) -> some View {
        let isExpanded = isRecordingMode && isHovering
        let controlHeight = controlHeight(for: size)
        let expandedSideWidth = controlHeight + MeetingAssistantDesignSystem.Layout.spacing20

        return ZStack(alignment: .top) {
            HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing12) {
                expandedLeadingControls
                    .modifier(
                        ExpandedContentVisibility(
                            isVisible: isExpanded,
                            expandedWidth: expandedSideWidth
                        )
                    )

                divider
                    .modifier(
                        ExpandedContentVisibility(
                            isVisible: isExpanded,
                            expandedWidth: 1
                        )
                    )

                recordingCluster(size: size)

                divider
                    .modifier(
                        ExpandedContentVisibility(
                            isVisible: isExpanded,
                            expandedWidth: 1
                        )
                    )

                expandedTrailingControl
                    .modifier(
                        ExpandedContentVisibility(
                            isVisible: isExpanded,
                            expandedWidth: expandedSideWidth
                        )
                    )
            }
            .padding(.horizontal, MeetingAssistantDesignSystem.Layout.spacing16)
            .frame(height: controlHeight)
            .background(MeetingAssistantDesignSystem.Colors.overlayBackground)
            .clipShape(Capsule())
            .shadow(
                color: .black.opacity(0.15),
                radius: MeetingAssistantDesignSystem.Layout.shadowRadius,
                x: MeetingAssistantDesignSystem.Layout.shadowX,
                y: MeetingAssistantDesignSystem.Layout.shadowY
            )
            .contentShape(Capsule())
            .onHover { hovering in
                guard isRecordingMode else { return }
                if hovering {
                    hoverCollapseTask?.cancel()
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.86)) {
                        isHovering = true
                    }
                    return
                }

                hoverCollapseTask?.cancel()
                hoverCollapseTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 110_000_000)
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeOut(duration: 0.14)) {
                        isHovering = false
                    }
                }
            }
            .onDisappear {
                hoverCollapseTask?.cancel()
                hoverCollapseTask = nil
            }

            if isRecordingMode, audioMonitor.isSilenceWarningVisible {
                silenceWarningOverlay
                    .padding(.top, 2)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    // MARK: - Shared Components

    private var expandedLeadingControls: some View {
        HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing12) {
            Button(action: onStop) {
                Image(systemName: "checkmark")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(MeetingAssistantDesignSystem.Colors.overlayForeground)
                    .frame(
                        width: MeetingAssistantDesignSystem.Layout.spacing20,
                        height: MeetingAssistantDesignSystem.Layout.spacing20
                    )
            }
            .buttonStyle(.plain)
            .help("recording_indicator.stop.help".localized)

            promptPickerControl
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
            .contentShape(Rectangle())
            .onTapGesture {
                onCancel()
                audioMonitor.dismissSilenceWarning()
            }
    }

    private var divider: some View {
        Rectangle()
            .fill(MeetingAssistantDesignSystem.Colors.overlayDivider)
            .frame(width: 1, height: MeetingAssistantDesignSystem.Layout.spacing20)
    }

    private var expandedTrailingControl: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            Button(action: onCancel) {
                Image(systemName: "trash")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(MeetingAssistantDesignSystem.Colors.overlayForeground)
                    .frame(
                        width: MeetingAssistantDesignSystem.Layout.spacing20,
                        height: MeetingAssistantDesignSystem.Layout.spacing20
                    )
            }
            .buttonStyle(.plain)
            .help("recording_indicator.cancel.help".localized)
        }
    }

    /// Dot indicating recording or processing (Figma uses 12x12).
    private func statusDot(for size: IndicatorSize) -> some View {
        let dotSize: CGFloat = switch size {
        case .classic:
            MeetingAssistantDesignSystem.Layout.spacing12
        case .mini:
            MeetingAssistantDesignSystem.Layout.recordingIndicatorMiniDotSize
        }

        Circle()
            .fill(isRecordingMode ? MeetingAssistantDesignSystem.Colors.recording : MeetingAssistantDesignSystem.Colors.accent)
            .frame(width: dotSize, height: dotSize)
            .modifier(PulsingModifier(isActive: isRecordingMode, speed: isRecordingMode ? 0.9 : 1.4))
    }

    private func controlHeight(for size: IndicatorSize) -> CGFloat {
        switch size {
        case .classic:
            MeetingAssistantDesignSystem.Layout.controlHeight
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
        guard recordingManager.isRecording else { return false }
        if recordingManager.recordingSource == .microphone { return true }
        return recordingManager.currentMeeting?.isDictation == true
    }

    private var isMeetingRecording: Bool {
        recordingManager.isRecording && !isDictationRecording
    }

    private func recordingCluster(size: IndicatorSize) -> some View {
        HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing12) {
            statusDot(for: size)

            AudioVisualizer(
                audioMeter: audioMonitor.audioMeter,
                mode: visualizerModeForIndicator,
                barCount: size == .classic ? 16 : 8,
                maxHeight: MeetingAssistantDesignSystem.Layout.recordingIndicatorWaveformMaxHeight,
                barWidth: MeetingAssistantDesignSystem.Layout.spacing4,
                barSpacing: MeetingAssistantDesignSystem.Layout.spacing2,
                minHeight: MeetingAssistantDesignSystem.Layout.spacing8
            )

            if isRecordingMode, isMeetingRecording {
                TimelineView(.periodic(from: .now, by: 1.0)) { context in
                    Text(formatRecordingDuration(at: context.date))
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(MeetingAssistantDesignSystem.Colors.overlayForeground)
                        .monospacedDigit()
                }
                .accessibilityLabel("recording_indicator.duration".localized)
            }
        }
    }

    private var promptPickerControl: some View {
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
            HStack(spacing: 6) {
                Image(systemName: currentPromptIconName)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(MeetingAssistantDesignSystem.Colors.overlayForeground)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(MeetingAssistantDesignSystem.Colors.overlayForegroundMuted)
            }
            .frame(height: MeetingAssistantDesignSystem.Layout.spacing20)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .help("recording_indicator.prompt.help".localized)
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
}

private struct ExpandedContentVisibility: ViewModifier {
    let isVisible: Bool
    let expandedWidth: CGFloat

    func body(content: Content) -> some View {
        content
            .frame(width: isVisible ? expandedWidth : 0)
            .animation(
                isVisible
                    ? .spring(response: 0.2, dampingFraction: 0.88)
                    : .easeOut(duration: 0.12),
                value: isVisible
            )
            .opacity(isVisible ? 1 : 0)
            .animation(
                isVisible
                    ? .easeOut(duration: 0.16)
                    : .easeIn(duration: 0.08),
                value: isVisible
            )
            .clipped()
            .allowsHitTesting(isVisible)
            .accessibilityHidden(!isVisible)
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
    let barCount: Int
    let maxHeight: CGFloat
    let barWidth: CGFloat
    let barSpacing: CGFloat
    let minHeight: CGFloat
    let hardThreshold: Double = 0.05

    private let sensitivityMultipliers: [Double]
    private let phaseOffsets: [Double]
    private let secondaryOffsets: [Double]
    private let amplitudeScales: [Double]

    @State private var barHeights: [CGFloat]
    @State private var targetHeights: [CGFloat]

    init(
        audioMeter: AudioMeter,
        mode: AudioVisualizerMode,
        barCount: Int,
        maxHeight: CGFloat,
        barWidth: CGFloat = MeetingAssistantDesignSystem.Layout.spacing4,
        barSpacing: CGFloat = MeetingAssistantDesignSystem.Layout.spacing2,
        minHeight: CGFloat = MeetingAssistantDesignSystem.Layout.spacing8
    ) {
        self.audioMeter = audioMeter
        self.mode = mode
        self.barCount = barCount
        self.maxHeight = maxHeight
        self.barWidth = barWidth
        self.barSpacing = barSpacing
        self.minHeight = minHeight

        sensitivityMultipliers = (0..<barCount).map { _ in
            Double.random(in: 0.6...1.4)
        }
        phaseOffsets = (0..<barCount).map { _ in
            Double.random(in: 0...Double.pi * 2)
        }
        secondaryOffsets = (0..<barCount).map { _ in
            Double.random(in: 0...Double.pi * 2)
        }
        amplitudeScales = (0..<barCount).map { _ in
            Double.random(in: 0.75...1.1)
        }

        _barHeights = State(initialValue: Array(repeating: minHeight, count: barCount))
        _targetHeights = State(initialValue: Array(repeating: minHeight, count: barCount))
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
        .onChange(of: audioMeter.averagePower) { _, newValue in
            updateBars(with: Float(newValue))
        }
    }

    private var processingBars: some View {
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
    }

    private func processingHeight(for index: Int, time: TimeInterval) -> CGFloat {
        let base = (sin(time * 2.4 + phaseOffsets[index]) + 1) / 2
        let modulation = (sin(time * 0.9 + secondaryOffsets[index]) + 1) / 2
        let blended = (0.35 + 0.65 * base) * (0.6 + 0.4 * modulation) * amplitudeScales[index]
        let clamped = min(1.0, max(0.0, blended))
        return minHeight + CGFloat(clamped) * (maxHeight - minHeight)
    }

    private func updateBars(with audioLevel: Float) {
        let rawLevel = max(0, min(1, Double(audioLevel)))
        let adjustedLevel = rawLevel < hardThreshold ? 0 : (rawLevel - hardThreshold) / (1.0 - hardThreshold)

        let range = maxHeight - minHeight
        let center = barCount / 2

        for i in 0..<barCount {
            let distanceFromCenter = abs(i - center)
            let positionMultiplier = 1.0 - (Double(distanceFromCenter) / Double(center)) * 0.4

            // Use randomized sensitivity
            let sensitivityAdjustedLevel = adjustedLevel * positionMultiplier * sensitivityMultipliers[i]

            let targetHeight = minHeight + CGFloat(sensitivityAdjustedLevel) * range

            let isDecaying = targetHeight < targetHeights[i]
            let smoothingFactor: CGFloat = isDecaying ? 0.4 : 0.2

            targetHeights[i] = targetHeights[i] * (1 - smoothingFactor) + targetHeight * smoothingFactor

            if abs(barHeights[i] - targetHeights[i]) > 0.3 {
                barHeights[i] = targetHeights[i]
            }
        }
    }
}

// MARK: - Pulsing Animation Modifier

/// Modifier that adds a subtle pulsing animation.
private struct PulsingModifier: ViewModifier {
    let isActive: Bool
    let speed: Double
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 0.6 : 1.0)
            .scaleEffect(isPulsing ? 1.15 : 1.0)
            .onAppear { updateAnimation() }
            .onChange(of: isActive) { _, _ in updateAnimation() }
            .onChange(of: speed) { _, _ in updateAnimation() }
    }

    private func updateAnimation() {
        guard isActive else {
            isPulsing = false
            return
        }
        withAnimation(.easeInOut(duration: speed).repeatForever(autoreverses: true)) {
            isPulsing = true
        }
    }
}

// MARK: - Preview

#Preview("Classic") {
    let monitor = AudioLevelMonitor()
    return FloatingRecordingIndicatorView(
        audioMonitor: monitor,
        style: .classic,
        mode: .recording,
        onStop: {},
        onCancel: {}
    )
    .padding()
    .background(MeetingAssistantDesignSystem.Colors.neutral.opacity(0.3))
}

#Preview("Mini") {
    let monitor = AudioLevelMonitor()
    return FloatingRecordingIndicatorView(
        audioMonitor: monitor,
        style: .mini,
        mode: .recording,
        onStop: {},
        onCancel: {}
    )
    .padding()
    .background(MeetingAssistantDesignSystem.Colors.neutral.opacity(0.3))
}
