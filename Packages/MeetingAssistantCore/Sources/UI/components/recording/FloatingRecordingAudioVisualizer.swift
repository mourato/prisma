import MeetingAssistantCoreAudio
import MeetingAssistantCoreInfrastructure
import SwiftUI

// MARK: - Audio Visualizer

enum AudioVisualizerMath {
    static let visualHeightBoost: Double = 0.40

    static func presentedLevels(
        _ sourceLevels: [Double],
        barCount: Int,
        isAnimationActive: Bool
    ) -> [Double] {
        guard barCount > 0 else { return [] }

        if !isAnimationActive {
            return Array(repeating: 0.0, count: barCount)
        }

        guard !sourceLevels.isEmpty else { return Array(repeating: 0.0, count: barCount) }

        return (0..<barCount).map { index in
            let sourceIndex = min(
                Int(Double(index) * Double(sourceLevels.count) / Double(barCount)),
                max(0, sourceLevels.count - 1)
            )
            return min(max(sourceLevels[sourceIndex], 0.0), 1.0)
        }
    }

    static func displayLevel(_ level: Double) -> Double {
        let clamped = min(max(level, 0.0), 1.0)
        let boosted = clamped + visualHeightBoost * pow(clamped, 3)
        return min(max(boosted, 0.0), 1.0)
    }

    static func barHeight(level: Double, minHeight: CGFloat, maxHeight: CGFloat) -> CGFloat {
        let displayLevel = displayLevel(level)
        return minHeight + CGFloat(displayLevel) * (maxHeight - minHeight)
    }
}

struct AudioVisualizer: View {
    let barLevels: [Double]
    let isAnimationActive: Bool
    let animationSpeed: RecordingIndicatorAnimationSpeed
    let barCount: Int
    let maxHeight: CGFloat
    let barWidth: CGFloat
    let barSpacing: CGFloat
    let minHeight: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        barLevels: [Double],
        isAnimationActive: Bool = true,
        animationSpeed: RecordingIndicatorAnimationSpeed = .normal,
        barCount: Int,
        maxHeight: CGFloat,
        barWidth: CGFloat = 4,
        barSpacing: CGFloat = 2,
        minHeight: CGFloat = 8
    ) {
        self.barLevels = barLevels
        self.isAnimationActive = isAnimationActive
        self.animationSpeed = animationSpeed
        self.barCount = barCount
        self.maxHeight = maxHeight
        self.barWidth = barWidth
        self.barSpacing = barSpacing
        self.minHeight = minHeight
    }

    var body: some View {
        let levels = AudioVisualizerMath.presentedLevels(
            barLevels,
            barCount: barCount,
            isAnimationActive: isAnimationActive
        )

        return HStack(spacing: barSpacing) {
            ForEach(0..<barCount, id: \.self) { index in
                Capsule()
                    .fill(Color.white)
                    .frame(
                        width: barWidth,
                        height: AudioVisualizerMath.barHeight(
                            level: levels[safe: index] ?? 0.0,
                            minHeight: minHeight,
                            maxHeight: maxHeight
                        )
                    )
            }
        }
        .frame(height: maxHeight, alignment: .center)
        .animation(reduceMotion ? nil : .linear(duration: animationDuration), value: levels)
    }

    private var animationDuration: Double {
        switch animationSpeed {
        case .slow:
            0.12
        case .normal:
            0.08
        case .fast:
            0.06
        }
    }
}

private struct AudioVisualizerLivePreview: View {
    var body: some View {
        AudioVisualizer(
            barLevels: [0.18, 0.24, 0.32, 0.52, 0.70, 0.64, 0.42, 0.28, 0.20],
            isAnimationActive: true,
            animationSpeed: .normal,
            barCount: AppDesignSystem.Layout.recordingIndicatorClassicWaveCount,
            maxHeight: AppDesignSystem.Layout.recordingIndicatorClassicWaveHeight,
            barWidth: AppDesignSystem.Layout.recordingIndicatorWaveformBarWidth,
            barSpacing: AppDesignSystem.Layout.recordingIndicatorWaveformBarSpacing,
            minHeight: AppDesignSystem.Layout.recordingIndicatorWaveformMinHeight
        )
        .padding()
        .background(AppDesignSystem.Colors.neutral.opacity(0.8))
    }
}

#Preview("Recording Audio Visualizer", traits: .sizeThatFitsLayout) {
    AudioVisualizerLivePreview()
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
