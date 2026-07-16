import AppKit
import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI
import UniformTypeIdentifiers

public enum DictionaryWorkflow: String, CaseIterable, Identifiable, Sendable {
    case substitutions
    case vocabulary

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .substitutions: "settings.dictionary.workflow.substitutions".localized
        case .vocabulary: "settings.dictionary.workflow.vocabulary".localized
        }
    }

    public var icon: String {
        switch self {
        case .substitutions: "arrow.2.squarepath"
        case .vocabulary: "text.book.closed"
        }
    }
}

public struct DictionarySettingsTab: View {
    @StateObject private var substitutionViewModel: VocabularySettingsViewModel
    @StateObject private var vocabularyViewModel: VocabularyTermsSettingsViewModel
    @State private var selectedWorkflow: DictionaryWorkflow = .substitutions
    @State private var ruleFindInput = ""
    @State private var ruleReplaceInput = ""
    @State private var selectedRuleID: UUID?
    @State private var importExportMessage: String?
    @State private var showImportExportAlert = false
    private let showsHeader: Bool
    private let onBack: (() -> Void)?

    public init(
        settings: AppSettingsStore = .shared,
        showsHeader: Bool = true,
        onBack: (() -> Void)? = nil,
    ) {
        _substitutionViewModel = StateObject(wrappedValue: VocabularySettingsViewModel(settings: settings))
        _vocabularyViewModel = StateObject(wrappedValue: VocabularyTermsSettingsViewModel(settings: settings))
        self.showsHeader = showsHeader
        self.onBack = onBack
    }

