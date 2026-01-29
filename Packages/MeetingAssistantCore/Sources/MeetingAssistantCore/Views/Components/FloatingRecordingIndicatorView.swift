import DSWaveformImageViews
import SwiftUI

/// Floating indicator view that shows real-time audio waveforms during recording.
public struct FloatingRecordingIndicatorView: View {
    @ObservedObject var audioMonitor: AudioLevelMonitor
    let style: RecordingIndicatorStyle

    public init(audioMonitor: AudioLevelMonitor, style: RecordingIndicatorStyle) {
        self.audioMonitor = audioMonitor
        self.style = style
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
    }

    // MARK: - Classic Style

    /// Full waveform view similar to SuperWhisper's "Classic" style.
    private var classicWaveformView: some View {
        HStack(spacing: 8) {
            recordingDot
            waveformCanvas
                .frame(width: 160)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    }

    // MARK: - Mini Style

    /// Compact pill view similar to SuperWhisper's "Mini" style.
    private var miniWaveformView: some View {
        HStack(spacing: 6) {
            recordingDot
            miniWaveformBars
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)
    }

    // MARK: - Shared Components

    /// Pulsing red dot indicating active recording.
    private var recordingDot: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 8, height: 8)
            .modifier(PulsingModifier())
    }

    /// Real-time waveform canvas using DSWaveformImage.
    private var waveformCanvas: some View {
        WaveformLiveCanvas(
            samples: audioMonitor.samples,
            configuration: .init(
                style: .striped(.init(color: .white, width: 2, spacing: 2)),
                verticalScalingFactor: 0.95
            ),
            shouldDrawSilencePadding: true
        )
        .frame(height: 24)
    }

    /// Simplified animated bars for mini style.
    private var miniWaveformBars: some View {
        HStack(spacing: 2) {
            ForEach(0..<7, id: \.self) { index in
                MiniWaveformBar(
                    amplitude: barAmplitude(at: index)
                )
            }
        }
        .frame(width: 50, height: 16)
    }

    /// Calculates the amplitude for a specific bar index from samples.
    private func barAmplitude(at index: Int) -> Float {
        let samples = audioMonitor.samples
        guard !samples.isEmpty else { return 0.1 }

        // Map bar index to sample index
        let sampleIndex = (samples.count - 1) - (6 - index) * 2
        guard sampleIndex >= 0, sampleIndex < samples.count else {
            return 0.1
        }

        return max(0.1, samples[sampleIndex])
    }
}

// MARK: - Mini Waveform Bar

/// Individual animated bar for the mini waveform style.
private struct MiniWaveformBar: View {
    let amplitude: Float

    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Color.white)
            .frame(width: 2, height: barHeight)
            .animation(.easeOut(duration: 0.08), value: amplitude)
    }

    private var barHeight: CGFloat {
        let minHeight: CGFloat = 4
        let maxHeight: CGFloat = 16
        let range = maxHeight - minHeight
        return minHeight + CGFloat(amplitude) * range
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
    }
}

// MARK: - Preview

#Preview("Classic") {
    let monitor = AudioLevelMonitor()
    return FloatingRecordingIndicatorView(
        audioMonitor: monitor,
        style: .classic
    )
    .padding()
    .background(Color.gray.opacity(0.3))
}

#Preview("Mini") {
    let monitor = AudioLevelMonitor()
    return FloatingRecordingIndicatorView(
        audioMonitor: monitor,
        style: .mini
    )
    .padding()
    .background(Color.gray.opacity(0.3))
}
