@testable import MeetingAssistantCore
import XCTest

final class MetricsAggregatorTests: XCTestCase {
    func testComputeSummary_TimeSavedUsesRecordedDuration() {
        // Given
        let calendar = Self.gregorianCalendarMondayFirst()

        let monday = Self.date(year: 2_026, month: 2, day: 2, time: (hour: 10, minute: 0), calendar: calendar)
        let tuesday = Self.date(year: 2_026, month: 2, day: 3, time: (hour: 10, minute: 0), calendar: calendar)

        let metadata: [TranscriptionMetadata] = [
            TranscriptionMetadata(
                id: UUID(),
                meetingId: UUID(),
                appName: "Teams",
                appRawValue: "microsoft-teams",
                startTime: monday,
                createdAt: monday,
                previewText: "",
                wordCount: 100,
                language: "pt",
                isPostProcessed: false,
                duration: 60,
                audioFilePath: nil
            ),
            TranscriptionMetadata(
                id: UUID(),
                meetingId: UUID(),
                appName: "Teams",
                appRawValue: "microsoft-teams",
                startTime: tuesday,
                createdAt: tuesday,
                previewText: "",
                wordCount: 50,
                language: "pt",
                isPostProcessed: false,
                duration: 30,
                audioFilePath: nil
            ),
        ]

        // When
        let summary = MetricsAggregator.computeSummary(metadata: metadata, baselineTypingWordsPerMinute: 35)

        // Then
        XCTAssertEqual(summary.sessionsRecorded, 2)
        XCTAssertEqual(summary.wordsDictated, 150)
        XCTAssertEqual(summary.totalRecordedDuration, 90, accuracy: 0.001)
        XCTAssertEqual(summary.estimatedTypingDuration, (150.0 / 35.0) * 60.0, accuracy: 0.001)
        XCTAssertEqual(summary.timeSaved, summary.estimatedTypingDuration - summary.totalRecordedDuration, accuracy: 0.001)
    }

    func testComputeWeekdayBuckets_OrdersByCalendarFirstWeekday() {
        // Given
        var calendar = Self.gregorianCalendarMondayFirst()
        calendar.firstWeekday = 2 // Monday

        let monday = Self.date(year: 2_026, month: 2, day: 2, time: (hour: 10, minute: 0), calendar: calendar) // Monday
        let wednesday = Self.date(year: 2_026, month: 2, day: 2, time: (hour: 10, minute: 0), calendar: calendar)
            .addingTimeInterval(2 * 24 * 60 * 60) // Wednesday

        let metadata: [TranscriptionMetadata] = [
            TranscriptionMetadata(
                id: UUID(),
                meetingId: UUID(),
                appName: "Teams",
                appRawValue: "microsoft-teams",
                startTime: monday,
                createdAt: monday,
                previewText: "",
                wordCount: 10,
                language: "pt",
                isPostProcessed: false,
                duration: 10,
                audioFilePath: nil
            ),
            TranscriptionMetadata(
                id: UUID(),
                meetingId: UUID(),
                appName: "Teams",
                appRawValue: "microsoft-teams",
                startTime: wednesday,
                createdAt: wednesday,
                previewText: "",
                wordCount: 5,
                language: "pt",
                isPostProcessed: false,
                duration: 10,
                audioFilePath: nil
            ),
        ]

        // When
        let buckets = MetricsAggregator.computeWeekdayBuckets(metadata: metadata, calendar: calendar)

        // Then
        XCTAssertEqual(buckets.count, 7)
        XCTAssertEqual(buckets.first?.weekday, 2)

        let mondayBucket = buckets.first { $0.weekday == 2 }
        XCTAssertEqual(mondayBucket?.words, 10)

        let wednesdayBucket = buckets.first { $0.weekday == 4 }
        XCTAssertEqual(wednesdayBucket?.words, 5)
    }

    private static func gregorianCalendarMondayFirst() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        calendar.locale = Locale(identifier: "pt_BR")
        calendar.firstWeekday = 2
        return calendar
    }

    private static func date(year: Int, month: Int, day: Int, time: (hour: Int, minute: Int), calendar: Calendar) -> Date {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = time.hour
        components.minute = time.minute
        return components.date ?? Date(timeIntervalSince1970: 0)
    }
}
