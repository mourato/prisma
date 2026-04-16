import MeetingAssistantCoreCommon
import MeetingAssistantCoreInfrastructure
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
                HStack(spacing: 12) {
                    Text("settings.enhancements.model_selector.title".localized)
                        .font(.headline)

                    Spacer(minLength: 8)

                    searchField
                        .frame(width: 320)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

                List(filteredOptions, id: \.id) { option in
                    Button {
                        onSelect(option)
                    } label: {
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(option.modelID)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                Text(option.registrationName ?? option.provider.displayName)
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
                || option.registrationName?.localizedCaseInsensitiveContains(query) == true
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(
                "settings.enhancements.model_selector.search_placeholder".localized,
                text: $searchText
            )
            .textFieldStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(height: AppDesignSystem.Layout.compactButtonHeight)
        .background(AppDesignSystem.Colors.subtleFill)
        .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.Layout.smallCornerRadius))
    }
}

#Preview("Enhancements model selector") {
    let options: [EnhancementsProviderModelOption] = [
        .init(provider: .openai, modelID: "gpt-4o-mini"),
        .init(provider: .openai, modelID: "gpt-4o"),
        .init(provider: .anthropic, modelID: "claude-3-5-sonnet"),
        .init(provider: .google, modelID: "gemini-1.5-flash"),
    ]

    EnhancementsModelSelectionSheet(
        options: options,
        isSelected: { option in
            option.modelID == "gpt-4o"
        },
        onSelect: { _ in },
        onCancel: {}
    )
    .frame(width: 560, height: 440)
}