    public var body: some View {
        SettingsFormPage {
            VStack(alignment: .leading, spacing: 8) {
                if let onBack {
                    SettingsChildPageBackButton(action: onBack)
                }
                SettingsFormSectionHeader(title: "settings.section.dictionary".localized, icon: "character.book.closed")
                if showsHeader {
                    Text("settings.dictionary.description".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Picker("", selection: $selectedWorkflow) {
                    ForEach(DictionaryWorkflow.allCases) { workflow in
                        Label(workflow.title, systemImage: workflow.icon).tag(workflow)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(.vertical, 4)
            }
        } content: {
            switch selectedWorkflow {
            case .substitutions:
                substitutionsContent
                importExportSection
            case .vocabulary:
                vocabularyContent
                importExportSection
            }
        }
        .alert(
            "settings.dictionary.import_export.title".localized,
            isPresented: $showImportExportAlert,
        ) {
            Button("common.ok".localized, role: .cancel) {}
        } message: {
            if let message = importExportMessage {
                Text(message)
            }
        }
        .sheet(isPresented: $substitutionViewModel.showRuleEditor) {
            substitutionEditorSheet
                .onAppear(perform: syncEditorInputsFromEditingRule)
        }
        .alert(
            "settings.vocabulary.delete_confirm_title".localized,
            isPresented: $substitutionViewModel.showDeleteConfirmation,
        ) {
            Button("common.cancel".localized, role: .cancel) {}
            Button("common.delete".localized, role: .destructive) {
                substitutionViewModel.executeDelete()
            }
        } message: {
            if let rule = substitutionViewModel.ruleToDelete {
                Text("settings.vocabulary.delete_confirm_message".localized(with: rule.find))
            }
        }
        .alert(
            "settings.dictionary.vocabulary.delete_confirm_title".localized,
            isPresented: $vocabularyViewModel.showDeleteConfirmation,
        ) {
            Button("common.cancel".localized, role: .cancel) {}
            Button("common.delete".localized, role: .destructive) {
                vocabularyViewModel.executeDelete()
            }
        } message: {
            if let term = vocabularyViewModel.termToDelete {
                Text("settings.dictionary.vocabulary.delete_confirm_message".localized(with: term.term))
            }
        }
        .onDeleteCommand(perform: handleDeleteKey)
    }

    // MARK: - Substitutions Content

    private var substitutionsContent: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("settings.vocabulary.applied_order_note".localized)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                SettingsInlineList(
                    items: substitutionViewModel.rules,
                    emptyText: "settings.vocabulary.empty".localized,
                    containerStyle: .plain,
                ) { rule in
                    substitutionRow(for: rule)
                }

                HStack {
                    Spacer()
                    Button {
                        ruleFindInput = ""
                        ruleReplaceInput = ""
                        substitutionViewModel.startCreatingRule()
                    } label: {
                        Label("settings.vocabulary.add_rule".localized, systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }
            }
        } header: {
            SettingsFormSectionHeader(
                title: "settings.dictionary.workflow.substitutions".localized,
                icon: "arrow.2.squarepath",
            )
        }
    }

    private func substitutionRow(for rule: VocabularyReplacementRule) -> some View {
        VocabularyRuleRowView(
            rule: rule,
            isSelected: selectedRuleID == rule.id,
            onSelect: { selectSubstitutionRule(rule) },
            onEdit: { editSubstitutionRule(rule) },
            onDelete: { confirmDeleteSubstitutionRule(rule) },
        )
    }

    private var substitutionEditorSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(substitutionEditorTitle)
                .font(.title3)
                .fontWeight(.semibold)

            Text("settings.vocabulary.editor_description".localized)
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("settings.vocabulary.find_label".localized)
                    .font(.subheadline)
                    .fontWeight(.medium)
                TextField("settings.vocabulary.find_placeholder".localized, text: $ruleFindInput)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("settings.vocabulary.replace_label".localized)
                    .font(.subheadline)
                    .fontWeight(.medium)
                TextField("settings.vocabulary.replace_placeholder".localized, text: $ruleReplaceInput)
                    .textFieldStyle(.roundedBorder)
            }

            if let errorKey = substitutionEditorErrorKey {
                Text(errorKey.localized)
                    .font(.caption)
                    .foregroundStyle(AppDesignSystem.Colors.error)
            }

            HStack {
                Spacer()
                Button("common.cancel".localized) {
                    substitutionViewModel.dismissRuleEditor()
                }
                .keyboardShortcut(.cancelAction)

                Button("common.save".localized) {
                    _ = substitutionViewModel.saveRule(find: ruleFindInput, replace: ruleReplaceInput)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(minWidth: 520)
    }

    private var substitutionEditorTitle: String {
        if substitutionViewModel.editingRule == nil {
            return "settings.vocabulary.add_rule".localized
        }
        return "settings.vocabulary.edit_rule".localized
    }

    private var substitutionEditorErrorKey: String? {
        switch substitutionViewModel.editorValidationError {
        case .none: nil
        case .some(.emptyFind): "settings.vocabulary.validation.find_required"
        case .some(.duplicatedFind): "settings.vocabulary.validation.find_duplicated"
        }
    }

    private func syncEditorInputsFromEditingRule() {
        if let rule = substitutionViewModel.editingRule {
            ruleFindInput = rule.find
            ruleReplaceInput = rule.replace
        } else {
            ruleFindInput = ""
            ruleReplaceInput = ""
        }
    }

    private func selectSubstitutionRule(_ rule: VocabularyReplacementRule) {
        selectedRuleID = rule.id
    }

    private func editSubstitutionRule(_ rule: VocabularyReplacementRule) {
        selectSubstitutionRule(rule)
        ruleFindInput = rule.find
        ruleReplaceInput = rule.replace
        substitutionViewModel.startEditingRule(rule)
    }

    private func confirmDeleteSubstitutionRule(_ rule: VocabularyReplacementRule) {
        selectSubstitutionRule(rule)
        substitutionViewModel.confirmDelete(rule)
    }

    // MARK: - Vocabulary Content

    private var vocabularyContent: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("settings.dictionary.vocabulary.description".localized)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                // Bulk add area
                HStack(spacing: 8) {
                    TextField("settings.dictionary.vocabulary.add_placeholder".localized, text: $vocabularyViewModel.bulkInputText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { vocabularyViewModel.addTermsFromBulkInput() }

                    Button("common.add".localized) {
                        vocabularyViewModel.addTermsFromBulkInput()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(vocabularyViewModel.bulkInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if let error = vocabularyViewModel.validationError {
                    Text(validationErrorMessage(for: error))
                        .font(.caption)
                        .foregroundStyle(AppDesignSystem.Colors.error)
                }

                if vocabularyViewModel.addedTermsCount > 0 {
                    Text("settings.dictionary.vocabulary.added_count".localized(with: vocabularyViewModel.addedTermsCount))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Existing terms list
                if vocabularyViewModel.terms.isEmpty {
                    Text("settings.dictionary.vocabulary.empty".localized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(vocabularyViewModel.terms) { term in
                        VocabularyTermRowView(
                            term: term,
                            onDelete: { vocabularyViewModel.confirmDelete(term) },
                        )
                    }
                }
            }
        } header: {
            SettingsFormSectionHeader(
                title: "settings.dictionary.workflow.vocabulary".localized,
                icon: "text.book.closed",
            )
        }
    }

    private func validationErrorMessage(for error: VocabularyTermsSettingsViewModel.ValidationError) -> String {
        switch error {
        case .emptyTerm:
            "settings.dictionary.vocabulary.validation.empty".localized
        case let .duplicatedTerm(term):
            "settings.dictionary.vocabulary.validation.duplicated".localized(with: term)
        }
    }

    // MARK: - Import / Export

    private var importExportSection: some View {
        Section {
            HStack(spacing: 12) {
                Button("settings.dictionary.export".localized) {
                    exportDictionary()
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                Button("settings.dictionary.import".localized) {
                    importDictionary()
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                Spacer()
            }
        } header: {
            SettingsFormSectionHeader(
                title: "settings.dictionary.import_export".localized,
                icon: "arrow.up.arrow.down",
            )
        }
    }

    private func exportDictionary() {
        let settings = AppSettingsStore.shared
        let archive = DictionaryArchive(
            vocabularyTerms: settings.vocabularyTerms,
            substitutionRules: settings.vocabularyReplacementRules,
        )

        guard let data = try? JSONEncoder().encode(archive) else {
            importExportMessage = "settings.dictionary.export.error_encode".localized
            showImportExportAlert = true
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.json]
        panel.nameFieldStringValue = "prisma-dictionary-export.json"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try data.write(to: url, options: .atomic)
            importExportMessage = "settings.dictionary.export.success".localized
            showImportExportAlert = true
        } catch {
            importExportMessage = "settings.dictionary.export.error_write".localized(with: error.localizedDescription)
            showImportExportAlert = true
        }
    }

    private func importDictionary() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.json]
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try Data(contentsOf: url)
            let result = DictionaryArchive.validate(data: data)

            switch result {
            case let .success(archive):
                let settings = AppSettingsStore.shared
                let mergeResult = archive.merge(
                    into: settings.vocabularyTerms,
                    existingRules: settings.vocabularyReplacementRules,
                )

                if mergeResult.totalImported > 0 {
                    settings.vocabularyTerms = mergeResult.totalDuplicates > 0
                        ? settings.vocabularyTerms
                        : archive.vocabularyTerms + settings.vocabularyTerms
                    settings.vocabularyReplacementRules = mergeResult.totalDuplicates > 0
                        ? settings.vocabularyReplacementRules
                        : settings.vocabularyReplacementRules + archive.substitutionRules

                    // Re-apply with merge logic
                    reapplyImport(archive: archive, mergeResult: mergeResult)
                }

                importExportMessage = importResultMessage(mergeResult)
                showImportExportAlert = true

            case let .failure(error):
                importExportMessage = "settings.dictionary.import.error_invalid".localized(with: error.localizedDescription)
                showImportExportAlert = true
            }
        } catch {
            importExportMessage = "settings.dictionary.import.error_read".localized(with: error.localizedDescription)
            showImportExportAlert = true
        }
    }

    private func reapplyImport(archive: DictionaryArchive, mergeResult: DictionaryArchive.ImportResult) {
        guard mergeResult.totalImported > 0 else { return }

        let settings = AppSettingsStore.shared

        // Merge terms (skip duplicates)
        var mergedTerms = settings.vocabularyTerms
        let existingTermLower = Set(mergedTerms.map { $0.term.lowercased() })
        for term in archive.vocabularyTerms {
            if !existingTermLower.contains(term.term.lowercased()) {
                mergedTerms.append(term)
            }
        }

        // Merge rules (skip duplicates)
        var mergedRules = settings.vocabularyReplacementRules
        for rule in archive.substitutionRules {
            let ruleVariants = Set(rule.normalizedFindVariants.map { $0.lowercased() })
            let isDuplicate = mergedRules.contains { existingRule in
                let existingVariants = Set(existingRule.normalizedFindVariants.map { $0.lowercased() })
                return !ruleVariants.isDisjoint(with: existingVariants)
            }
            if !isDuplicate {
                mergedRules.append(rule)
            }
        }

        settings.vocabularyTerms = mergedTerms
        settings.vocabularyReplacementRules = mergedRules
        vocabularyViewModel.reloadFromStore()
    }

    private func importResultMessage(_ result: DictionaryArchive.ImportResult) -> String {
        var parts: [String] = []
        if result.termsImported > 0 {
            parts.append("settings.dictionary.import.result.terms".localized(with: result.termsImported))
        }
        if result.rulesImported > 0 {
            parts.append("settings.dictionary.import.result.rules".localized(with: result.rulesImported))
        }
        if result.totalDuplicates > 0 {
            parts.append("settings.dictionary.import.result.skipped".localized(with: result.totalDuplicates))
        }
        if parts.isEmpty {
            return "settings.dictionary.import.result.nothing".localized
        }
        return parts.joined(separator: "\n")
    }

    // MARK: - Keyboard

    private func handleDeleteKey() {
        if selectedWorkflow == .substitutions, let selectedRuleID,
           let rule = substitutionViewModel.rules.first(where: { $0.id == selectedRuleID })
        {
            substitutionViewModel.confirmDelete(rule)
        }
    }
}

// MARK: - Vocabulary Term Row

private struct VocabularyTermRowView: View {
    let term: VocabularyTerm
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(term.term)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if !term.definition.isEmpty {
                    Text(term.definition)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .help("common.delete".localized)
            .accessibilityLabel("settings.dictionary.vocabulary.delete_term".localized(with: term.term))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: AppDesignSystem.Layout.smallCornerRadius)
                .fill(Color.clear),
        )
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("common.delete".localized, systemImage: "trash")
            }
        }
    }
}

