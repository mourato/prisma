import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

public struct WebMeetingTargetEditorSheet: View {
    private let target: WebMeetingTarget?
    private let onSave: (WebMeetingTarget) -> Void
    private let onCancel: () -> Void

    @State private var selectedApp: MeetingApp
    @State private var displayName: String
    @State private var urlPatternsText: String
    @State private var selectedBrowsers: Set<String>

    public init(
        target: WebMeetingTarget?,
        onSave: @escaping (WebMeetingTarget) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.target = target
        self.onSave = onSave
        self.onCancel = onCancel

        let initialApp = target?.app ?? .googleMeet
        _selectedApp = State(initialValue: initialApp)
        _displayName = State(initialValue: target?.displayName ?? initialApp.displayName)
        _urlPatternsText = State(initialValue: (target?.urlPatterns ?? Self.defaultURLPatterns(for: initialApp)).joined(separator: "\n"))
        _selectedBrowsers = State(initialValue: Set(target?.browserBundleIdentifiers ?? WebTargetEditorSupport.defaultBrowserBundleIdentifiers))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing12) {
            Text("settings.meetings.web_targets.editor_title".localized)
                .font(.headline)

            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
                Text("settings.meetings.web_targets.app_label".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("", selection: $selectedApp) {
                    ForEach(availableApps, id: \.self) { app in
                        Text(app.displayName).tag(app)
                    }
                }
                .pickerStyle(.menu)
            }

            WebTargetEditorFields(
                nameLabelKey: "settings.meetings.web_targets.name_label",
                urlLabelKey: "settings.meetings.web_targets.url_label",
                urlDescriptionKey: "settings.meetings.web_targets.url_desc",
                browserLabelKey: "settings.meetings.web_targets.browser_label",
                canSave: canSave,
                onSave: { onSave(buildTarget()) },
                onCancel: onCancel,
                displayName: $displayName,
                urlPatternsText: $urlPatternsText,
                selectedBrowsers: $selectedBrowsers
            )
        }
        .padding()
        .frame(minWidth: 420)
        .onChange(of: selectedApp) { _, newValue in
            if target == nil {
                displayName = newValue.displayName
                if urlPatternsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    urlPatternsText = Self.defaultURLPatterns(for: newValue).joined(separator: "\n")
                }
            }
        }
    }

    private var canSave: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !parsedURLPatterns.isEmpty
    }

    private var parsedURLPatterns: [String] {
        WebTargetEditorSupport.parseURLPatterns(from: urlPatternsText)
    }

    private func buildTarget() -> WebMeetingTarget {
        WebMeetingTarget(
            id: target?.id ?? UUID(),
            app: selectedApp,
            displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            urlPatterns: parsedURLPatterns,
            browserBundleIdentifiers: Array(selectedBrowsers)
        )
    }

    private var availableApps: [MeetingApp] {
        MeetingApp.allCases.filter { app in
            app != .manualMeeting && app != .importedFile && app != .unknown
        }
    }

    private static func defaultURLPatterns(for app: MeetingApp) -> [String] {
        AppSettingsStore.defaultWebMeetingTargets
            .first(where: { $0.app == app })
            .map { $0.urlPatterns }
            ?? []
    }

}

#Preview {
    WebMeetingTargetEditorSheet(
        target: AppSettingsStore.defaultWebMeetingTargets.first,
        onSave: { _ in },
        onCancel: {}
    )
}
