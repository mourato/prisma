import Charts
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

struct MetricsDashboardIndexPage: View {
    @ObservedObject var viewModel: MetricsDashboardViewModel
    let openMoreInsights: () -> Void
    let openPerformance: () -> Void
    let openEventDetail: (MeetingCalendarEventSnapshot) -> Void

    var body: some View {
        SettingsScrollableContent {
            SettingsSectionHeader(
                title: "settings.section.metrics".localized,
                description: "metrics.hero.subtitle".localized(
                    with: MetricsDashboardFormatters.formattedNumber(viewModel.summary.wordsDictated),
                    viewModel.summary.sessionsRecorded
                )
            )

            MetricsDashboardLoadErrorSection(
                errorMessage: viewModel.errorMessage,
                onRetry: { await viewModel.load() }
            )

            MetricsDashboardActivitySection(viewModel: viewModel)
            MetricsDashboardMoreInsightsLinkSection(openMoreInsights: openMoreInsights)
            MetricsDashboardPerformanceLinkSection(openPerformance: openPerformance)
            if viewModel.isMeetingTranscriptionEnabled {
                MetricsDashboardUpcomingEventsSection(
                    viewModel: viewModel,
                    onOpenEventDetail: openEventDetail
                )
            }
        }
    }
}

struct MetricsDashboardMoreInsightsPage: View {
    @ObservedObject var viewModel: MetricsDashboardViewModel

    var body: some View {
        SettingsScrollableContent {
            MetricsDashboardLoadErrorSection(
                errorMessage: viewModel.errorMessage,
                onRetry: { await viewModel.load() }
            )

            MetricsDashboardFiltersSection(viewModel: viewModel)

            if viewModel.summary.sessionsRecorded == 0, !viewModel.isLoading {
                MAEmptyStateView(
                    iconName: "chart.bar.xaxis",
                    title: "metrics.empty.title".localized,
                    message: "metrics.empty.subtitle".localized
                )
            } else {
                MetricsDashboardSummarySection(viewModel: viewModel)
                MetricsDashboardAppStartFrequencySection(viewModel: viewModel)
                MetricsDashboardHourlyPeaksSection(viewModel: viewModel)
                MetricsDashboardWeekdayPeaksSection(viewModel: viewModel)
            }
        }
    }
}

struct MetricsDashboardEventDetailPage: View {
    let event: MeetingCalendarEventSnapshot
    @ObservedObject var viewModel: MetricsDashboardViewModel

    @State private var notesDraft: MeetingNotesContent = .empty
    @State private var isAttendeesPopoverPresented = false
    @State private var notesAutosaveTask: Task<Void, Never>?
    @State private var hasLoadedInitialNotes = false

    var body: some View {
        SettingsScrollableContent {
            SettingsSectionHeader(
                title: eventTitle,
                description: "metrics.calendar.detail.subtitle".localized
            )

            DSGroup("metrics.calendar.detail.metadata.title".localized, icon: "calendar") {
                VStack(alignment: .leading, spacing: 12) {
                    Label(
                        MetricsDashboardFormatters.calendarEventIntervalLabel(
                            startDate: event.startDate,
                            endDate: event.endDate
                        ),
                        systemImage: "calendar.badge.clock"
                    )
                    .font(.subheadline)

                    if let location = event.location?.trimmingCharacters(in: .whitespacesAndNewlines), !location.isEmpty {
                        Label(location, systemImage: "mappin.and.ellipse")
                            .font(.subheadline)
                    }

                    Button {
                        isAttendeesPopoverPresented.toggle()
                    } label: {
                        Label(
                            "metrics.calendar.detail.attendees.count".localized(with: event.attendees.count),
                            systemImage: "person.2"
                        )
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .popover(isPresented: $isAttendeesPopoverPresented, arrowEdge: .bottom) {
                        attendeesPopoverContent
                    }
                }
            }

            DSGroup("metrics.calendar.detail.notes.title".localized, icon: "note.text") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("metrics.calendar.detail.notes.subtitle".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    MeetingNotesMarkdownEditor(
                        content: $notesDraft,
                        documentId: "calendar-event-notes-\(event.eventIdentifier)"
                    )
                    .frame(minHeight: 280)
                }
            }
        }
        .onAppear {
            loadPersistedNotesIfNeeded()
        }
        .onChange(of: event.eventIdentifier) { _, _ in
            hasLoadedInitialNotes = false
            loadPersistedNotesIfNeeded()
        }
        .onChange(of: notesDraft) { _, _ in
            scheduleNotesAutosave()
        }
        .onDisappear {
            flushNotesAutosave()
        }
    }

