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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @MainActor
    public init() {}

    public var body: some View {
        SettingsScrollableContent {
            SettingsSectionHeader(
                title: "settings.section.metrics".localized,
                description: "metrics.hero.subtitle".localized(
                    with: Formatters.formattedNumber(viewModel.summary.wordsDictated),
                    viewModel.summary.sessionsRecorded
                )
            )

            if let errorMessage = viewModel.errorMessage {
                SettingsStateBlock(
                    kind: .warning,
                    title: "common.error".localized,
                    message: errorMessage,
                    actionTitle: "settings.service.verify".localized
                ) {
                    Task { await viewModel.load() }
                }
            }

            activityHeatmapSection
            upcomingEventsSection
            filtersSection

            if viewModel.summary.sessionsRecorded == 0, !viewModel.isLoading {
                emptyStateSection
            } else {
                summarySection
                hourlyPeaksSection
                weekdayPeaksSection
            }
        }
        .task {
            await viewModel.load()
        }
        .onReceive(NotificationCenter.default.publisher(for: .meetingAssistantTranscriptionSaved)) { notification in
            Task { await viewModel.handleTranscriptionSaved(notification) }
        }
    }

    private var filtersSection: some View {
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

    private var upcomingEventsSection: some View {
        DSGroup("metrics.calendar.upcoming.title".localized, icon: "calendar.badge.clock") {
            VStack(alignment: .leading, spacing: 12) {
                Text("metrics.calendar.upcoming.subtitle".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if viewModel.isLoadingCalendar {
                    SettingsStateBlock(
                        kind: .loading,
                        title: "metrics.calendar.loading.title".localized,
                        message: "metrics.calendar.loading.message".localized
                    )
                } else if !viewModel.calendarPermissionState.isAuthorized {
                    SettingsStateBlock(
                        kind: .warning,
                        title: "metrics.calendar.permission.title".localized,
                        message: calendarPermissionMessage,
                        actionTitle: calendarPermissionActionTitle
                    ) {
                        if viewModel.calendarPermissionState == .notDetermined {
                            Task { await viewModel.requestCalendarAccess() }
                        } else {
                            viewModel.openCalendarSettings()
                        }
                    }
                } else if viewModel.upcomingEvents.isEmpty {
                    SettingsStateBlock(
                        kind: .empty,
                        title: "metrics.calendar.empty.title".localized,
                        message: "metrics.calendar.empty.message".localized
                    )
                } else {
                    ForEach(viewModel.upcomingEvents, id: \.eventIdentifier) { event in
                        UpcomingCalendarEventRow(
                            event: event,
                            isRecording: viewModel.isRecording,
                            isLinked: viewModel.isLinkedEvent(event)
                        ) {
                            viewModel.linkCalendarEvent(event)
                        } onClear: {
                            viewModel.clearLinkedCalendarEvent()
                        }
                    }
                }
            }
        }
    }

    private var activityHeatmapSection: some View {
        DSGroup("metrics.activity.title".localized, icon: "calendar.badge.clock") {
            VStack(alignment: .leading, spacing: 8) {
                Text("metrics.activity.subtitle".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if viewModel.isLoading {
                    ProgressView()
                        .tint(AppDesignSystem.Colors.accent)
                        .frame(maxWidth: .infinity, minHeight: ActivityHeatmap.scrollHeight)
                        .padding(.vertical, ActivityHeatmap.verticalPadding)
                } else if viewModel.dailyBuckets.isEmpty {
                    SettingsStateBlock(
                        kind: .empty,
                        title: "metrics.empty.title".localized,
                        message: "metrics.empty.subtitle".localized
                    )
                } else {
                    HStack(alignment: .top, spacing: ActivityHeatmap.weekdayToGridSpacing) {
                        weekdayLegendColumn

                        ScrollViewReader { proxy in
                            ScrollView(.horizontal, showsIndicators: false) {
                                VStack(alignment: .leading, spacing: ActivityHeatmap.monthToGridSpacing) {
                                    monthHeaderRow

                                    HStack(alignment: .top, spacing: ActivityHeatmap.spacing) {
                                        ForEach(heatmapWeekColumns) { column in
                                            VStack(spacing: ActivityHeatmap.spacing) {
                                                ForEach(Array(column.days.enumerated()), id: \.offset) { _, bucket in
                                                    if let bucket {
                                                        activitySquare(for: bucket)
                                                    } else {
                                                        heatmapPlaceholder
                                                    }
                                                }
                                            }
                                            .id("\(ActivityHeatmap.weekColumnPrefix)-\(column.id)")
                                        }
                                        Color.clear
                                            .frame(width: 1, height: 1)
                                            .id(ActivityHeatmap.latestAnchorID)
                                    }
                                }
                                .padding(.vertical, ActivityHeatmap.verticalPadding)
                            }
                            .frame(height: ActivityHeatmap.scrollHeight)
                            .onAppear {
                                scrollToLatest(in: proxy, animated: true)
                            }
                            .onReceive(viewModel.$dailyBuckets.dropFirst()) { _ in
                                scrollToLatest(in: proxy, animated: false)
                            }
                        }
                    }
                    heatmapLegend
                }
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
            value: Formatters.formattedNumber(viewModel.summary.keystrokesSaved),
            detail: "metrics.summary.keystrokes_detail".localized,
            tint: .orange
        )
    }

    private var weekdayPeaksSection: some View {
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

    private var hourlyPeaksSection: some View {
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

    private var emptyStateSection: some View {
        SettingsStateBlock(
            kind: .empty,
            title: "metrics.empty.title".localized,
            message: "metrics.empty.subtitle".localized
        )
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

    private var activityCalendar: Calendar {
        Calendar.current
    }

    private var heatmapWeekColumns: [ActivityHeatmapWeekColumn] {
        let buckets = viewModel.dailyBuckets.sorted { $0.date < $1.date }
        guard let firstDate = buckets.first?.date, let lastDate = buckets.last?.date else {
            return []
        }

        let rangeStart = activityCalendar.startOfDay(for: firstDate)
        let rangeEnd = activityCalendar.startOfDay(for: lastDate)
        let firstWeekStart = activityCalendar.dateInterval(of: .weekOfYear, for: rangeStart)?.start ?? rangeStart
        let lastWeekStart = activityCalendar.dateInterval(of: .weekOfYear, for: rangeEnd)?.start ?? rangeEnd

        let bucketsByDate = Dictionary(uniqueKeysWithValues: buckets.map {
            (activityCalendar.startOfDay(for: $0.date), $0)
        })

        var columns: [ActivityHeatmapWeekColumn] = []
        var weekStart = firstWeekStart
        var index = 0

        while weekStart <= lastWeekStart {
            let days: [MetricsDailyBucket?] = (0..<7).map { offset in
                guard let day = activityCalendar.date(byAdding: .day, value: offset, to: weekStart) else {
                    return nil
                }

                guard day >= rangeStart, day <= rangeEnd else {
                    return nil
                }

                return bucketsByDate[day] ?? MetricsDailyBucket(date: day, words: 0)
            }

            columns.append(
                ActivityHeatmapWeekColumn(
                    id: index,
                    monthLabel: monthLabelForWeek(startingAt: weekStart, rangeStart: rangeStart, rangeEnd: rangeEnd),
                    days: days
                )
            )

            guard let nextWeek = activityCalendar.date(byAdding: .weekOfYear, value: 1, to: weekStart) else {
                break
            }

            weekStart = nextWeek
            index += 1
        }

        return columns
    }

    private var orderedWeekdayNumbers: [Int] {
        guard (1...7).contains(activityCalendar.firstWeekday) else {
            return Array(1...7)
        }

        return (0..<7).map { offset in
            ((activityCalendar.firstWeekday - 1 + offset) % 7) + 1
        }
    }

    private func weekdayLegendText(for weekdayNumber: Int) -> String {
        let visibleWeekdays: Set<Int> = [2, 4, 6]
        guard visibleWeekdays.contains(weekdayNumber) else {
            return ""
        }

        let symbols = weekdaySymbols
        guard weekdayNumber >= 1, weekdayNumber <= symbols.count else {
            return ""
        }

        return symbols[weekdayNumber - 1]
    }

    private var weekdayLegendColumn: some View {
        VStack(alignment: .trailing, spacing: ActivityHeatmap.spacing) {
            Spacer()
                .frame(height: ActivityHeatmap.monthHeaderHeight + ActivityHeatmap.monthToGridSpacing)

            ForEach(orderedWeekdayNumbers, id: \.self) { weekdayNumber in
                Text(weekdayLegendText(for: weekdayNumber))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .frame(height: ActivityHeatmap.squareSize)
            }
        }
        .frame(width: ActivityHeatmap.weekdayLabelWidth, alignment: .trailing)
    }

    private var monthHeaderRow: some View {
        ZStack(alignment: .leading) {
            Color.clear
                .frame(width: max(heatmapGridWidth, 1), height: ActivityHeatmap.monthHeaderHeight)

            ForEach(monthMarkers) { marker in
                Text(marker.label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: true, vertical: false)
                    .offset(x: marker.xOffset)
            }
        }
        .frame(height: ActivityHeatmap.monthHeaderHeight, alignment: .bottomLeading)
    }

    private var monthMarkers: [ActivityHeatmapMonthMarker] {
        let rawMarkers: [ActivityHeatmapMonthMarker] = heatmapWeekColumns.compactMap { column in
            guard let monthLabel = column.monthLabel else {
                return nil
            }

            let xOffset = CGFloat(column.id) * (ActivityHeatmap.squareSize + ActivityHeatmap.spacing)
            return ActivityHeatmapMonthMarker(id: column.id, label: monthLabel, xOffset: xOffset)
        }

        return ActivityHeatmap.resolveVisibleMonthMarkers(rawMarkers)
    }

    private var heatmapGridWidth: CGFloat {
        guard !heatmapWeekColumns.isEmpty else {
            return 0
        }

        let columns = CGFloat(heatmapWeekColumns.count)
        return columns * ActivityHeatmap.squareSize + (columns - 1) * ActivityHeatmap.spacing
    }

    private func monthLabelForWeek(startingAt weekStart: Date, rangeStart: Date, rangeEnd: Date) -> String? {
        for offset in 0..<7 {
            guard let date = activityCalendar.date(byAdding: .day, value: offset, to: weekStart) else {
                continue
            }

            guard date >= rangeStart, date <= rangeEnd else {
                continue
            }

            if activityCalendar.component(.day, from: date) == 1 {
                return localizedMonthLabel(for: date)
            }
        }

        if ActivityHeatmap.shouldShowRangeStartMonthLabel(
            for: weekStart,
            rangeStart: rangeStart,
            calendar: activityCalendar
        ) {
            return localizedMonthLabel(for: rangeStart)
        }

        return nil
    }

    private func localizedMonthLabel(for date: Date) -> String {
        let monthName = Self.activityMonthNameFormatter.string(from: date)
        return String(monthName.prefix(3))
    }

    private var maxDailyWords: Int {
        viewModel.dailyBuckets.map(\.words).max() ?? 0
    }

    private func activitySquare(for bucket: MetricsDailyBucket) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(ActivityHeatmap.baseColor)

            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(heatmapColor(for: bucket.words))
        }
        .frame(width: ActivityHeatmap.squareSize, height: ActivityHeatmap.squareSize)
        .overlay(
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .stroke(
                    bucket.words > 0 && bucket.words == maxDailyWords
                        ? AppDesignSystem.Colors.accent
                        : Color.secondary.opacity(0.2),
                    lineWidth: bucket.words > 0 && bucket.words == maxDailyWords ? 1 : 0.5
                )
        )
        .help(heatmapTooltip(for: bucket))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(heatmapTooltip(for: bucket)))
    }

    private var heatmapLegend: some View {
        HStack(spacing: ActivityHeatmap.legendSpacing) {
            legendItem(
                color: AppDesignSystem.Colors.accent.opacity(0),
                label: "metrics.activity.legend.none".localized
            )
            legendItem(
                color: AppDesignSystem.Colors.accent,
                label: "metrics.activity.legend.most".localized
            )
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: ActivityHeatmap.legendSwatchCornerRadius, style: .continuous)
                .fill(color)
                .frame(width: ActivityHeatmap.legendSwatchSize, height: ActivityHeatmap.legendSwatchSize)
                .overlay(
                    RoundedRectangle(cornerRadius: ActivityHeatmap.legendSwatchCornerRadius, style: .continuous)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
            Text(label)
        }
    }

    private func heatmapColor(for words: Int) -> Color {
        guard maxDailyWords > 0 else {
            return AppDesignSystem.Colors.accent.opacity(0)
        }

        let normalized = max(0, min(1, Double(words) / Double(maxDailyWords)))
        return AppDesignSystem.Colors.accent.opacity(normalized)
    }

    private func heatmapTooltip(for bucket: MetricsDailyBucket) -> String {
        let dayText = Self.activityDateFormatter.string(from: bucket.date)
        let wordsText = Formatters.formattedNumber(bucket.words)
        return "metrics.activity.tooltip.words_on_date".localized(with: wordsText, dayText)
    }

    private var calendarPermissionMessage: String {
        switch viewModel.calendarPermissionState {
        case .notDetermined:
            "metrics.calendar.permission.request".localized
        case .denied, .restricted:
            "metrics.calendar.permission.denied".localized
        case .granted:
            ""
        }
    }

    private var calendarPermissionActionTitle: String {
        viewModel.calendarPermissionState == .notDetermined
            ? "metrics.calendar.permission.action_request".localized
            : "metrics.calendar.permission.action_open_settings".localized
    }

    private func scrollToLatest(in proxy: ScrollViewProxy, animated: Bool) {
        DispatchQueue.main.async {
            if animated, !reduceMotion {
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(ActivityHeatmap.latestAnchorID, anchor: .trailing)
                }
            } else {
                proxy.scrollTo(ActivityHeatmap.latestAnchorID, anchor: .trailing)
            }
        }
    }

    private var heatmapPlaceholder: some View {
        RoundedRectangle(cornerRadius: AppDesignSystem.Layout.tinyCornerRadius, style: .continuous)
            .fill(Color.clear)
            .frame(width: ActivityHeatmap.squareSize, height: ActivityHeatmap.squareSize)
            .opacity(0)
            .accessibilityHidden(true)
    }

    private static let activityDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter
    }()

    private static let activityMonthNameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMM")
        return formatter
    }()
}

