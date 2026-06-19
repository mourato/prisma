import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain
import SwiftUI

struct MetricsDashboardPerformanceWorkspace: View {
    @ObservedObject var viewModel: MetricsDashboardPerformanceViewModel
    let openRecording: (UUID) -> Void

    var body: some View {
        stageSection

        if viewModel.analysis.summary.totalAttempts == 0, !viewModel.isLoading {
            MAEmptyStateView(
                iconName: "gauge.open.with.lines.needle.33percent",
                title: "metrics.performance.empty.title".localized,
                message: "metrics.performance.empty.subtitle".localized
            )
        } else {
            MetricsDashboardPerformanceSummaryStrip(analysis: viewModel.analysis)
            filtersSection
            MetricsDashboardPerformanceLeaderboardSection(
                stage: viewModel.stage,
                sort: $viewModel.leaderboardSort,
                entries: viewModel.sortedLeaderboard
            )
            MetricsDashboardPerformanceHistorySection(
                stage: viewModel.stage,
                attempts: viewModel.history,
                openRecording: openRecording
            )
        }
    }

    private var stageSection: some View {
        DSGroup("metrics.performance.stage.title".localized, icon: "square.3.layers.3d.top.filled") {
            Picker("", selection: $viewModel.stage) {
                ForEach(ModelPerformanceStage.allCases, id: \.self) { stage in
                    Text(stage.displayName).tag(stage)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
        }
    }

    private var filtersSection: some View {
        DSGroup("metrics.performance.filters.title".localized, icon: "line.3.horizontal.decrease.circle") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    MetricsDashboardFilterPicker(
                        title: "metrics.performance.filters.capture".localized,
                        selection: $viewModel.captureFilter
                    ) {
                        ForEach(PerformanceFilter.allCases, id: \.self) { filter in
                            Text(filter.displayName).tag(filter)
                        }
                    }

                    MetricsDashboardFilterPicker(
                        title: "metrics.performance.filters.date".localized,
                        selection: $viewModel.dateFilter
                    ) {
                        ForEach(DateFilter.allCases, id: \.self) { filter in
                            Text(filter.displayName).tag(filter)
                        }
                    }
                }

                HStack(spacing: 12) {
                    MetricsDashboardFilterPicker(
                        title: "metrics.performance.filters.provider".localized,
                        selection: $viewModel.providerID
                    ) {
                        Text("metrics.performance.filters.provider.all".localized)
                            .tag(String?.none)

                        ForEach(viewModel.providerOptions) { option in
                            Text(option.displayName).tag(Optional(option.id))
                        }
                    }

                    MetricsDashboardFilterPicker(
                        title: "metrics.performance.filters.status".localized,
                        selection: $viewModel.statusFilter
                    ) {
                        ForEach(ModelPerformanceStatusFilter.allCases, id: \.self) { filter in
                            Text(filter.displayName).tag(filter)
                        }
                    }
                }

            }
        }
    }
}

private struct MetricsDashboardPerformanceSummaryStrip: View {
    let analysis: ModelPerformanceAnalysis

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                attemptsCard
                successCard
                modelsCard
                fastestCard
            }

            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    attemptsCard
                    successCard
                }
                HStack(spacing: 12) {
                    modelsCard
                    fastestCard
                }
            }
        }
    }

    private var attemptsCard: some View {
        MetricsDashboardPerformanceStatCard(
            icon: "clock.badge.checkmark",
            value: "\(analysis.summary.totalAttempts)",
            label: "metrics.performance.summary.attempts".localized,
            detail: "\(analysis.summary.failedAttempts) " + "metrics.performance.summary.failures".localized,
            tint: .indigo
        )
    }

    private var successCard: some View {
        MetricsDashboardPerformanceStatCard(
            icon: "checkmark.seal.fill",
            value: ModelPerformanceFormatting.percent(
                analysis.summary.totalAttempts == 0
                    ? 0
                    : Double(analysis.summary.successfulAttempts) / Double(analysis.summary.totalAttempts)
            ),
            label: "metrics.performance.summary.success_rate".localized,
            detail: "\(analysis.summary.successfulAttempts)/\(analysis.summary.totalAttempts)",
            tint: .green
        )
    }

    private var modelsCard: some View {
        MetricsDashboardPerformanceStatCard(
            icon: "square.stack.3d.up.fill",
            value: "\(analysis.summary.distinctModels)",
            label: "metrics.performance.summary.models".localized,
            detail: analysis.stage.displayName,
            tint: .orange
        )
    }

    private var fastestCard: some View {
        MetricsDashboardPerformanceStatCard(
            icon: "hare.fill",
            value: ModelPerformanceFormatting.throughput(
                analysis.summary.fastestModelThroughput,
                stage: analysis.stage
            ),
            label: "metrics.performance.summary.fastest".localized,
            detail: analysis.summary.fastestModelDisplayName ?? "metrics.performance.summary.none".localized,
            tint: .mint
        )
    }
}