    private var eventTitle: String {
        event.trimmedTitle.isEmpty ? "metrics.calendar.event.untitled".localized : event.trimmedTitle
    }

    private var attendeesPopoverContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("metrics.calendar.detail.attendees.title".localized)
                .font(.headline)

            if event.attendees.isEmpty {
                Text("metrics.calendar.detail.attendees.empty".localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(event.attendees.enumerated()), id: \.offset) { _, attendee in
                            Text(attendee)
                                .font(.subheadline)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .settingsScrollEdgeEffect()
                .subtleScrollbars()
                .frame(maxHeight: 220)
            }
        }
        .padding(AppDesignSystem.Layout.cardPadding)
        .frame(width: 320, alignment: .leading)
    }

    private func loadPersistedNotesIfNeeded() {
        guard !hasLoadedInitialNotes else { return }
        hasLoadedInitialNotes = true
        notesDraft = viewModel.calendarEventNotesContent(for: event)
    }

    private func scheduleNotesAutosave() {
        notesAutosaveTask?.cancel()
        let pendingNotes = notesDraft
        notesAutosaveTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                viewModel.updateCalendarEventNotes(pendingNotes, for: event)
            }
        }
    }

    private func flushNotesAutosave() {
        notesAutosaveTask?.cancel()
        notesAutosaveTask = nil
        viewModel.updateCalendarEventNotes(notesDraft, for: event)
    }
}

private struct MetricsDashboardLoadErrorSection: View {
    let errorMessage: String?
    let onRetry: @MainActor @Sendable () async -> Void

    var body: some View {
        if let errorMessage {
            SettingsStateBlock(
                kind: .warning,
                title: "common.error".localized,
                message: errorMessage,
                actionTitle: "settings.service.verify".localized
            ) {
                Task {
                    await onRetry()
                }
            }
        }
    }
}

private struct MetricsDashboardMoreInsightsLinkSection: View {
    let openMoreInsights: () -> Void

    var body: some View {
        DSGroup {
            SettingsDrillDownButtonRow(
                title: "metrics.more_insights.title".localized,
                accessibilityHint: "metrics.more_insights.accessibility_hint".localized
            ) {
                openMoreInsights()
            }
        }
    }
}

private struct MetricsDashboardPerformanceLinkSection: View {
    let openPerformance: () -> Void

    var body: some View {
        DSGroup {
            SettingsDrillDownButtonRow(
                title: "metrics.performance.link.title".localized,
                accessibilityHint: "metrics.performance.link.accessibility_hint".localized
            ) {
                openPerformance()
            }
        }
    }
}

struct MetricsDashboardPerformancePage: View {
    @StateObject private var viewModel: MetricsDashboardPerformanceViewModel
    let openRecording: (UUID) -> Void

    init(
        storage: StorageService = FileSystemStorageService.shared,
        openRecording: @escaping (UUID) -> Void = { _ in }
    ) {
        _viewModel = StateObject(wrappedValue: MetricsDashboardPerformanceViewModel(storage: storage))
        self.openRecording = openRecording
    }

    var body: some View {
        SettingsScrollableContent {
            SettingsSectionHeader(
                title: "metrics.performance.title".localized,
                description: "metrics.performance.subtitle".localized
            )

            if let errorMessage = viewModel.errorMessage {
                SettingsStateBlock(kind: .warning, title: "common.error".localized, message: errorMessage) {
                    Task {
                        await viewModel.load()
                    }
                }
            }

            if viewModel.isLoading, viewModel.analysis.summary.totalAttempts == 0 {
                ProgressView()
                    .tint(AppDesignSystem.Colors.accent)
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                MetricsDashboardPerformanceWorkspace(
                    viewModel: viewModel,
                    openRecording: openRecording
                )
            }
        }
        .task {
            await viewModel.load()
        }
    }
}

