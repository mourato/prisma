import Charts
import Combine
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

public struct MetricsDashboardSettingsTab: View {
    @StateObject private var viewModel = MetricsDashboardViewModel()

    @MainActor
    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.sectionSpacing) {
                if let errorMessage = viewModel.errorMessage {
                    MACard {
                        Text(errorMessage)
                            .foregroundStyle(.secondary)
                    }
                }

                heroSection
                filtersSection

                if viewModel.summary.sessionsRecorded == 0, !viewModel.isLoading {
                    emptyStateSection
                } else {
                    summarySection

                    hourlyPeaksSection
                    weekdayPeaksSection
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task {
            await viewModel.load()
        }
        .onReceive(NotificationCenter.default.publisher(for: .meetingAssistantTranscriptionSaved)) { _ in
            Task { await viewModel.refresh() }
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
            Text("metrics.hero.title".localized(with: formattedTimeSaved))
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            Text("metrics.hero.subtitle".localized(with: Formatters.formattedNumber(viewModel.summary.wordsDictated), viewModel.summary.sessionsRecorded))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(MeetingAssistantDesignSystem.Layout.heroPadding)
        .background(MeetingAssistantDesignSystem.Colors.dashboardHeroGradient)
        .clipShape(RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.heroCornerRadius, style: .continuous))
        .shadow(
            color: MeetingAssistantDesignSystem.Colors.accent.opacity(0.2),
            radius: MeetingAssistantDesignSystem.Layout.shadowRadius,
            x: MeetingAssistantDesignSystem.Layout.shadowX,
            y: MeetingAssistantDesignSystem.Layout.shadowY
        )
    }

    private var filtersSection: some View {
        MAGroup("metrics.filters.title".localized, icon: "calendar") {
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
                .frame(width: MeetingAssistantDesignSystem.Layout.maxPickerWidth)
            }
        }
    }

    private var summarySection: some View {
        ViewThatFits(in: .horizontal) {
            // Wide: 4 columns, 1 row
            Grid(horizontalSpacing: 16, verticalSpacing: 16) {
                GridRow {
                    sessionCard
                    wordsCard
                    wpmCard
                    keystrokesCard
                }
            }
            .frame(maxWidth: .infinity)

            // Narrow/Minimum: 2 columns, 2 rows
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
            value: Formatters.formattedNumber(viewModel.summary.sessionsRecorded),
            detail: "metrics.summary.sessions_recorded_detail".localized,
            tint: .purple
        )
    }

    private var wordsCard: some View {
        MetricStatCard(
            icon: "text.alignleft",
            title: "metrics.summary.words_dictated".localized,
            value: Formatters.formattedNumber(viewModel.summary.wordsDictated),
            detail: "metrics.summary.words_dictated_detail".localized,
            tint: MeetingAssistantDesignSystem.Colors.accent
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
            value: Formatters.formattedNumber(viewModel.summary.keystrokesSaved),
            detail: "metrics.summary.keystrokes_detail".localized,
            tint: .orange
        )
    }

    private var weekdayPeaksSection: some View {
        MAGroup("metrics.peaks.weekday.title".localized, icon: "chart.bar.xaxis") {
            Chart(viewModel.weekdayBuckets) { bucket in
                BarMark(
                    x: .value("weekday", weekdayLabel(for: bucket.weekday)),
                    y: .value("words", bucket.words)
                )
                .foregroundStyle(MeetingAssistantDesignSystem.Colors.accent.gradient)
                .cornerRadius(MeetingAssistantDesignSystem.Layout.tinyCornerRadius)
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: MeetingAssistantDesignSystem.Layout.chartHeight)
        }
    }

    private var hourlyPeaksSection: some View {
        MAGroup("metrics.peaks.hourly.title".localized, icon: "clock.arrow.circlepath") {
            Chart(viewModel.hourlyBuckets) { bucket in
                BarMark(
                    x: .value("hour", bucket.hour),
                    y: .value("count", bucket.count)
                )
                .foregroundStyle(MeetingAssistantDesignSystem.Colors.accent.gradient)
            }
            .chartXScale(domain: 0...23)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: MeetingAssistantDesignSystem.Layout.chartHeight)
        }
    }

    private var emptyStateSection: some View {
        MACard {
            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing6) {
                Text("metrics.empty.title".localized)
                    .font(.headline)
                Text("metrics.empty.subtitle".localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var formattedTimeSaved: String {
        formattedDuration(viewModel.summary.timeSaved)
    }

    private var formattedTimeSavedAccessibility: String {
        formattedDuration(viewModel.summary.timeSaved, style: .full)
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

    private func formattedDuration(_ interval: TimeInterval, style: DateComponentsFormatter.UnitsStyle = .abbreviated) -> String {
        Formatters.formattedDuration(interval, style: style, fallback: "–")
    }
}

private struct MetricStatCard: View {
    let icon: String
    let title: String
    let value: String
    let detail: String
    let tint: Color

    var body: some View {
        MACard {
            HStack(alignment: .top, spacing: MeetingAssistantDesignSystem.Layout.spacing12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.smallCornerRadius, style: .continuous)
                            .fill(tint.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing4) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    Text(value)
                        .font(.title3.weight(.semibold))

                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    MetricsDashboardSettingsTab()
}

private enum Formatters {
    static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()

    static func formattedNumber(_ value: Int) -> String {
        numberFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func formattedDuration(
        _ interval: TimeInterval,
        style: DateComponentsFormatter.UnitsStyle,
        fallback: String
    ) -> String {
        guard interval > 0 else { return fallback }
        let formatter = DateComponentsFormatter()
        formatter.maximumUnitCount = 2
        formatter.unitsStyle = style
        formatter.allowedUnits = interval >= 3_600 ? [.hour, .minute] : [.minute, .second]
        return formatter.string(from: interval) ?? fallback
    }
}
