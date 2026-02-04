import Charts
import Combine
import SwiftUI

public struct MetricsDashboardSettingsTab: View {
    @StateObject private var viewModel = MetricsDashboardViewModel()

    @MainActor
    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SettingsDesignSystem.Layout.sectionSpacing) {
                if let errorMessage = viewModel.errorMessage {
                    SettingsCard {
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

                    weekdayPeaksSection
                    hourlyPeaksSection
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
        SettingsCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("metrics.title".localized)
                    .font(.title2.weight(.semibold))

                Text(formattedTimeSaved)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(SettingsDesignSystem.Colors.aiGradient)
                    .accessibilityLabel(formattedTimeSavedAccessibility)

                Text("metrics.subtitle".localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var filtersSection: some View {
        SettingsGroup("metrics.filters.title".localized, icon: "calendar") {
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
                .frame(width: 200)
            }
        }
    }

    private var summarySection: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 16)], spacing: 16) {
            MetricStatCard(
                icon: "mic.fill",
                title: "metrics.summary.sessions".localized,
                value: Formatters.formattedNumber(viewModel.summary.sessionsRecorded),
                detail: "metrics.summary.sessions_detail".localized,
                tint: .purple
            )

            MetricStatCard(
                icon: "text.alignleft",
                title: "metrics.summary.words".localized,
                value: Formatters.formattedNumber(viewModel.summary.wordsDictated),
                detail: "metrics.summary.words_detail".localized,
                tint: SettingsDesignSystem.Colors.accent
            )

            MetricStatCard(
                icon: "clock.fill",
                title: "metrics.summary.time_saved".localized,
                value: formattedDuration(viewModel.summary.timeSaved),
                detail: "metrics.summary.time_saved_detail".localized,
                tint: .orange
            )
        }
    }

    private var weekdayPeaksSection: some View {
        SettingsGroup("metrics.peaks.weekday.title".localized, icon: "chart.bar.xaxis") {
            Chart(viewModel.weekdayBuckets) { bucket in
                BarMark(
                    x: .value("weekday", weekdayLabel(for: bucket.weekday)),
                    y: .value("words", bucket.words)
                )
                .foregroundStyle(SettingsDesignSystem.Colors.accent.gradient)
                .cornerRadius(4)
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 220)
        }
    }

    private var hourlyPeaksSection: some View {
        SettingsGroup("metrics.peaks.hourly.title".localized, icon: "clock.arrow.circlepath") {
            Chart(viewModel.hourlyBuckets) { bucket in
                BarMark(
                    x: .value("hour", bucket.hour),
                    y: .value("count", bucket.count)
                )
                .foregroundStyle(SettingsDesignSystem.Colors.accent.gradient)
            }
            .chartXScale(domain: 0...23)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 220)
        }
    }

    private var emptyStateSection: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 6) {
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
        SettingsCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(tint.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 4) {
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
        }
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
