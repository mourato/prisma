import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain
import SwiftUI

struct PerformanceStatCard: View {
    let icon: String
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        DSCard {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(tint)

                Text(value)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())

                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 80)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct MetricDisplay: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text(value)
                .font(.system(.body, design: .monospaced, weight: .semibold))
                .foregroundStyle(tint)
        }
    }
}

private func formatDuration(_ duration: TimeInterval) -> String {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.minute, .second]
    formatter.unitsStyle = .abbreviated
    return formatter.string(from: duration) ?? "0s"
}

struct TranscriptionModelCard: View {
    let modelStat: ModelPerformanceStat

    var body: some View {
        DSCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(modelStat.name)
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Spacer()

                    Text("metrics.performance.transcription_count".localized(with: modelStat.fileCount))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Divider()

                VStack(spacing: 16) {
                    VStack {
                        Text(String(format: "%.1fx", modelStat.speedFactor))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.mint)
                        Text("metrics.performance.speed_factor".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    Divider()

                    HStack {
                        MetricDisplay(
                            title: "metrics.performance.avg_audio".localized,
                            value: formatDuration(modelStat.avgAudioDuration),
                            tint: .indigo
                        )
                        Spacer()
                        MetricDisplay(
                            title: "metrics.performance.avg_process_time".localized,
                            value: String(format: "%.2f s", modelStat.avgProcessingTime),
                            tint: .teal
                        )
                    }
                }
            }
        }
    }
}

struct EnhancementModelCard: View {
    let modelStat: ModelPerformanceStat

    var body: some View {
        DSCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(modelStat.name)
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Spacer()

                    Text("metrics.performance.transcription_count".localized(with: modelStat.fileCount))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Divider()

                VStack(spacing: 16) {
                    VStack {
                        Text(String(format: "%.1fx", modelStat.speedFactor))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.mint)
                        Text("metrics.performance.speed_factor".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    Divider()

                    HStack {
                        MetricDisplay(
                            title: "metrics.performance.avg_audio".localized,
                            value: formatDuration(modelStat.avgAudioDuration),
                            tint: .indigo
                        )
                        Spacer()
                        MetricDisplay(
                            title: "metrics.performance.avg_enhancement_time".localized,
                            value: String(format: "%.2f s", modelStat.avgProcessingTime),
                            tint: .teal
                        )
                    }
                }
            }
        }
    }
}
