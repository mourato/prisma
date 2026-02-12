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
        _urlPatternsText = State(initialValue: (target?.urlPatterns ?? defaultURLPatterns(for: initialApp)).joined(separator: "\n"))
        _selectedBrowsers = State(initialValue: Set(target?.browserBundleIdentifiers ?? defaultBrowsers))
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

            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
                Text("settings.meetings.web_targets.name_label".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("", text: $displayName)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
                Text("settings.meetings.web_targets.url_label".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("settings.meetings.web_targets.url_desc".localized)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                TextEditor(text: $urlPatternsText)
                    .font(.caption.monospaced())
                    .frame(minHeight: 80)
                    .padding(6)
                    .background(MeetingAssistantDesignSystem.Colors.subtleFill2)
                    .clipShape(RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.smallCornerRadius))
            }

            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
                Text("settings.meetings.web_targets.browser_label".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(browserOptions, id: \.bundleIdentifier) { option in
                    MAToggleRow(
                        option.name,
                        isOn: binding(for: option.bundleIdentifier)
                    )
                }
            }

            HStack {
                Spacer()
                Button("common.cancel".localized) {
                    onCancel()
                }
                .buttonStyle(.bordered)

                Button("common.save".localized) {
                    onSave(buildTarget())
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
            }
        }
        .padding()
        .frame(minWidth: 420)
        .onChange(of: selectedApp) { _, newValue in
            if target == nil {
                displayName = newValue.displayName
                if urlPatternsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    urlPatternsText = defaultURLPatterns(for: newValue).joined(separator: "\n")
                }
            }
        }
    }

    private var canSave: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !parsedURLPatterns.isEmpty
            && !selectedBrowsers.isEmpty
    }

    private var parsedURLPatterns: [String] {
        urlPatternsText
            .replacingOccurrences(of: ",", with: "\n")
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
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

    private func binding(for bundleIdentifier: String) -> Binding<Bool> {
        Binding(
            get: { selectedBrowsers.contains(bundleIdentifier) },
            set: { isSelected in
                if isSelected {
                    selectedBrowsers.insert(bundleIdentifier)
                } else {
                    selectedBrowsers.remove(bundleIdentifier)
                }
            }
        )
    }

    private var availableApps: [MeetingApp] {
        MeetingApp.allCases.filter { app in
            app != .manualMeeting && app != .importedFile && app != .unknown
        }
    }

    private var browserOptions: [BrowserOption] {
        [
            BrowserOption(name: "Safari", bundleIdentifier: "com.apple.Safari"),
            BrowserOption(name: "Google Chrome", bundleIdentifier: "com.google.Chrome"),
            BrowserOption(name: "Microsoft Edge", bundleIdentifier: "com.microsoft.edgemac"),
        ]
    }

    private static let defaultBrowsers: [String] = [
        "com.apple.Safari",
        "com.google.Chrome",
        "com.microsoft.edgemac",
    ]

    private func defaultURLPatterns(for app: MeetingApp) -> [String] {
        AppSettingsStore.defaultWebMeetingTargets
            .first(where: { $0.app == app })
            .map { $0.urlPatterns }
            ?? []
    }

    private struct BrowserOption {
        let name: String
        let bundleIdentifier: String
    }
}

#Preview {
    WebMeetingTargetEditorSheet(
        target: AppSettingsStore.defaultWebMeetingTargets.first,
        onSave: { _ in },
        onCancel: {}
    )
}