private struct MetricsDashboardPerformanceStatCard: View {
    let icon: String
    let value: String
    let label: String
    let detail: String
    let tint: Color

    var body: some View {
        DSCard {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(tint)

                Text(value)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())

                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct MetricsDashboardPerformanceLeaderboardSection: View {
    let stage: ModelPerformanceStage
    @Binding var sort: MetricsDashboardPerformanceViewModel.LeaderboardSort
    let entries: [ModelPerformanceLeaderboardEntry]

    var body: some View {
        DSGroup("metrics.performance.leaderboard.title".localized, icon: "list.number") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("metrics.performance.leaderboard.subtitle".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Picker("metrics.performance.sort.title".localized, selection: $sort) {
                        ForEach(MetricsDashboardPerformanceViewModel.LeaderboardSort.allCases, id: \.self) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }

                if entries.isEmpty {
                    Text("metrics.performance.leaderboard.empty".localized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 0) {
                        header

                        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                            Divider()
                            MetricsDashboardPerformanceLeaderboardRow(
                                rank: index + 1,
                                stage: stage,
                                entry: entry
                            )
                        }
                    }
                    .background(
                        AppDesignSystem.Colors.settingsCardBackground(intensity: .regular),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("metrics.performance.leaderboard.header.model".localized)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("metrics.performance.leaderboard.header.success".localized)
                .frame(width: 96, alignment: .trailing)
            Text("metrics.performance.leaderboard.header.speed".localized)
                .frame(width: 120, alignment: .trailing)
            Text("metrics.performance.leaderboard.header.latency".localized)
                .frame(width: 96, alignment: .trailing)
            Text("metrics.performance.leaderboard.header.attempts".localized)
                .frame(width: 80, alignment: .trailing)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

private struct MetricsDashboardPerformanceLeaderboardRow: View {
    let rank: Int
    let stage: ModelPerformanceStage
    let entry: ModelPerformanceLeaderboardEntry

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Text("#\(rank)")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, alignment: .leading)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(entry.identity.modelDisplayName)
                            .font(.body.weight(.semibold))
                            .lineLimit(1)

                        if entry.isBestBalance {
                            Text("metrics.performance.badge.best_balance".localized)
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.green.opacity(0.14), in: Capsule())
                                .foregroundStyle(.green)
                        }
                    }

                    Text(
                        "\(entry.identity.providerDisplayName) • \(entry.identity.runtimeKind.displayName)"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 2) {
                Text(ModelPerformanceFormatting.percent(entry.successRate))
                    .font(.system(.body, design: .monospaced, weight: .semibold))
                Text("\(entry.failedAttempts) " + "metrics.performance.summary.failures".localized)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 96, alignment: .trailing)

            VStack(alignment: .trailing, spacing: 2) {
                Text(ModelPerformanceFormatting.throughput(entry.normalizedThroughput, stage: stage))
                    .font(.system(.body, design: .monospaced, weight: .semibold))
                Text(ModelPerformanceFormatting.secondaryThroughput(entry.secondaryThroughput, stage: stage))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 120, alignment: .trailing)

            Text(ModelPerformanceFormatting.duration(entry.medianWallClockSeconds))
                .font(.system(.body, design: .monospaced, weight: .semibold))
                .frame(width: 96, alignment: .trailing)

            Text("\(entry.attemptCount)")
                .font(.system(.body, design: .monospaced, weight: .semibold))
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private struct MetricsDashboardPerformanceHistorySection: View {
    let stage: ModelPerformanceStage
    let attempts: [ModelPerformanceAttempt]
    let openRecording: (UUID) -> Void

    var body: some View {
        DSGroup("metrics.performance.history.title".localized, icon: "clock.arrow.trianglehead.counterclockwise.rotate.90") {
            VStack(alignment: .leading, spacing: 12) {
                Text("metrics.performance.history.subtitle".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if attempts.isEmpty {
                    Text("metrics.performance.history.empty".localized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 0) {
                        ForEach(attempts) { attempt in
                            MetricsDashboardPerformanceHistoryRow(
                                stage: stage,
                                attempt: attempt,
                                openRecording: openRecording
                            )

                            if attempt.id != attempts.last?.id {
                                Divider()
                            }
                        }
                    }
                    .background(
                        AppDesignSystem.Colors.settingsCardBackground(intensity: .regular),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                }
            }
        }
    }
}

private struct MetricsDashboardPerformanceHistoryRow: View {
    let stage: ModelPerformanceStage
    let attempt: ModelPerformanceAttempt
    let openRecording: (UUID) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(ModelPerformanceFormatting.dateTime(attempt.startedAt))
                    .font(.system(.body, design: .monospaced, weight: .medium))

                Text(attempt.attemptKind.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 160, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(attempt.modelIdentity.modelDisplayName)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)

                Text("\(attempt.modelIdentity.providerDisplayName) • \(attempt.modelIdentity.runtimeKind.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let failureReason = attempt.failureReason?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !failureReason.isEmpty
                {
                    Text(failureReason)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 4) {
                Text(ModelPerformanceFormatting.duration(attempt.wallClockSeconds))
                    .font(.system(.body, design: .monospaced, weight: .semibold))

                Text(ModelPerformanceFormatting.attemptInput(attempt, stage: stage))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(attempt.status.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(attempt.status == .succeeded ? .green : .red)
            }
            .frame(width: 160, alignment: .trailing)

            Button("metrics.performance.history.open_recording".localized) {
                openRecording(attempt.transcriptionID)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private struct MetricsDashboardFilterPicker<SelectionValue: Hashable, Content: View>: View {
    let title: String
    @Binding var selection: SelectionValue
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("", selection: $selection, content: content)
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private enum ModelPerformanceFormatting {
    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        return formatter
    }()

    static func percent(_ value: Double) -> String {
        String(format: "%.0f%%", value * 100.0)
    }

    static func duration(_ seconds: Double) -> String {
        guard seconds > 0 else { return "metrics.performance.summary.none".localized }
        if seconds < 60 {
            return String(format: "%.1fs", seconds)
        }

        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = seconds >= 3_600 ? [.hour, .minute, .second] : [.minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: seconds) ?? String(format: "%.0fs", seconds)
    }

    static func throughput(_ value: Double, stage: ModelPerformanceStage) -> String {
        guard value > 0 else { return "metrics.performance.summary.none".localized }
        switch stage {
        case .transcription:
            return String(format: "%.2fx", value)
        case .postProcessing:
            return bytesPerSecond(value)
        }
    }

    static func secondaryThroughput(_ value: Double, stage: ModelPerformanceStage) -> String {
        guard value > 0 else { return "metrics.performance.summary.none".localized }
        switch stage {
        case .transcription:
            return String(format: "%.2f %@", value, "metrics.performance.units.audio_minutes_per_minute".localized)
        case .postProcessing:
            return String(format: "%.0f %@", value, "metrics.performance.units.characters_per_second".localized)
        }
    }

    static func attemptInput(_ attempt: ModelPerformanceAttempt, stage: ModelPerformanceStage) -> String {
        switch stage {
        case .transcription:
            guard attempt.audioSeconds > 0 else { return "metrics.performance.summary.none".localized }
            return duration(attempt.audioSeconds)
        case .postProcessing:
            guard attempt.inputUTF8Bytes > 0 else { return "metrics.performance.summary.none".localized }
            return bytesCount(attempt.inputUTF8Bytes)
        }
    }

    static func dateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private static func bytesPerSecond(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond >= 1_000_000 {
            return String(format: "%.1f MB/s", bytesPerSecond / 1_000_000)
        }
        if bytesPerSecond >= 1_000 {
            return String(format: "%.1f KB/s", bytesPerSecond / 1_000)
        }
        return String(format: "%.0f B/s", bytesPerSecond)
    }

    private static func bytesCount(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}
