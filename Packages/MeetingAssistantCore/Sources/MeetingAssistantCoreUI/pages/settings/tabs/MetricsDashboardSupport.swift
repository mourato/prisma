import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain
import SwiftUI

struct ActivityHeatmapWeekColumn: Identifiable {
    let id: Int
    let monthLabel: String?
    let days: [MetricsDailyBucket?]
}

struct ActivityHeatmapMonthMarker: Identifiable, Equatable {
    let id: Int
    let label: String
    let xOffset: CGFloat
}

enum MetricsDashboardFormatters {
    static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()

    static let calendarIntervalFormatter: DateIntervalFormatter = {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static func formattedNumber(_ value: Int) -> String {
        numberFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func calendarEventIntervalLabel(startDate: Date, endDate: Date) -> String {
        calendarIntervalFormatter.string(from: startDate, to: endDate)
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

        for marker in markers {
            guard let lastMarker = visibleMarkers.last else {
                visibleMarkers.append(marker)
                continue
            }

            let lastMarkerEnd = lastMarker.xOffset + estimatedLabelWidth
            if marker.xOffset - lastMarkerEnd >= minimumSpacing {
                visibleMarkers.append(marker)
            }
        }

        return visibleMarkers
    }

    static func shouldShowRangeStartMonthLabel(
        for weekStart: Date,
        rangeStart: Date,
        calendar: Calendar
    ) -> Bool {
        guard calendar.component(.day, from: rangeStart) != 1 else {
            return false
        }

        let rangeStartWeek = calendar.dateInterval(of: .weekOfYear, for: rangeStart)?.start
        return rangeStartWeek == weekStart
    }

    static let legendSpacing: CGFloat = 12
    static let legendSwatchSize: CGFloat = 10
    static let legendSwatchCornerRadius: CGFloat = 2
}
