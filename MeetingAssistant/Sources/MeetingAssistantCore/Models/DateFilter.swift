import Foundation

/// Filter for transcription date ranges.
public enum DateFilter: String, CaseIterable, Sendable {
    case today
    case yesterday
    case thisWeek
    case lastWeek
    case thisMonth
    case lastMonth
    case allEntries

    /// Display name for the filter option.
    public var displayName: String {
        switch self {
        case .today:
            "Today"
        case .yesterday:
            "Yesterday"
        case .thisWeek:
            "This Week"
        case .lastWeek:
            "Last Week"
        case .thisMonth:
            "This Month"
        case .lastMonth:
            "Last Month"
        case .allEntries:
            "All Entries"
        }
    }

    /// Date range for filtering.
    /// Returns a tuple of (start, end) dates for the filter period.
    public var dateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .today:
            let start = calendar.startOfDay(for: now)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? now
            return (start, end)

        case .yesterday:
            let todayStart = calendar.startOfDay(for: now)
            let start = calendar.date(byAdding: .day, value: -1, to: todayStart) ?? now
            return (start, todayStart)

        case .thisWeek:
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            let start = calendar.date(from: components) ?? now
            let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
            return (start, end)

        case .lastWeek:
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            let thisWeekStart = calendar.date(from: components) ?? now
            let start = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart) ?? now
            return (start, thisWeekStart)

        case .thisMonth:
            let components = calendar.dateComponents([.year, .month], from: now)
            let start = calendar.date(from: components) ?? now
            let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
            return (start, end)

        case .lastMonth:
            let components = calendar.dateComponents([.year, .month], from: now)
            let thisMonthStart = calendar.date(from: components) ?? now
            let start = calendar.date(byAdding: .month, value: -1, to: thisMonthStart) ?? now
            return (start, thisMonthStart)

        case .allEntries:
            return (.distantPast, .distantFuture)
        }
    }

    /// Checks if a date falls within the filter's range.
    public func contains(_ date: Date) -> Bool {
        let range = self.dateRange
        return date >= range.start && date < range.end
    }
}