struct MetricsDashboardPerformanceRecordingPage: View {
    let recordingID: UUID

    @State private var transcription: Transcription?
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let storage: StorageService

    init(
        recordingID: UUID,
        storage: StorageService = FileSystemStorageService.shared
    ) {
        self.recordingID = recordingID
        self.storage = storage
    }

    var body: some View {
        SettingsScrollableContent {
            SettingsSectionHeader(
                title: transcription?.meeting.preferredTitle ?? "metrics.performance.recording.title".localized,
                description: "metrics.performance.recording.subtitle".localized
            )

            if let errorMessage {
                SettingsStateBlock(kind: .warning, title: "common.error".localized, message: errorMessage) {
                    Task {
                        await loadRecording()
                    }
                }
            }

            if isLoading {
                ProgressView()
                    .tint(AppDesignSystem.Colors.accent)
                    .frame(maxWidth: .infinity, minHeight: 180)
            } else if let transcription {
                recordingSnapshotSection(transcription)
                transcriptPreviewSection(transcription)
            } else {
                MAEmptyStateView(
                    iconName: "doc.text.magnifyingglass",
                    title: "metrics.performance.recording.empty.title".localized,
                    message: "metrics.performance.recording.empty.subtitle".localized
                )
            }
        }
        .task(id: recordingID) {
            await loadRecording()
        }
    }

