import MeetingAssistantCoreAI
import MeetingAssistantCoreInfrastructure
import SwiftUI

public struct ModesSettingsTab: View {
    @StateObject private var viewModel: DictationStylesSettingsViewModel
    @StateObject private var aiSettingsViewModel: AISettingsViewModel
    @State private var navigationState = SettingsSubpageNavigationState<DictationStyleRoute>()

    public init(settings: AppSettingsStore = .shared) {
        _viewModel = StateObject(wrappedValue: DictationStylesSettingsViewModel(settings: settings))
        _aiSettingsViewModel = StateObject(wrappedValue: AISettingsViewModel(settings: settings))
    }

    public var body: some View {
        NavigationSplitView {
            listColumn
                .navigationSplitViewColumnWidth(min: 220, ideal: 280, max: 360)
        } detail: {
            detailContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var listColumn: some View {
        StylesSettingsTab(
            viewModel: viewModel,
            aiSettingsViewModel: aiSettingsViewModel,
            onOpenEditor: { styleID in
                viewModel.prepareEditor(for: styleID)
                openRoute(.editor(styleID: styleID))
            },
        )
    }

    private var detailContent: some View {
        ZStack {
            if let route = navigationState.currentRoute {
                routeContent(for: route)
                    .id(route)
            } else {
                emptyDetailPlaceholder
            }
        }
    }

    @ViewBuilder
    private func routeContent(for route: DictationStyleRoute) -> some View {
        switch route {
        case .editor:
            editorPage(for: route)
        case .triggerSelection:
            triggerSelectionPage
        case .promptEditor:
            promptEditorPage
        }
    }

    private var emptyDetailPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "paintpalette")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.secondary)
            Text("settings.styles.editor.empty_detail".localized)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func editorPage(for route: DictationStyleRoute) -> some View {
        if case let .editor(styleID) = route {
            if let draft = viewModel.editorDraft {
                DictationStyleEditorDetailView(
                    draft: draft,
                    appCatalog: viewModel.appCatalog,
                    isLoadingAppCatalog: viewModel.isLoadingAppCatalog,
                    onEnsureAppCatalogLoaded: viewModel.ensureAppCatalogLoaded,
                    onFindConflictingStyleName: { target, excludeID in
                        viewModel.styleNameConflicting(with: target, excluding: excludeID)
                    },
                    modelOptions: aiSettingsViewModel.enhancementsProviderModels,
                    isLoadingModelOptions: aiSettingsViewModel.isLoadingEnhancementsProviderModels,
                    onRefreshModelOptions: {
                        _ = aiSettingsViewModel.refreshEnhancementsProviderModelsManually()
                    },
                    providerDisplayName: viewModel.enhancementsProviderDisplayName(for:),
                    onSave: { draft in
                        viewModel.saveStyle(draft)
                        navigateToRoot()
                    },
                    onCancel: {
                        viewModel.clearEditor()
                        navigateToRoot()
                    },
                    onDelete: styleID != nil ? {
                        if let styleID {
                            viewModel.deleteStyle(id: styleID)
                        }
                        viewModel.clearEditor()
                        navigateToRoot()
                    } : nil,
                    onOpenTriggerSelection: { draft in
                        viewModel.editorDraft = draft
                        openRoute(.triggerSelection(styleID: styleID))
                    },
                    onOpenPromptEditor: { draft in
                        viewModel.editorDraft = draft
                        openRoute(.promptEditor(styleID: styleID))
                    },
                )
                .id(route)
            } else {
                emptyDetailPlaceholder
            }
        }
    }

    private var triggerSelectionPage: some View {
        let styleID: UUID? = {
            if case let .triggerSelection(styleID) = navigationState.currentRoute {
                return styleID
            }
            return nil
        }()

        return TriggerSelectionView(
            initialTargets: viewModel.editorDraft?.targets ?? [],
            appCatalog: viewModel.appCatalog,
            isLoadingAppCatalog: viewModel.isLoadingAppCatalog,
            styleID: styleID,
            onFindConflictingStyleName: { target, excludeID in
                viewModel.styleNameConflicting(with: target, excluding: excludeID)
            },
            onApply: { updatedTargets in
                viewModel.editorDraft?.targets = updatedTargets
                openRoute(.editor(styleID: styleID))
            },
        )
    }

    @ViewBuilder
    private var promptEditorPage: some View {
        if let draft = viewModel.editorDraft {
            DictationStylePromptEditorView(
                promptInstructions: Binding(
                    get: { draft.promptInstructions },
                    set: { viewModel.editorDraft?.promptInstructions = $0 },
                ),
                onCancel: {
                    openRoute(.editor(styleID: draft.id))
                },
            )
        } else {
            emptyDetailPlaceholder
        }
    }

    private func navigateToRoot() {
        _ = navigationState.goBack()
    }

    private func openRoute(_ route: DictationStyleRoute) {
        navigationState.open(route)
    }
}

#Preview("Modes — Native Split") {
    ModesSettingsTab()
}

#Preview("Modes — Narrow") {
    ModesSettingsTab()
        .frame(width: 620, height: 520)
}

#Preview("Modes — Expanded") {
    ModesSettingsTab()
        .frame(width: 1_080, height: 720)
}
