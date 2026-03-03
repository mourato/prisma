import SwiftUI

// MARK: - Model

/// Represents a single bar in the waveform visualization.
private struct WaveformBar: Identifiable {
    let id: Int
    let normalizedAmplitude: Float
    let relativePosition: Double
}

// MARK: - View

/// A simple bar-based waveform visualization.
public struct AudioWaveformView: View {
    let samples: [Float]
    let progress: Double
    let color: Color

    public init(samples: [Float], progress: Double, color: Color = .accentColor) {
        self.samples = samples
        self.progress = progress
        self.color = color
    }

    private var bars: [WaveformBar] {
        let count = samples.count
        guard count > 0 else { return [] }
        return samples.enumerated().map { index, amplitude in
            WaveformBar(
                id: index,
                normalizedAmplitude: amplitude,
                relativePosition: Double(index) / Double(count)
            )
        }
    }

    public var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 1) {
                ForEach(bars) { bar in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(bar.relativePosition <= progress ? color : color.opacity(0.3))
                        .frame(minWidth: 1)
                        .frame(height: geometry.size.height * CGFloat(bar.normalizedAmplitude))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    AudioWaveformView(
        samples: [0.2, 0.4, 0.8, 0.5, 0.3, 0.9, 0.4, 0.2, 0.6, 0.8],
        progress: 0.5
    )
    .frame(width: 200, height: 40)
    .padding()
}
