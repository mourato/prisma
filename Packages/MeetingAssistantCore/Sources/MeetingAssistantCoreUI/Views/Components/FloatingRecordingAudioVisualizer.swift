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

    private let phaseOffsets: [Double]
    private let secondaryOffsets: [Double]
    private let recordingAmplitudeScales: [Double]
    private let recordingPrimaryRateScales: [Double]
    private let recordingSecondaryRateScales: [Double]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

        phaseOffsets = (0..<barCount).map { Double($0) * 0.4 }
        secondaryOffsets = (0..<barCount).map { Double($0) * 0.73 }
        recordingAmplitudeScales = (0..<barCount).map { index in
            Self.deterministicValue(index: index, count: barCount, range: 0.78...1.32, seed: 0.31)
        }
        recordingPrimaryRateScales = (0..<barCount).map { index in
            Self.deterministicValue(index: index, count: barCount, range: 0.86...1.24, seed: 0.61)
        }
        recordingSecondaryRateScales = (0..<barCount).map { index in
            Self.deterministicValue(index: index, count: barCount, range: 1.45...2.30, seed: 1.09)
        }
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
        Group {
            if isAnimationActive, !reduceMotion {
                TimelineView(.animation(minimumInterval: 0.016)) { timeline in
                    HStack(spacing: barSpacing) {
                        ForEach(0..<barCount, id: \.self) { index in
                            Capsule()
                                .fill(Color.white)
                                .frame(
                                    width: barWidth,
                                    height: recordingHeight(for: index, at: timeline.date)
                                )
                        }
                    }
                }
            } else {
                staticBars
            }
        }
        .frame(height: maxHeight, alignment: .center)
    }

    private var processingBars: some View {
        Group {
            if isAnimationActive, !reduceMotion {
                TimelineView(.animation(minimumInterval: 0.016)) { timeline in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    HStack(spacing: barSpacing) {
                        ForEach(0..<barCount, id: \.self) { index in
                            Capsule()
                                .fill(Color.white)
                                .frame(width: barWidth, height: processingHeight(for: index, time: time))
                        }
                    }
                }
            } else {
                staticBars
            }
        }
        .frame(height: maxHeight, alignment: .center)
    }

    private var staticBars: some View {
        HStack(spacing: barSpacing) {
            ForEach(0..<barCount, id: \.self) { _ in
                Capsule()
                    .fill(Color.white)
                    .frame(width: barWidth, height: minHeight)
            }
        }
    }

    private func recordingHeight(for index: Int, at date: Date) -> CGFloat {
        let time = date.timeIntervalSince1970
        let average = max(0.0, min(1.0, audioMeter.averagePower))
        let peak = max(0.0, min(1.0, audioMeter.peakPower))
        let energy = max(pow(average, 0.72), pow(peak, 0.68) * 0.55)

        let baseRate = 8.0 * frequencyMultiplier
        let primaryWave = (
            sin(time * (baseRate * recordingPrimaryRateScales[index]) + phaseOffsets[index]) + 1.0
        ) / 2.0
        let secondaryWave = (
            sin(time * (baseRate * recordingSecondaryRateScales[index]) + secondaryOffsets[index]) + 1.0
        ) / 2.0
        let independentWave = (0.58 * primaryWave) + (0.42 * secondaryWave)

        let centerDistance = abs(Double(index) - Double(barCount) / 2.0) / Double(max(barCount / 2, 1))
        let centerWeight = 1.0 - (centerDistance * 0.20)
        let scaled = energy * (0.28 + 0.72 * independentWave) * centerWeight * recordingAmplitudeScales[index]
        let clamped = min(1.0, max(0.0, scaled))
        return minHeight + CGFloat(clamped) * (maxHeight - minHeight)
    }

    private func processingHeight(for index: Int, time: TimeInterval) -> CGFloat {
        let base = (sin(time * (7.2 * frequencyMultiplier) + phaseOffsets[index]) + 1.0) / 2.0
        let modulation = (sin(time * (3.8 * frequencyMultiplier) + secondaryOffsets[index]) + 1.0) / 2.0
        let blended = (0.45 + 0.55 * base) * (0.65 + 0.35 * modulation)
        let clamped = min(1.0, max(0.0, blended))
        return minHeight + CGFloat(clamped) * (maxHeight - minHeight)
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

    private static func deterministicValue(
        index: Int,
        count: Int,
        range: ClosedRange<Double>,
        seed: Double
    ) -> Double {
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
