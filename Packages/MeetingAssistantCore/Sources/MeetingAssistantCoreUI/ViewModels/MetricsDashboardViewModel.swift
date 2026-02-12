import Foundation
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import OSLog

@MainActor
public final class MetricsDashboardViewModel: ObservableObject {
    @Published public private(set) var summary: MetricsDashboardSummary
    @Published public private(set) var weekdayBuckets: [MetricsWeekdayBucket] = []
    @Published public private(set) var hourlyBuckets: [MetricsHourlyBucket] = []
    @Published public private(set) var dailyBuckets: [MetricsDailyBucket] = []

    @Published public var dateFilter: DateFilter = .allEntries {
        didSet {
            recompute()
        }
    }

    @Published public private(set) var isLoading = true
    @Published public private(set) var errorMessage: String?

    private let storage: StorageService
    private let logger = Logger(subsystem: "MeetingAssistant", category: "MetricsDashboardViewModel")
    private var allMetadata: [TranscriptionMetadata] = []
    private var isRefreshing = false

    private static let DEFAULT_BASELINE_WPM: Double = 35

    public init(storage: StorageService = FileSystemStorageService.shared) {
        self.storage = storage
        summary = MetricsAggregator.computeSummary(
            metadata: [],
            baselineTypingWordsPerMinute: Self.DEFAULT_BASELINE_WPM
        )
    }

    public func load() async {
        await refresh(showLoadingIndicator: true)
    }

    public func refresh() async {
        await refresh(showLoadingIndicator: false)
    }

    private func refresh(showLoadingIndicator: Bool) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        if showLoadingIndicator {
            isLoading = true
        }
        errorMessage = nil

        do {
            allMetadata = try await storage.loadAllMetadata()
            recompute()
        } catch {
            logger.error("Failed to load metadata: \(error.localizedDescription)")
            errorMessage = "metrics.error.load".localized
        }

        if showLoadingIndicator {
            isLoading = false
        }
    }

    private func recompute() {
        let filtered = allMetadata.filter { dateFilter.contains($0.startTime) }
        summary = MetricsAggregator.computeSummary(
            metadata: filtered,
            baselineTypingWordsPerMinute: Self.DEFAULT_BASELINE_WPM
        )
        weekdayBuckets = MetricsAggregator.computeWeekdayBuckets(metadata: filtered)
        hourlyBuckets = MetricsAggregator.computeHourlyBuckets(metadata: filtered)
        dailyBuckets = MetricsAggregator.computeDailyBuckets(metadata: filtered)
    }
}
