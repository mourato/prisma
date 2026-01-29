import SwiftUI

/// Floating indicator view that shows real-time audio waveforms during recording.
public struct FloatingRecordingIndicatorView: View {
    @ObservedObject var audioMonitor: AudioLevelMonitor
    let style: RecordingIndicatorStyle
    let onStop: @Sendable () -> Void
    let onCancel: @Sendable () -> Void

    @State private var isHovering = false

    public init(
        audioMonitor: AudioLevelMonitor,
        style: RecordingIndicatorStyle,
        onStop: @escaping @Sendable () -> Void,
        onCancel: @escaping @Sendable () -> Void
    ) {
        self.audioMonitor = audioMonitor
        self.style = style
        self.onStop = onStop
        self.onCancel = onCancel
    }

    public var body: some View {
        Group {
            switch style {
            case .classic:
                classicWaveformView
            case .mini:
                miniWaveformView
            case .none:
                EmptyView()
            }
        }
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovering = hovering
            }
        }
    }

    // MARK: - Classic Style

    /// Full waveform view similar to SuperWhisper's "Classic" style.
    private var classicWaveformView: some View {
        ZStack {
            HStack(spacing: 8) {
                recordingDot
                AudioVisualizer(
                    audioMeter: audioMonitor.audioMeter,
                    barCount: 16,
                    maxHeight: 44
                )
                .frame(width: 120)
            }
            .opacity(isHovering ? 0.3 : 1.0)

            if isHovering {
                controlsOverlay
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color.black.opacity(0.85))
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    }

    // MARK: - Mini Style

    /// Compact pill view similar to SuperWhisper's "Mini" style.
    private var miniWaveformView: some View {
        ZStack {
            HStack(spacing: 6) {
                recordingDot
                AudioVisualizer(
                    audioMeter: audioMonitor.audioMeter,
                    barCount: 7,
                    maxHeight: 16
                )
            }
            .opacity(isHovering ? 0.3 : 1.0)

            if isHovering {
                controlsOverlay
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.85))
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
            .help("Stop and Transcribe")

            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
            .help("Cancel and Discard")
        }
    }

    /// Pulsing red dot indicating active recording.
    private var recordingDot: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 8, height: 8)
            .modifier(PulsingModifier())
    }
}

// MARK: - Audio Visualizer (Native implementation based on VoiceInk)

struct AudioVisualizer: View {
    let audioMeter: AudioMeter
    let barCount: Int
    let minHeight: CGFloat = 4
    let maxHeight: CGFloat
    let barWidth: CGFloat = 2.5
    let barSpacing: CGFloat = 2.0
    let hardThreshold: Double = 0.05

    private let sensitivityMultipliers: [Double]

    @State private var barHeights: [CGFloat]
    @State private var targetHeights: [CGFloat]

    init(audioMeter: AudioMeter, barCount: Int, maxHeight: CGFloat) {
        self.audioMeter = audioMeter
        self.barCount = barCount
        self.maxHeight = maxHeight

        sensitivityMultipliers = (0..<barCount).map { _ in
            Double.random(in: 0.6...1.4)
        }

        _barHeights = State(initialValue: Array(repeating: 4, count: barCount))
        _targetHeights = State(initialValue: Array(repeating: 4, count: barCount))
    }

    var body: some View {
        HStack(spacing: barSpacing) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.2)
                    .fill(Color.white)
                    .frame(width: barWidth, height: barHeights[index])
            }
        }
        .onChange(of: audioMeter) { _, newValue in
            updateBars(with: Float(newValue.averagePower))
        }
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
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 0.5 : 1.0)
            .scaleEffect(isPulsing ? 0.85 : 1.0)
            .animation(
                .easeInOut(duration: 0.8)
                    .repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear {
                isPulsing = true
            }
            .onDisappear {
                isPulsing = false
            }
    }
}

// MARK: - Preview

#Preview("Classic") {
    let monitor = AudioLevelMonitor()
    return FloatingRecordingIndicatorView(
        audioMonitor: monitor,
        style: .classic,
        onStop: {},
        onCancel: {}
    )
    .padding()
    .background(Color.gray.opacity(0.3))
}

#Preview("Mini") {
    let monitor = AudioLevelMonitor()
    return FloatingRecordingIndicatorView(
        audioMonitor: monitor,
        style: .mini,
        onStop: {},
        onCancel: {}
    )
    .padding()
    .background(Color.gray.opacity(0.3))
}