// MARK: - Substitution Rule Row (reused from VocabularySettingsTab)

extension DictionarySettingsTab {
    struct VocabularyRuleRowView: View {
        let rule: VocabularyReplacementRule
        let isSelected: Bool
        let onSelect: () -> Void
        let onEdit: () -> Void
        let onDelete: () -> Void

        var body: some View {
            HStack(spacing: 12) {
                SettingsRowClickSurface(
                    onSingleClick: onSelect,
                    onDoubleClick: onEdit,
                    content: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(rule.find)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(AppDesignSystem.Colors.primaryTextStyle(isSelected: isSelected))
                                Text(rule.replace.isEmpty ? "settings.vocabulary.empty_replace".localized : rule.replace)
                                    .font(.caption)
                                    .foregroundStyle(AppDesignSystem.Colors.secondaryTextStyle(isSelected: isSelected))
                            }

                            Spacer()

                            Image(systemName: "arrow.right")
                                .font(.caption)
                                .foregroundStyle(AppDesignSystem.Colors.secondaryTextStyle(isSelected: isSelected))
                        }
                    },
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(rowBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.Layout.smallCornerRadius))
            .contextMenu {
                Button {
                    onEdit()
                } label: {
                    Label("settings.vocabulary.edit_rule".localized, systemImage: "pencil")
                }

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("settings.vocabulary.delete_rule".localized, systemImage: "trash")
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint("settings.vocabulary.actions".localized)
        }

        @ViewBuilder
        private var rowBackground: some View {
            if isSelected {
                RoundedRectangle(cornerRadius: AppDesignSystem.Layout.smallCornerRadius)
                    .fill(AppDesignSystem.Colors.selectionFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppDesignSystem.Layout.smallCornerRadius)
                            .stroke(AppDesignSystem.Colors.selectionStroke, lineWidth: 1),
                    )
            } else {
                Color.clear
            }
        }

        private var accessibilityLabel: String {
            [rule.find, rule.replace.isEmpty ? "settings.vocabulary.empty_replace".localized : rule.replace]
                .joined(separator: ", ")
        }
    }
}

#Preview {
    DictionarySettingsTab()
}
