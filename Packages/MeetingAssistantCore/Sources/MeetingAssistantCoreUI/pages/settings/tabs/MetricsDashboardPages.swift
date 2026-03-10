import Charts
import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain
import SwiftUI

struct MetricsDashboardIndexPage: View {
    @ObservedObject var viewModel: MetricsDashboardViewModel
    let openMoreInsights: () -> Void

    var body: some View {
        SettingsScrollableContent {
            SettingsSectionHeader(
                title: "settings.section.metrics".localized,
                description: "metrics.hero.subtitle".localized(
                    with: MetricsDashboardFormatters.formattedNumber(viewModel.summary.wordsDictated),
                    viewModel.summary.sessionsRecorded
                )
            )

            MetricsDashboardLoadErrorSection(
                errorMessage: viewModel.errorMessage,
                onRetry: { await viewModel.load() }
            )

            MetricsDashboardActivitySection(viewModel: viewModel)
            MetricsDashboardMoreInsightsLinkSection(openMoreInsights: openMoreInsights)
            MetricsDashboardUpcomingEventsSection(viewModel: viewModel)
        }
    }
}

struct MetricsDashboardMoreInsightsPage: View {
    @ObservedObject var viewModel: MetricsDashboardViewModel

    var body: some View {
        SettingsScrollableContent {
            MetricsDashboardLoadErrorSection(
                errorMessage: viewModel.errorMessage,
                onRetry: { await viewModel.load() }
            )

            MetricsDashboardFiltersSection(viewModel: viewModel)

            if viewModel.summary.sessionsRecorded == 0, !viewModel.isLoading {
                MAEmptyStateView(
                    iconName: "chart.bar.xaxis",
                    title: "metrics.empty.title".localized,
                    message: "metrics.empty.subtitle".localized
                )
            } else {
                MetricsDashboardSummarySection(viewModel: viewModel)
                MetricsDashboardHourlyPeaksSection(viewModel: viewModel)
                MetricsDashboardWeekdayPeaksSection(viewModel: viewModel)
            }
        }
    }
}

private struct MetricsDashboardLoadErrorSection: View {
    let errorMessage: String?
    let onRetry: @MainActor @Sendable () async -> Void

    var body: some View {
        if let errorMessage {
            SettingsStateBlock(
                kind: .warning,
                title: "common.error".localized,
                message: errorMessage,
                actionTitle: "settings.service.verify".localized
            ) {
                Task {
                    await onRetry()
                }
            }
        }
    }
}

private struct MetricsDashboardMoreInsightsLinkSection: View {
    let openMoreInsights: () -> Void

    var body: some View {
        DSCard {
            SettingsDrillDownButtonRow(
                title: "metrics.more_insights.title".localized,
                accessibilityHint: "metrics.more_insights.accessibility_hint".localized
            ) {
                openMoreInsights()
            }
        }
    }
}

private struct MetricsDashboardFiltersSection: View {
    @ObservedObject var viewModel: MetricsDashboardViewModel

    var body: some View {
        DSGroup("metrics.filters.title".localized, icon: "calendar") {
            HStack {
                Text("metrics.filters.period".localized)
                    .font(.body)

                Spacer()

                Picker("", selection: $viewModel.dateFilter) {
                    ForEach(DateFilter.allCases, id: \.self) { filter in
                        Text(filter.displayName).tag(filter)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
        }
    }
}

private struct MetricsDashboardSummarySection: View {
    @ObservedObject var viewModel: MetricsDashboardViewModel

    var body: some View {
        ViewThatFits(in: .horizontal) {
            Grid(horizontalSpacing: 16, verticalSpacing: 16) {
                GridRow {
                    sessionCard
                    wordsCard
                    wpmCard
                    keystrokesCard
                }
            }
            .frame(maxWidth: .infinity)

            Grid(horizontalSpacing: 16, verticalSpacing: 16) {
                GridRow {
                    sessionCard
                    wordsCard
                }
                GridRow {
                    wpmCard
                    keystrokesCard
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var sessionCard: some View {
        MetricStatCard(
            icon: "mic.fill",
            title: "metrics.summary.sessions_recorded".localized,
            value: MetricsDashboardFormatters.formattedNumber(viewModel.summary.sessionsRecorded),
            detail: "metrics.summary.sessions_recorded_detail".localized,
            tint: .purple
        )
    }

    private var wordsCard: some View {
        MetricStatCard(
            icon: "text.alignleft",
            title: "metrics.summary.words_dictated".localized,
            value: MetricsDashboardFormatters.formattedNumber(viewModel.summary.wordsDictated),
            detail: "metrics.summary.words_dictated_detail".localized,
            tint: AppDesignSystem.Colors.accent
        )
    }

    private var wpmCard: some View {
        MetricStatCard(
            icon: "bolt.fill",
            title: "metrics.summary.wpm".localized,
            value: String(format: "%.0f", viewModel.summary.wordsPerMinute),
            detail: "metrics.summary.wpm_detail".localized,
            tint: .blue
        )
    }

    private var keystrokesCard: some View {
        MetricStatCard(
            icon: "keyboard",
            title: "metrics.summary.keystrokes".localized,
            value: MetricsDashboardFormatters.formattedNumber(viewModel.summary.keystrokesSaved),
            detail: "metrics.summary.keystrokes_detail".localized,
            tint: .orange
        )
    }
}

private struct MetricsDashboardHourlyPeaksSection: View {
    @ObservedObject var viewModel: MetricsDashboardViewModel

    var body: some View {
        DSGroup("metrics.peaks.hourly.title".localized, icon: "clock.arrow.circlepath") {
            Chart(viewModel.hourlyBuckets) { bucket in
                BarMark(
                    x: .value("hour", bucket.hour),
                    y: .value("count", bucket.count)
                )
                .foregroundStyle(AppDesignSystem.Colors.accent.gradient)
            }
            .chartXScale(domain: 0...23)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: AppDesignSystem.Layout.chartHeight)
        }
    }
}

private struct MetricsDashboardWeekdayPeaksSection: View {
    @ObservedObject var viewModel: MetricsDashboardViewModel

    var body: some View {
        DSGroup("metrics.peaks.weekday.title".localized, icon: "chart.bar.xaxis") {
            Chart(viewModel.weekdayBuckets) { bucket in
                BarMark(
                    x: .value("weekday", weekdayLabel(for: bucket.weekday)),
                    y: .value("words", bucket.words)
                )
                .foregroundStyle(AppDesignSystem.Colors.accent.gradient)
                .cornerRadius(AppDesignSystem.Layout.tinyCornerRadius)
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: AppDesignSystem.Layout.chartHeight)
        }
    }

    private func weekdayLabel(for weekday: Int) -> String {
        let symbols = weekdaySymbols
        guard weekday >= 1, weekday <= symbols.count else { return "\(weekday)" }
        return symbols[weekday - 1]
    }

    private var weekdaySymbols: [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        return formatter.shortWeekdaySymbols
    }
}

#Preview("Dashboard More Insights") {
    MetricsDashboardMoreInsightsPage(viewModel: MetricsDashboardViewModel())
        .frame(width: 720, height: 780)
}
