import Foundation
import OSLog

@MainActor
public final class MetricsDashboardViewModel: ObservableObject {
    @Published public private(set) var summary: MetricsDashboardSummary
    @Published public private(set) var weekdayBuckets: [MetricsWeekdayBucket] = []

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

    private let baselineTypingWordsPerMinute: Double = 35

    public init(storage: StorageService = FileSystemStorageService.shared) {
        self.storage = storage
        summary = MetricsAggregator.computeSummary(
            metadata: [],
            baselineTypingWordsPerMinute: baselineTypingWordsPerMinute
        )
    }

    public func load() async {
        isLoading = true
        errorMessage = nil

        do {
            allMetadata = try await storage.loadAllMetadata()
            recompute()
        } catch {
            logger.error("Failed to load metadata: \(error.localizedDescription)")
            errorMessage = "metrics.error.load".localized
        }

        isLoading = false
    }

    private func recompute() {
        let filtered = allMetadata.filter { dateFilter.contains($0.startTime) }
        summary = MetricsAggregator.computeSummary(
            metadata: filtered,
            baselineTypingWordsPerMinute: baselineTypingWordsPerMinute
        )
        weekdayBuckets = MetricsAggregator.computeWeekdayBuckets(metadata: filtered)
    }
}
