import Foundation

public struct MetricsDashboardSummary: Equatable, Sendable {
    public let sessionsRecorded: Int
    public let wordsDictated: Int
    public let totalRecordedDuration: TimeInterval
    public let estimatedTypingDuration: TimeInterval
    public let timeSaved: TimeInterval
    public let baselineTypingWordsPerMinute: Double

    public init(
        sessionsRecorded: Int,
        wordsDictated: Int,
        totalRecordedDuration: TimeInterval,
        estimatedTypingDuration: TimeInterval,
        timeSaved: TimeInterval,
        baselineTypingWordsPerMinute: Double
    ) {
        self.sessionsRecorded = sessionsRecorded
        self.wordsDictated = wordsDictated
        self.totalRecordedDuration = totalRecordedDuration
        self.estimatedTypingDuration = estimatedTypingDuration
        self.timeSaved = timeSaved
        self.baselineTypingWordsPerMinute = baselineTypingWordsPerMinute
    }
}

public struct MetricsWeekdayBucket: Equatable, Identifiable, Sendable {
    public let weekday: Int
    public let words: Int

    public var id: Int { weekday }

    public init(weekday: Int, words: Int) {
        self.weekday = weekday
        self.words = words
    }
}

public struct MetricsHourlyBucket: Equatable, Identifiable, Sendable {
    public let hour: Int
    public let count: Int

    public var id: Int { hour }

    public init(hour: Int, count: Int) {
        self.hour = hour
        self.count = count
    }
}

public enum MetricsAggregator {
    public static func computeSummary(
        metadata: [TranscriptionMetadata],
        baselineTypingWordsPerMinute: Double
    ) -> MetricsDashboardSummary {
        let sessionsRecorded = metadata.count
        let wordsDictated = metadata.reduce(0) { $0 + $1.wordCount }
        let totalRecordedDuration = metadata.reduce(0.0) { $0 + $1.duration }

        let estimatedTypingDuration: TimeInterval = if baselineTypingWordsPerMinute > 0 {
            (Double(wordsDictated) / baselineTypingWordsPerMinute) * 60.0
        } else {
            0
        }

        let timeSaved = max(estimatedTypingDuration - totalRecordedDuration, 0)

        return MetricsDashboardSummary(
            sessionsRecorded: sessionsRecorded,
            wordsDictated: wordsDictated,
            totalRecordedDuration: totalRecordedDuration,
            estimatedTypingDuration: estimatedTypingDuration,
            timeSaved: timeSaved,
            baselineTypingWordsPerMinute: baselineTypingWordsPerMinute
        )
    }

    public static func computeWeekdayBuckets(
        metadata: [TranscriptionMetadata],
        calendar: Calendar = .current
    ) -> [MetricsWeekdayBucket] {
        var wordCounts: [Int: Int] = [:]
        wordCounts.reserveCapacity(7)

        for item in metadata {
            let weekday = calendar.component(.weekday, from: item.startTime)
            wordCounts[weekday, default: 0] += item.wordCount
        }

        let orderedWeekdays = orderedWeekdays(calendar: calendar)
        return orderedWeekdays.map { weekday in
            MetricsWeekdayBucket(weekday: weekday, words: wordCounts[weekday, default: 0])
        }
    }

    private static func orderedWeekdays(calendar: Calendar) -> [Int] {
        guard (1...7).contains(calendar.firstWeekday) else {
            return Array(1...7)
        }

        return (0..<7).map { offset in
            ((calendar.firstWeekday - 1 + offset) % 7) + 1
        }
    }

    public static func computeHourlyBuckets(
        metadata: [TranscriptionMetadata],
        calendar: Calendar = .current
    ) -> [MetricsHourlyBucket] {
        var hourCounts: [Int: Int] = [:]
        hourCounts.reserveCapacity(24)

        for item in metadata {
            let hour = calendar.component(.hour, from: item.startTime)
            hourCounts[hour, default: 0] += 1
        }

        return (0..<24).map { hour in
            MetricsHourlyBucket(hour: hour, count: hourCounts[hour, default: 0])
        }
    }
}
