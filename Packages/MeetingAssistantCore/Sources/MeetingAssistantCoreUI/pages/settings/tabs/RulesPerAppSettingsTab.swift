import MeetingAssistantCoreCommon
import MeetingAssistantCoreInfrastructure
import SwiftUI

public struct RulesPerAppSettingsTab: View {
    @StateObject private var viewModel: RulesPerAppSettingsViewModel
    @StateObject private var markdownWebTargetsViewModel: WebMarkdownTargetsViewModel

    public init(settings: AppSettingsStore = .shared) {
        _viewModel = StateObject(wrappedValue: RulesPerAppSettingsViewModel(settings: settings))
        _markdownWebTargetsViewModel = StateObject(wrappedValue: WebMarkdownTargetsViewModel(settings: settings))
    }

    public var body: some View {
        SettingsScrollableContent {
            SettingsSectionHeader(
                title: "settings.section.rules_per_app".localized,
                description: "settings.rules_per_app.description".localized
            )
            appRulesSection
            websitesSection
        }
        .sheet(isPresented: $viewModel.showAddAppSheet) {
            addAppSheet
        }
        .sheet(isPresented: $viewModel.showRuleEditor) {
            if let editingRule = editingAppRule {
                AppRuleEditorSheet(
                    resolvedRule: editingRule,
                    onSave: { forceMarkdownOutput, outputLanguage, customPromptInstructions in
                        viewModel.saveRule(
                            bundleIdentifier: editingRule.rule.bundleIdentifier,
                            forceMarkdownOutput: forceMarkdownOutput,
                            outputLanguage: outputLanguage,
                            customPromptInstructions: customPromptInstructions
                        )
                    },
                    onCancel: viewModel.dismissRuleEditor
                )
            }
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
        DSGroup("settings.rules_per_app.title".localized, icon: "slider.horizontal.3") {
            VStack(alignment: .leading, spacing: 12) {
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
        DSGroup("settings.markdown_targets.websites.title".localized, icon: "globe") {
            VStack(alignment: .leading, spacing: 8) {
                Text("settings.markdown_targets.websites.desc".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                SettingsInlineList(
                    items: markdownWebTargetsViewModel.targets,
                    emptyText: "settings.markdown_targets.websites.empty".localized
                ) { target in
                    websiteRow(target)
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
                    appRow(for: resolvedRule)

                    if index < viewModel.resolvedRules.count - 1 {
                        Divider()
                    }
                }
            }
            .background(AppDesignSystem.Colors.subtleFill2)
            .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.Layout.smallCornerRadius))

            Spacer()
        }
    }

    private func appRow(for resolvedRule: ResolvedDictationAppRule) -> some View {
        HStack(spacing: 12) {
            AppIconView(
                bundleIdentifier: resolvedRule.rule.bundleIdentifier,
                fallbackSystemName: "app.fill",
                size: 32,
                cornerRadius: AppDesignSystem.Layout.smallCornerRadius
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

            SettingsContextMenuButton(accessibilityLabel: "settings.rules_per_app.actions".localized) {
                Button {
                    viewModel.editRule(bundleIdentifier: resolvedRule.rule.bundleIdentifier)
                } label: {
                    Label("settings.rules_per_app.edit_app".localized, systemImage: "pencil")
                }

                Button(role: .destructive) {
                    viewModel.removeRule(bundleIdentifier: resolvedRule.rule.bundleIdentifier)
                } label: {
                    Label("settings.rules_per_app.remove_app".localized, systemImage: "trash")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(appRowAccessibilityLabel(for: resolvedRule))
        .accessibilityHint("settings.rules_per_app.actions".localized)
    }

    private var addAppSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                    HStack(spacing: 12) {
                        AppIconView(
                            bundleIdentifier: app.bundleIdentifier,
                            fallbackSystemName: "app.fill",
                            size: 32,
                            cornerRadius: AppDesignSystem.Layout.smallCornerRadius
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
        HStack(spacing: 12) {
            Image(systemName: "globe")
                .font(.title3)
                .foregroundStyle(AppDesignSystem.Colors.iconHighlight)
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

            websiteRuleSummary(for: target)

            SettingsContextMenuButton(accessibilityLabel: "settings.rules_per_app.actions".localized) {
                Button {
                    markdownWebTargetsViewModel.editTarget(target)
                } label: {
                    Label("settings.markdown_targets.websites.edit".localized, systemImage: "pencil")
                }

                Button(role: .destructive) {
                    markdownWebTargetsViewModel.confirmDelete(target)
                } label: {
                    Label("settings.markdown_targets.websites.delete".localized, systemImage: "trash")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(websiteRowAccessibilityLabel(for: target))
        .accessibilityHint("settings.rules_per_app.actions".localized)
    }

    private func browserNames(from bundleIdentifiers: [String]) -> String {
        WebTargetBrowserNamesFormatter.formattedNames(
            bundleIdentifiers: bundleIdentifiers,
            fallbackBundleIdentifiers: viewModel.effectiveWebTargetBrowserBundleIdentifiers,
            localizedListKey: "settings.markdown_targets.websites.browsers"
        )
    }

    private var editingAppRule: ResolvedDictationAppRule? {
        guard let bundleIdentifier = viewModel.editingRuleBundleIdentifier else { return nil }
        return viewModel.resolvedRules.first { $0.rule.bundleIdentifier == bundleIdentifier }
    }

    private func websiteRuleSummary(for target: WebContextTarget) -> some View {
        HStack(spacing: 8) {
            Text(
                target.forceMarkdownOutput
                    ? "settings.markdown_targets.websites.summary.markdown_on".localized
                    : "settings.markdown_targets.websites.summary.markdown_off".localized
            )
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(AppDesignSystem.Colors.subtleFill2)
            )
            .foregroundStyle(.secondary)
            .accessibilityLabel("settings.rules_per_app.markdown.title".localized)

            if target.outputLanguage != .original {
                Text(target.outputLanguage.flagEmoji)
                    .font(.headline)
                    .accessibilityLabel(target.outputLanguage.localizedName)
            }

            if let customPromptInstructions = target.customPromptInstructions,
               !customPromptInstructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            {
                Image(systemName: "text.append")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("settings.rules_per_app.custom_prompt.badge_accessibility".localized)
            }

            if target.autoStartMeetingRecording {
                Text("settings.markdown_targets.websites.summary.auto_record".localized)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(AppDesignSystem.Colors.subtleFill2)
                    )
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("settings.markdown_targets.websites.auto_record.title".localized)
            }
        }
    }

    private func appRuleSummary(for rule: DictationAppRule) -> some View {
        HStack(spacing: 8) {
            if rule.forceMarkdownOutput {
                Text("MD")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(AppDesignSystem.Colors.subtleFill2)
                    )
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("settings.rules_per_app.markdown.title".localized)
            }

            if rule.outputLanguage != .original {
                Text(rule.outputLanguage.flagEmoji)
                    .font(.headline)
                    .accessibilityLabel(rule.outputLanguage.localizedName)
            }

            if let customPromptInstructions = rule.customPromptInstructions,
               !customPromptInstructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            {
                Image(systemName: "text.append")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("settings.rules_per_app.custom_prompt.badge_accessibility".localized)
            }
        }
    }

    private func appRowAccessibilityLabel(for resolvedRule: ResolvedDictationAppRule) -> String {
        [resolvedRule.displayName, resolvedRule.rule.bundleIdentifier, appRuleSummaryAccessibility(for: resolvedRule.rule)]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    private func websiteRowAccessibilityLabel(for target: WebContextTarget) -> String {
        [target.displayName, target.urlPatterns.joined(separator: ", "), websiteRuleSummaryAccessibility(for: target)]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    private func appRuleSummaryAccessibility(for rule: DictationAppRule) -> String {
        var parts: [String] = []
        if rule.forceMarkdownOutput {
            parts.append("settings.rules_per_app.markdown.title".localized)
        }
        if rule.outputLanguage != .original {
            parts.append(rule.outputLanguage.localizedName)
        }
        if let customPromptInstructions = rule.customPromptInstructions,
           !customPromptInstructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            parts.append("settings.rules_per_app.custom_prompt.badge_accessibility".localized)
        }
        return parts.joined(separator: ", ")
    }

    private func websiteRuleSummaryAccessibility(for target: WebContextTarget) -> String {
        var parts: [String] = []
        parts.append(
            target.forceMarkdownOutput
                ? "settings.markdown_targets.websites.summary.markdown_on".localized
                : "settings.markdown_targets.websites.summary.markdown_off".localized
        )
        if target.outputLanguage != .original {
            parts.append(target.outputLanguage.localizedName)
        }
        if let customPromptInstructions = target.customPromptInstructions,
           !customPromptInstructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            parts.append("settings.rules_per_app.custom_prompt.badge_accessibility".localized)
        }
        if target.autoStartMeetingRecording {
            parts.append("settings.markdown_targets.websites.summary.auto_record".localized)
        }
        return parts.joined(separator: ", ")
    }
}

#Preview {
    RulesPerAppSettingsTab()
}
