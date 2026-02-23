import MeetingAssistantCoreAudio
import MeetingAssistantCoreInfrastructure
import SwiftUI

// MARK: - Audio Visualizer (Native implementation based on VoiceInk)

enum AudioVisualizerMode: Sendable {
    case recording
    case processing
}

struct AudioVisualizer: View {
    let audioMeter: AudioMeter
    let mode: AudioVisualizerMode
    let isAnimationActive: Bool
    let animationSpeed: RecordingIndicatorAnimationSpeed
    let barCount: Int
    let maxHeight: CGFloat
    let barWidth: CGFloat
    let barSpacing: CGFloat
    let minHeight: CGFloat
    let gateStart: Double = 0.35
    let gateWidth: Double = 0.2
    let inputGain: Double = 1.05
    let peakBlendRatio: Double = 0.35
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
        animationSpeed: RecordingIndicatorAnimationSpeed = .normal,
        barCount: Int,
        maxHeight: CGFloat,
        barWidth: CGFloat = MeetingAssistantDesignSystem.Layout.spacing4,
        barSpacing: CGFloat = MeetingAssistantDesignSystem.Layout.spacing2,
        minHeight: CGFloat = MeetingAssistantDesignSystem.Layout.spacing8
    ) {
        self.audioMeter = audioMeter
        self.mode = mode
        self.isAnimationActive = isAnimationActive
        self.animationSpeed = animationSpeed
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
            if isAnimationActive, !reduceMotion {
                TimelineView(.animation) { timeline in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    let adjustedTime = time * frequencyMultiplier
                    HStack(spacing: barSpacing) {
                        ForEach(0..<barCount, id: \.self) { index in
                            Capsule()
                                .fill(Color.white)
                                .frame(width: barWidth, height: processingHeight(for: index, time: adjustedTime))
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

        if isAnimationActive, !reduceMotion {
            let currentAverage = barHeights.reduce(0, +) / CGFloat(max(barHeights.count, 1))
            let targetAverage = targetHeights.reduce(0, +) / CGFloat(max(targetHeights.count, 1))
            let isRising = targetAverage >= currentAverage
            let baseResponse = isRising ? 0.18 : 0.12
            withAnimation(
                .spring(
                    response: baseResponse * responseMultiplier,
                    dampingFraction: 0.86,
                    blendDuration: 0.05
                )
            ) {
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

    private var responseMultiplier: Double {
        switch animationSpeed {
        case .slow:
            1.30
        case .normal:
            1.00
        case .fast:
            0.75
        }
    }

    private var frequencyMultiplier: Double {
        switch animationSpeed {
        case .slow:
            0.80
        case .normal:
            1.00
        case .fast:
            1.25
        }
    }

    private static func deterministicValue(index: Int, count: Int, range: ClosedRange<Double>, seed: Double) -> Double {
        guard count > 0 else { return range.lowerBound }
        let normalized = Double(index + 1) / Double(count + 1)
        let wave = (sin((normalized + seed) * .pi * 2) + 1) / 2
        return range.lowerBound + (range.upperBound - range.lowerBound) * wave
    }
}

#Preview("Processing Audio Visualizer", traits: .sizeThatFitsLayout) {
    AudioVisualizer(
        audioMeter: AudioMeter(averagePower: 0.5, peakPower: 0.8),
        mode: .processing,
        barCount: 6,
        maxHeight: MeetingAssistantDesignSystem.Layout.recordingIndicatorClassicWaveHeight
    )
    .padding()
    .background(MeetingAssistantDesignSystem.Colors.neutral.opacity(0.8))
}
