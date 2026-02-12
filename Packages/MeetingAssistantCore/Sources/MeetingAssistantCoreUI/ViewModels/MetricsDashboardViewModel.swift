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
    private var hasLoaded = false

    private static let DEFAULT_BASELINE_WPM: Double = 35
    private static var cachedMetadata: [TranscriptionMetadata]?

    public init(storage: StorageService = FileSystemStorageService.shared) {
        self.storage = storage
        summary = MetricsAggregator.computeSummary(
            metadata: [],
            baselineTypingWordsPerMinute: Self.DEFAULT_BASELINE_WPM
        )

        if let cachedMetadata = Self.cachedMetadata {
            allMetadata = cachedMetadata
            hasLoaded = true
            isLoading = false
            recompute()
        }
    }

    public func load() async {
        guard !hasLoaded else { return }
        await refresh(showLoadingIndicator: true)
    }

    public func refresh() async {
        await refresh(showLoadingIndicator: false)
    }

    public func handleTranscriptionSaved(_ notification: Notification) async {
        let transcriptionID = (notification.userInfo?[AppNotifications.UserInfoKey.transcriptionId] as? String)
            .flatMap(UUID.init(uuidString:))

        guard let transcriptionID else {
            await refresh(showLoadingIndicator: false)
            return
        }

        do {
            guard let transcription = try await storage.loadTranscription(by: transcriptionID) else {
                await refresh(showLoadingIndicator: false)
                return
            }

            upsertMetadata(from: transcription)
            Self.cachedMetadata = allMetadata
            hasLoaded = true
            isLoading = false
            recompute()
        } catch {
            logger.error("Failed to update metadata incrementally: \(error.localizedDescription)")
            await refresh(showLoadingIndicator: false)
        }
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
            Self.cachedMetadata = allMetadata
            hasLoaded = true
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
        dailyBuckets = MetricsAggregator.computeDailyBuckets(metadata: allMetadata)
    }

    private func upsertMetadata(from transcription: Transcription) {
        let metadata = TranscriptionMetadata(
            id: transcription.id,
            meetingId: transcription.meeting.id,
            appName: transcription.meeting.appName,
            appRawValue: transcription.meeting.app.rawValue,
            appBundleIdentifier: transcription.meeting.appBundleIdentifier,
            startTime: transcription.meeting.startTime,
            createdAt: transcription.createdAt,
            previewText: String(transcription.text.prefix(100)),
            wordCount: transcription.wordCount,
            language: transcription.language,
            isPostProcessed: transcription.isPostProcessed,
            duration: transcription.meeting.duration,
            audioFilePath: transcription.meeting.audioFilePath,
            inputSource: transcription.inputSource
        )

        if let existingIndex = allMetadata.firstIndex(where: { $0.id == metadata.id }) {
            allMetadata[existingIndex] = metadata
        } else {
            allMetadata.append(metadata)
        }
    }
}
