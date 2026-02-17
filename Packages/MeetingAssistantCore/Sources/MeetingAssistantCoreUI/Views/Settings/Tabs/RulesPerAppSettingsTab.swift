import MeetingAssistantCoreCommon
import MeetingAssistantCoreInfrastructure
import SwiftUI

public struct RulesPerAppSettingsTab: View {
    @StateObject private var viewModel: RulesPerAppSettingsViewModel
    @StateObject private var markdownWebTargetsViewModel: WebMarkdownTargetsViewModel
    @State private var expandedBundleIdentifiers = Set<String>()

    public init(settings: AppSettingsStore = .shared) {
        _viewModel = StateObject(wrappedValue: RulesPerAppSettingsViewModel(settings: settings))
        _markdownWebTargetsViewModel = StateObject(wrappedValue: WebMarkdownTargetsViewModel(settings: settings))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.sectionSpacing) {
                appRulesSection
                websitesSection
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(isPresented: $viewModel.showAddAppSheet) {
            addAppSheet
        }
        .sheet(isPresented: $markdownWebTargetsViewModel.showEditor) {
            WebMarkdownTargetEditorSheet(
                target: markdownWebTargetsViewModel.editingTarget,
                onSave: markdownWebTargetsViewModel.handleSave,
                onCancel: { markdownWebTargetsViewModel.showEditor = false }
            )
        }
        .alert(
            "settings.markdown_targets.websites.delete_confirm_title".localized,
            isPresented: $markdownWebTargetsViewModel.showDeleteConfirmation
        ) {
            Button("common.cancel".localized, role: .cancel) {}
            Button("common.delete".localized, role: .destructive) {
                markdownWebTargetsViewModel.executeDelete()
            }
        } message: {
            if let target = markdownWebTargetsViewModel.targetToDelete {
                Text("settings.markdown_targets.websites.delete_confirm_message".localized(with: target.displayName))
            }
        }
    }

