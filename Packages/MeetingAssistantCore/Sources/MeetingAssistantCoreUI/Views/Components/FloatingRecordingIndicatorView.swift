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
    let style: RecordingIndicatorStyle
    let mode: FloatingRecordingIndicatorMode
    let meetingType: MeetingType? // Added
    let onStop: @Sendable () -> Void
    let onCancel: @Sendable () -> Void

    @State private var isHovering = false

    public init(
        audioMonitor: AudioLevelMonitor,
        style: RecordingIndicatorStyle,
        mode: FloatingRecordingIndicatorMode,
        meetingType: MeetingType? = nil, // Added default nil
        onStop: @escaping @Sendable () -> Void,
        onCancel: @escaping @Sendable () -> Void
    ) {
        self.audioMonitor = audioMonitor
        self.style = style
        self.mode = mode
        self.meetingType = meetingType
        self.onStop = onStop
        self.onCancel = onCancel
    }

    public var body: some View {
        Group {
            switch mode {
            case .error:
                errorView
            case .recording, .processing:
                switch style {
                case .classic:
                    classicWaveformView
                case .mini:
                    miniWaveformView
                case .none:
                    EmptyView()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovering = hovering
            }
        }
    }

    // MARK: - Classic Style

    /// Full waveform view similar to SuperWhisper's "Classic" style.
    private var classicWaveformView: some View {
        let visualizerMode = visualizerModeForIndicator
        return ZStack {
            HStack(spacing: 4) {
                statusDot
                AudioVisualizer(
                    audioMeter: audioMonitor.audioMeter,
                    mode: visualizerMode,
                    barCount: 16,
                    maxHeight: 24
                )
                .frame(width: 120)

                if let type = meetingType, isRecordingMode {
                    Image(systemName: type.iconName)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.leading, 4)
                        .help(type.displayName)
                }
            }
            .opacity(isHovering ? 0.3 : 1.0)

            if isHovering, isRecordingMode {
                controlsOverlay
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }

            if isRecordingMode, audioMonitor.isSilenceWarningVisible {
                silenceWarningOverlay
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(MeetingAssistantDesignSystem.Colors.overlayBackground)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    }

    // MARK: - Mini Style

    /// Compact pill view similar to SuperWhisper's "Mini" style.
    private var miniWaveformView: some View {
        let visualizerMode = visualizerModeForIndicator
        return ZStack {
            HStack(spacing: 6) {
                statusDot
                AudioVisualizer(
                    audioMeter: audioMonitor.audioMeter,
                    mode: visualizerMode,
                    barCount: 7,
                    maxHeight: 16
                )
            }
            .opacity(isHovering ? 0.3 : 1.0)

            if isHovering, isRecordingMode {
                controlsOverlay
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }

            if isRecordingMode, audioMonitor.isSilenceWarningVisible {
                silenceWarningOverlay
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(MeetingAssistantDesignSystem.Colors.overlayBackground)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)
    }

    // MARK: - Shared Components

    /// Control buttons overlay shown on hover.
    private var controlsOverlay: some View {
        HStack(spacing: 24) {
            Button(action: onStop) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .help("recording_indicator.stop.help".localized)

            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
            .help("recording_indicator.cancel.help".localized)
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
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(MeetingAssistantDesignSystem.Colors.recording.opacity(0.9))
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            .contentShape(Rectangle())
            .onTapGesture {
                onCancel()
                audioMonitor.dismissSilenceWarning()
            }
    }

    /// Dot indicating recording or processing.
    private var statusDot: some View {
        Circle()
            .fill(isRecordingMode ? MeetingAssistantDesignSystem.Colors.recording : MeetingAssistantDesignSystem.Colors.accent)
            .frame(width: 8, height: 8)
            .modifier(PulsingModifier(isActive: isRecordingMode, speed: isRecordingMode ? 0.9 : 1.4))
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

        return HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.white)
                .font(.system(size: 12, weight: .bold))

            Text(message)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(MeetingAssistantDesignSystem.Colors.error.opacity(0.95))
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
    }

    private var errorMessage: String? {
        guard case let .error(message) = mode else {
            return nil
        }
        return message
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
    let minHeight: CGFloat = 2.5
    let maxHeight: CGFloat
    let barWidth: CGFloat = 2.5
    let barSpacing: CGFloat = 2.0
    let hardThreshold: Double = 0.05

    private let sensitivityMultipliers: [Double]
    private let phaseOffsets: [Double]
    private let secondaryOffsets: [Double]
    private let amplitudeScales: [Double]

    @State private var barHeights: [CGFloat]
    @State private var targetHeights: [CGFloat]

    init(audioMeter: AudioMeter, mode: AudioVisualizerMode, barCount: Int, maxHeight: CGFloat) {
        self.audioMeter = audioMeter
        self.mode = mode
        self.barCount = barCount
        self.maxHeight = maxHeight

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

        _barHeights = State(initialValue: Array(repeating: 4, count: barCount))
        _targetHeights = State(initialValue: Array(repeating: 4, count: barCount))
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
                RoundedRectangle(cornerRadius: 1.2)
                    .fill(Color.white)
                    .frame(width: barWidth, height: barHeights[index])
            }
        }
        .frame(height: maxHeight, alignment: .center)
        .onChange(of: audioMeter) { _, newValue in
            updateBars(with: Float(newValue.averagePower))
        }
    }

    private var processingBars: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: barSpacing) {
                ForEach(0..<barCount, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1.2)
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
                withAnimation(
                    isDecaying
                        ? .spring(response: 0.3, dampingFraction: 0.8)
                        : .spring(response: 0.2, dampingFraction: 0.7)
                ) {
                    barHeights[i] = targetHeights[i]
                }
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