    private func recordingSnapshotSection(_ transcription: Transcription) -> some View {
        DSGroup("metrics.performance.recording.snapshot".localized, icon: "doc.text") {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                GridRow {
                    recordingMetric(
                        title: "metrics.performance.recording.capture".localized,
                        value: transcription.capturePurpose.displayName
                    )
                    recordingMetric(
                        title: "metrics.performance.recording.source".localized,
                        value: transcription.meeting.appName
                    )
                }

                GridRow {
                    recordingMetric(
                        title: "metrics.performance.recording.transcription_model".localized,
                        value: transcription.modelName
                    )
                    recordingMetric(
                        title: "metrics.performance.recording.transcription_time".localized,
                        value: formatDuration(transcription.transcriptionDuration)
                    )
                }

                GridRow {
                    recordingMetric(
                        title: "metrics.performance.recording.post_processing_model".localized,
                        value: transcription.postProcessingModel ?? "metrics.performance.summary.none".localized
                    )
                    recordingMetric(
                        title: "metrics.performance.recording.post_processing_time".localized,
                        value: formatDuration(transcription.postProcessingDuration)
                    )
                }

                GridRow {
                    recordingMetric(
                        title: "metrics.performance.recording.recorded_at".localized,
                        value: formattedDate(transcription.createdAt)
                    )
                    recordingMetric(
                        title: "metrics.performance.recording.input_source".localized,
                        value: transcription.inputSource ?? "metrics.performance.summary.none".localized
                    )
                }
            }

            if let failureReason = transcription.postProcessingFailureReason?.trimmingCharacters(in: .whitespacesAndNewlines),
               !failureReason.isEmpty
            {
                Divider()
                Text(failureReason)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private func transcriptPreviewSection(_ transcription: Transcription) -> some View {
        DSGroup("metrics.performance.recording.preview".localized, icon: "text.alignleft") {
            Text(transcription.processedContent ?? transcription.text)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func recordingMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func loadRecording() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            transcription = try await storage.loadTranscription(by: recordingID)
        } catch {
            transcription = nil
            errorMessage = "metrics.error.load".localized
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        guard seconds > 0 else { return "metrics.performance.summary.none".localized }
        if seconds < 60 {
            return String(format: "%.1fs", seconds)
        }

        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = seconds >= 3_600 ? [.hour, .minute, .second] : [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: seconds) ?? String(format: "%.0fs", seconds)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

private struct MetricsDashboardFiltersSection: View {
    @ObservedObject var viewModel: MetricsDashboardViewModel

    var body: some View {
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
}

private struct MetricsDashboardSummarySection: View {
    @ObservedObject var viewModel: MetricsDashboardViewModel

    var body: some View {
        ViewThatFits(in: .horizontal) {
            Grid(horizontalSpacing: 16, verticalSpacing: 16) {
                GridRow {
                    sessionCard
                    wordsCard
                    wpmCard
                    keystrokesCard
                }
            }
            .frame(maxWidth: .infinity)

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
            value: MetricsDashboardFormatters.formattedNumber(viewModel.summary.sessionsRecorded),
            detail: "metrics.summary.sessions_recorded_detail".localized,
            tint: .purple
        )
    }

    private var wordsCard: some View {
        MetricStatCard(
            icon: "text.alignleft",
            title: "metrics.summary.words_dictated".localized,
            value: MetricsDashboardFormatters.formattedNumber(viewModel.summary.wordsDictated),
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
            value: MetricsDashboardFormatters.formattedNumber(viewModel.summary.keystrokesSaved),
            detail: "metrics.summary.keystrokes_detail".localized,
            tint: .orange
        )
    }
}

private struct MetricsDashboardHourlyPeaksSection: View {
    @ObservedObject var viewModel: MetricsDashboardViewModel

    var body: some View {
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
}

private struct MetricsDashboardAppStartFrequencySection: View {
    @ObservedObject var viewModel: MetricsDashboardViewModel

    private var totalSessions: Int {
        viewModel.appUsageBuckets.reduce(0) { partialResult, bucket in
            partialResult + bucket.sessions
        }
    }

    var body: some View {
        DSGroup("metrics.apps.frequency.title".localized, icon: "app.badge") {
            VStack(alignment: .leading, spacing: 12) {
                Text("metrics.apps.frequency.subtitle".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if viewModel.appUsageBuckets.isEmpty {
                    MAEmptyStateView(
                        iconName: "chart.pie",
                        title: "metrics.empty.title".localized,
                        message: "metrics.empty.subtitle".localized,
                        emphasis: .compact
                    )
                } else {
                    ZStack {
                        Chart(viewModel.appUsageBuckets) { bucket in
                            SectorMark(
                                angle: .value("count", bucket.sessions),
                                innerRadius: .ratio(0.62),
                                angularInset: 2
                            )
                            .foregroundStyle(color(for: bucket))
                        }
                        .chartLegend(.hidden)

                        VStack(spacing: 4) {
                            Text(MetricsDashboardFormatters.formattedNumber(totalSessions))
                                .font(.title3.weight(.semibold))
                            Text("metrics.apps.frequency.total".localized)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(height: max(AppDesignSystem.Layout.chartHeight, 220))

                    VStack(spacing: 8) {
                        ForEach(viewModel.appUsageBuckets) { bucket in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(color(for: bucket))
                                    .frame(width: 10, height: 10)

                                Text(bucket.appName)
                                    .font(.caption)
                                    .lineLimit(1)

                                Spacer(minLength: 12)

                                Text(MetricsDashboardFormatters.formattedNumber(bucket.sessions))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)

                                Text(percentText(for: bucket.sessions))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 42, alignment: .trailing)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
        }
    }

    private func percentText(for sessions: Int) -> String {
        guard totalSessions > 0 else { return "0%" }
        let ratio = Double(sessions) / Double(totalSessions)
        return ratio.formatted(.percent.precision(.fractionLength(0)))
    }

    private func color(for bucket: MetricsAppUsageBucket) -> Color {
        if bucket.isOther {
            return AppDesignSystem.Colors.subtleFill
        }

        let app = MeetingApp(rawValue: bucket.appRawValue) ?? .unknown
        return app.color
    }
}

private struct MetricsDashboardWeekdayPeaksSection: View {
    @ObservedObject var viewModel: MetricsDashboardViewModel

    var body: some View {
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
}

#Preview("Dashboard More Insights") {
    MetricsDashboardMoreInsightsPage(viewModel: MetricsDashboardViewModel())
        .frame(width: 720, height: 780)
}