private struct UpcomingCalendarEventRow: View {
    let event: MeetingCalendarEventSnapshot
    let isRecording: Bool
    let isLinked: Bool
    let onLink: () -> Void
    let onClear: () -> Void

    var body: some View {
        DSCard {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.trimmedTitle.isEmpty ? "metrics.calendar.event.untitled".localized : event.trimmedTitle)
                        .font(.subheadline.weight(.semibold))

                    Text(timeLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let location = event.location?.trimmingCharacters(in: .whitespacesAndNewlines), !location.isEmpty {
                        Label(location, systemImage: "mappin.and.ellipse")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)

                if isLinked {
                    VStack(alignment: .trailing, spacing: 8) {
                        Label("metrics.calendar.event.linked".localized, systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppDesignSystem.Colors.success)

                        if isRecording {
                            Button("metrics.calendar.event.clear".localized) {
                                onClear()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                } else if isRecording {
                    Button("metrics.calendar.event.use_for_recording".localized) {
                        onLink()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var timeLabel: String {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: event.startDate, to: event.endDate)
    }
}

private struct ActivityHeatmapWeekColumn: Identifiable {
    let id: Int
    let monthLabel: String?
    let days: [MetricsDailyBucket?]
}

struct ActivityHeatmapMonthMarker: Identifiable, Equatable {
    let id: Int
    let label: String
    let xOffset: CGFloat
}

private struct MetricStatCard: View {
    let icon: String
    let title: String
    let value: String
    let detail: String
    let tint: Color

    var body: some View {
        DSCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: AppDesignSystem.Layout.smallCornerRadius, style: .continuous)
                            .fill(tint.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    Text(value)
                        .font(.title3.weight(.semibold))
                        .contentTransition(.numericText())

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

enum ActivityHeatmap {
    static let squareSize: CGFloat = 10
    static let spacing: CGFloat = 2
    static let verticalPadding: CGFloat = 8
    static let baseColor = AppDesignSystem.Colors.subtleFill
    static let monthHeaderHeight: CGFloat = 14
    static let monthToGridSpacing: CGFloat = 6
    static let estimatedMonthLabelWidth: CGFloat = 24
    static let monthLabelMinimumSpacing: CGFloat = 6
    static let weekdayLabelWidth: CGFloat = 24
    static let weekdayToGridSpacing: CGFloat = 8
    static let weekColumnPrefix = "heatmap-week"
    static let latestAnchorID = "heatmap-latest-anchor"

    static var gridHeight: CGFloat {
        squareSize * 7 + spacing * 6
    }

    static var scrollHeight: CGFloat {
        monthHeaderHeight + monthToGridSpacing + gridHeight + verticalPadding * 2
    }

    static func resolveVisibleMonthMarkers(
        _ markers: [ActivityHeatmapMonthMarker],
        estimatedLabelWidth: CGFloat = estimatedMonthLabelWidth,
        minimumSpacing: CGFloat = monthLabelMinimumSpacing
    ) -> [ActivityHeatmapMonthMarker] {
        var visibleMarkers: [ActivityHeatmapMonthMarker] = []
        var lastTrailingEdge = -CGFloat.greatestFiniteMagnitude

        for marker in markers.sorted(by: { $0.xOffset < $1.xOffset }) {
            guard marker.xOffset >= lastTrailingEdge + minimumSpacing else {
                continue
            }

            visibleMarkers.append(marker)
            lastTrailingEdge = marker.xOffset + estimatedLabelWidth
        }

        return visibleMarkers
    }

    static func shouldShowRangeStartMonthLabel(
        for weekStart: Date,
        rangeStart: Date,
        calendar: Calendar
    ) -> Bool {
        calendar.dateInterval(of: .weekOfYear, for: rangeStart)?.start == weekStart
    }

    static let legendSpacing: CGFloat = 12
    static let legendSwatchSize: CGFloat = 12
    static let legendSwatchCornerRadius: CGFloat = 3
}
