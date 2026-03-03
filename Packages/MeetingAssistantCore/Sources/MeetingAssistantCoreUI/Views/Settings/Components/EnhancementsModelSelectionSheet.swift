import MeetingAssistantCoreCommon
import SwiftUI

public struct EnhancementsModelSelectionSheet: View {
    let options: [EnhancementsProviderModelOption]
    let isSelected: (EnhancementsProviderModelOption) -> Bool
    let onSelect: (EnhancementsProviderModelOption) -> Void
    let onCancel: () -> Void

    @State private var searchText = ""

    public init(
        options: [EnhancementsProviderModelOption],
        isSelected: @escaping (EnhancementsProviderModelOption) -> Bool,
        onSelect: @escaping (EnhancementsProviderModelOption) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.options = options
        self.isSelected = isSelected
        self.onSelect = onSelect
        self.onCancel = onCancel
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: AppDesignSystem.Layout.spacing12) {
                    Text("settings.enhancements.model_selector.title".localized)
                        .font(.headline)

                    Spacer(minLength: AppDesignSystem.Layout.spacing8)

                    searchField
                        .frame(width: 320)
                }
                .padding(.horizontal, AppDesignSystem.Layout.spacing16)
                .padding(.top, AppDesignSystem.Layout.spacing12)
                .padding(.bottom, AppDesignSystem.Layout.spacing8)

                List(filteredOptions, id: \.id) { option in
                    Button {
                        onSelect(option)
                    } label: {
                        HStack(spacing: AppDesignSystem.Layout.spacing8) {
                            VStack(alignment: .leading, spacing: AppDesignSystem.Layout.spacing4) {
                                Text(option.modelID)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                Text(option.provider.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if isSelected(option) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(AppDesignSystem.Colors.success)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel".localized) {
                        onCancel()
                    }
                }
            }
        }
        .frame(minWidth: 520, minHeight: 420)
    }

    private var filteredOptions: [EnhancementsProviderModelOption] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return options }
        return options.filter { option in
            option.modelID.localizedCaseInsensitiveContains(query)
                || option.provider.displayName.localizedCaseInsensitiveContains(query)
        }
    }

    private var searchField: some View {
        HStack(spacing: AppDesignSystem.Layout.spacing8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(
                "settings.enhancements.model_selector.search_placeholder".localized,
                text: $searchText
            )
            .textFieldStyle(.plain)
        }
        .padding(.horizontal, AppDesignSystem.Layout.spacing10)
        .padding(.vertical, AppDesignSystem.Layout.spacing8)
        .frame(height: AppDesignSystem.Layout.compactButtonHeight)
        .background(AppDesignSystem.Colors.subtleFill)
        .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.Layout.smallCornerRadius))
    }
}