    private var appRulesSection: some View {
        MAGroup("settings.rules_per_app.title".localized, icon: "slider.horizontal.3") {
            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing12) {
                Text("settings.rules_per_app.description".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                rulesList

                HStack {
                    Spacer()
                    Button {
                        viewModel.openAddAppSheet()
                    } label: {
                        Label("settings.rules_per_app.add_app".localized, systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }
            }
        }
    }

    private var websitesSection: some View {
        MAGroup("settings.markdown_targets.websites.title".localized, icon: "globe") {
            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
                Text("settings.markdown_targets.websites.desc".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if markdownWebTargetsViewModel.targets.isEmpty {
                    Text("settings.markdown_targets.websites.empty".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(markdownWebTargetsViewModel.targets.enumerated()), id: \.element.id) { index, target in
                            websiteRow(target)

                            if index < markdownWebTargetsViewModel.targets.count - 1 {
                                Divider()
                            }
                        }
                    }
                    .background(MeetingAssistantDesignSystem.Colors.subtleFill2)
                    .clipShape(RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.smallCornerRadius))
                }

                HStack {
                    Spacer()
                    Button {
                        markdownWebTargetsViewModel.addTarget()
                    } label: {
                        Label("settings.markdown_targets.websites.add".localized, systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }
            }
        }
    }

    @ViewBuilder
    private var rulesList: some View {
        if viewModel.resolvedRules.isEmpty {
            Text("settings.rules_per_app.empty".localized)
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(viewModel.resolvedRules.enumerated()), id: \.element.id) { index, resolvedRule in
                    disclosureRow(for: resolvedRule)

                    if index < viewModel.resolvedRules.count - 1 {
                        Divider()
                    }
                }
            }
            .background(MeetingAssistantDesignSystem.Colors.subtleFill2)
            .clipShape(RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.smallCornerRadius))
            
            Spacer()
        }
    }

    private func disclosureRow(for resolvedRule: ResolvedDictationAppRule) -> some View {
        DisclosureGroup(
            isExpanded: expansionBinding(for: resolvedRule.rule.bundleIdentifier),
            content: {
                VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing12) {
                    MAToggleRow(
                        "settings.rules_per_app.markdown.title".localized,
                        description: "settings.rules_per_app.markdown.description".localized,
                        isOn: forceMarkdownBinding(for: resolvedRule.rule.bundleIdentifier)
                    )

                    HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing12) {
                        Text("settings.rules_per_app.language.title".localized)
                            .font(.body)
                            .fontWeight(.regular)

                        Spacer()

                        Picker(
                            "settings.rules_per_app.language.title".localized,
                            selection: outputLanguageBinding(for: resolvedRule.rule.bundleIdentifier)
                        ) {
                            ForEach(DictationOutputLanguage.allCases, id: \.self) { language in
                                Text(language.displayName).tag(language)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }

                    Button(role: .destructive) {
                        viewModel.removeRule(bundleIdentifier: resolvedRule.rule.bundleIdentifier)
                        expandedBundleIdentifiers.remove(resolvedRule.rule.bundleIdentifier)
                    } label: {
                        Label("settings.rules_per_app.remove_app".localized, systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundStyle(MeetingAssistantDesignSystem.Colors.error)
                }
                .padding(.top, MeetingAssistantDesignSystem.Layout.spacing8)
            },
            label: {
                HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
                    AppIconView(
                        bundleIdentifier: resolvedRule.rule.bundleIdentifier,
                        fallbackSystemName: "app.fill",
                        size: 32,
                        cornerRadius: MeetingAssistantDesignSystem.Layout.smallCornerRadius
                    )
                    .padding(.leading, 8)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(resolvedRule.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(resolvedRule.rule.bundleIdentifier)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    appRuleSummary(for: resolvedRule.rule)
                }
            }
        )
        .padding(.horizontal, MeetingAssistantDesignSystem.Layout.spacing12)
        .padding(.vertical, MeetingAssistantDesignSystem.Layout.spacing8)
    }

    private var addAppSheet: some View {
        VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing12) {
            Text("settings.rules_per_app.add_app".localized)
                .font(.title3)
                .fontWeight(.semibold)

            TextField("settings.rules_per_app.search_placeholder".localized, text: $viewModel.searchText)
                .textFieldStyle(.roundedBorder)

            if viewModel.isLoadingAppCatalog {
                VStack {
                    Spacer()
                    ProgressView("settings.rules_per_app.loading_apps".localized)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if viewModel.filteredAppCatalog.isEmpty {
                VStack {
                    Spacer()
                    Text("settings.rules_per_app.no_results".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List(viewModel.filteredAppCatalog) { app in
                    HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing12) {
                        AppIconView(
                            bundleIdentifier: app.bundleIdentifier,
                            fallbackSystemName: "app.fill",
                            size: 32,
                            cornerRadius: MeetingAssistantDesignSystem.Layout.smallCornerRadius
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.displayName)
                                .font(.subheadline)
                            Text(app.bundleIdentifier)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if viewModel.isAppAlreadyConfigured(app) {
                            Text("settings.rules_per_app.added".localized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Button("settings.rules_per_app.add".localized) {
                                viewModel.addAppRule(for: app)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                }
                .listStyle(.inset)
            }

            HStack {
                Spacer()
                Button("common.cancel".localized) {
                    viewModel.dismissAddAppSheet()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding()
        .frame(minWidth: 560, minHeight: 520)
    }

    private func websiteRow(_ target: WebContextTarget) -> some View {
        HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing12) {
            Image(systemName: "globe")
                .font(.title3)
                .foregroundStyle(MeetingAssistantDesignSystem.Colors.iconHighlight)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(target.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(target.urlPatterns.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(browserNames(from: target.browserBundleIdentifiers))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                markdownWebTargetsViewModel.editTarget(target)
            } label: {
                Image(systemName: "pencil")
                    .accessibilityLabel("settings.markdown_targets.websites.edit".localized)
            }
            .buttonStyle(.borderless)
            .controlSize(.regular)

            Button(role: .destructive) {
                markdownWebTargetsViewModel.confirmDelete(target)
            } label: {
                Image(systemName: "trash")
                    .accessibilityLabel("settings.markdown_targets.websites.delete".localized)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(MeetingAssistantDesignSystem.Colors.error)
            .controlSize(.regular)
        }
        .padding(.horizontal, MeetingAssistantDesignSystem.Layout.spacing12)
        .padding(.vertical, MeetingAssistantDesignSystem.Layout.spacing8)
    }

    private func browserNames(from bundleIdentifiers: [String]) -> String {
        let fallbackBundleIdentifiers = viewModel.effectiveWebTargetBrowserBundleIdentifiers

        if bundleIdentifiers.isEmpty && fallbackBundleIdentifiers.isEmpty {
            return "settings.web_targets.browsers.empty".localized
        }

        let effectiveBundleIdentifiers = bundleIdentifiers.isEmpty ? fallbackBundleIdentifiers : bundleIdentifiers
        let names = effectiveBundleIdentifiers
            .map { WebTargetEditorSupport.browserDisplayName(for: $0) }
            .sorted()
        return "settings.markdown_targets.websites.browsers".localized(with: names.joined(separator: ", "))
    }

    private func expansionBinding(for bundleIdentifier: String) -> Binding<Bool> {
        Binding(
            get: { expandedBundleIdentifiers.contains(bundleIdentifier) },
            set: { isExpanded in
                if isExpanded {
                    expandedBundleIdentifiers.insert(bundleIdentifier)
                } else {
                    expandedBundleIdentifiers.remove(bundleIdentifier)
                }
            }
        )
    }

    private func forceMarkdownBinding(for bundleIdentifier: String) -> Binding<Bool> {
        Binding(
            get: {
                viewModel.resolvedRules.first { $0.rule.bundleIdentifier == bundleIdentifier }?.rule.forceMarkdownOutput ?? false
            },
            set: { isEnabled in
                viewModel.setForceMarkdown(isEnabled, for: bundleIdentifier)
            }
        )
    }

    private func outputLanguageBinding(for bundleIdentifier: String) -> Binding<DictationOutputLanguage> {
        Binding(
            get: {
                viewModel.resolvedRules.first { $0.rule.bundleIdentifier == bundleIdentifier }?.rule.outputLanguage ?? .original
            },
            set: { language in
                viewModel.setOutputLanguage(language, for: bundleIdentifier)
            }
        )
    }

    @ViewBuilder
    private func appRuleSummary(for rule: DictationAppRule) -> some View {
        HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
            if rule.forceMarkdownOutput {
                Text("MD")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(MeetingAssistantDesignSystem.Colors.subtleFill2)
                    )
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("settings.rules_per_app.markdown.title".localized)
            }

            if rule.outputLanguage != .original {
                Text(rule.outputLanguage.flagEmoji)
                    .font(.headline)
                    .accessibilityLabel(rule.outputLanguage.localizedName)
            }
        }
    }
}

#Preview {
    RulesPerAppSettingsTab()
}
