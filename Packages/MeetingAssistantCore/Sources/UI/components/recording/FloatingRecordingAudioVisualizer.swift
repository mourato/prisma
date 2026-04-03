import MeetingAssistantCoreAudio
import MeetingAssistantCoreInfrastructure
import SwiftUI

// MARK: - Audio Visualizer

enum AudioVisualizerMath {
    static let visibilityGate: Double = 0.20
    static let amplitudeExponent: Double = 1.10
    static let centerBoostStrength: Double = 0
    static let visualHeightBoost: Double = 0.40

    static func shapedLevel(_ level: Double) -> Double {
        let clamped = min(max(level, 0.0), 1.0)
        guard clamped > visibilityGate else { return 0.0 }
        let normalized = (clamped - visibilityGate) / (1.0 - visibilityGate)
        return min(1.0, max(0.0, pow(normalized, amplitudeExponent)))
    }

    static func instantLevels(
        snapshotLevels: [Double],
        fallbackLevel: Double,
        barCount: Int,
        isAnimationActive: Bool
    ) -> [Double] {
        guard barCount > 0 else { return [] }

        if !isAnimationActive {
            return Array(repeating: 0.0, count: barCount)
        }

        let sourceLevels: [Double] = if snapshotLevels.isEmpty {
            Array(repeating: fallbackLevel, count: barCount)
        } else {
            snapshotLevels
        }

        return (0..<barCount).map { index in
            let sourceIndex = min(
                Int(Double(index) * Double(sourceLevels.count) / Double(barCount)),
                max(0, sourceLevels.count - 1)
            )
            let shaped = shapedLevel(sourceLevels[sourceIndex])
            return centerBoostedLevel(shaped, index: index, barCount: barCount)
        }
    }

    static func centerBoostedLevel(_ level: Double, index: Int, barCount: Int) -> Double {
        guard barCount > 1 else { return min(max(level, 0.0), 1.0) }

        let center = Double(barCount - 1) / 2.0
        let distance = abs(Double(index) - center)
        let normalizedDistance = min(1.0, distance / max(center, 1.0))
        let centerInfluence = 1.0 - normalizedDistance
        let boosted = level * (1.0 + (centerInfluence * centerBoostStrength))
        return min(max(boosted, 0.0), 1.0)
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
    let audioMeter: AudioMeter
    let instantBarLevels: [Double]
    let isAnimationActive: Bool
    let animationSpeed: RecordingIndicatorAnimationSpeed
    let barCount: Int
    let maxHeight: CGFloat
    let barWidth: CGFloat
    let barSpacing: CGFloat
    let minHeight: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        audioMeter: AudioMeter,
        instantBarLevels: [Double] = [],
        isAnimationActive: Bool = true,
        animationSpeed: RecordingIndicatorAnimationSpeed = .normal,
        barCount: Int,
        maxHeight: CGFloat,
        barWidth: CGFloat = 4,
        barSpacing: CGFloat = 2,
        minHeight: CGFloat = 8
    ) {
        self.audioMeter = audioMeter
        self.instantBarLevels = instantBarLevels
        self.isAnimationActive = isAnimationActive
        self.animationSpeed = animationSpeed
        self.barCount = barCount
        self.maxHeight = maxHeight
        self.barWidth = barWidth
        self.barSpacing = barSpacing
        self.minHeight = minHeight
    }

    var body: some View {
        let levels = AudioVisualizerMath.instantLevels(
            snapshotLevels: instantBarLevels,
            fallbackLevel: audioMeter.averagePower,
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
        .animation(reduceMotion ? nil : .easeOut(duration: animationDuration), value: levels)
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
            audioMeter: AudioMeter(averagePower: 0.44, peakPower: 0.72),
            instantBarLevels: [0.18, 0.24, 0.32, 0.52, 0.70, 0.64, 0.42, 0.28, 0.20],
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
