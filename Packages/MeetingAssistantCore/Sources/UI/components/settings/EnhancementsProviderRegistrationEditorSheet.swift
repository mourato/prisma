import AppKit
import MeetingAssistantCoreCommon
import MeetingAssistantCoreInfrastructure
import SwiftUI

public enum EnhancementsProviderEditorMode {
    case create
    case edit
}

public struct EnhancementsProviderEditorSheet: View {
    let mode: EnhancementsProviderEditorMode
    let provider: AIProvider
    @Binding var displayName: String
    @Binding var baseURL: String
    @Binding var apiKey: String
    let hasSavedAPIKey: Bool
    let connectionStatus: ConnectionStatus
    let errorMessage: String?
    let onSave: () -> Void
    let onTestAndSave: () -> Void
    let onDelete: (() -> Void)?
    let onRemoveKey: (() -> Void)?
    let onCancel: () -> Void

    public init(
        mode: EnhancementsProviderEditorMode,
        provider: AIProvider,
        displayName: Binding<String>,
        baseURL: Binding<String>,
        apiKey: Binding<String>,
        hasSavedAPIKey: Bool,
        connectionStatus: ConnectionStatus,
        errorMessage: String?,
        onSave: @escaping () -> Void,
        onTestAndSave: @escaping () -> Void,
        onDelete: (() -> Void)?,
        onRemoveKey: (() -> Void)?,
        onCancel: @escaping () -> Void
    ) {
        self.mode = mode
        self.provider = provider
        _displayName = displayName
        _baseURL = baseURL
        _apiKey = apiKey
        self.hasSavedAPIKey = hasSavedAPIKey
        self.connectionStatus = connectionStatus
        self.errorMessage = errorMessage
        self.onSave = onSave
        self.onTestAndSave = onTestAndSave
        self.onDelete = onDelete
        self.onRemoveKey = onRemoveKey
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)

            providerHeader

            if provider == .custom {
                VStack(alignment: .leading, spacing: 8) {
                    Text("settings.enhancements.providers.editor.name".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("", text: $displayName)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("settings.ai.base_url".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("https://api.example.com/v1", text: $baseURL)
                        .textFieldStyle(.roundedBorder)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("settings.ai.api_key".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                SecureField("settings.ai.api_key_placeholder".localized, text: $apiKey)
                    .textFieldStyle(.roundedBorder)

                if hasSavedAPIKey {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(AppDesignSystem.Colors.success)
                        Text("settings.ai.keychain_secure".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        if let onRemoveKey {
                            Button("settings.ai.remove_key".localized, role: .destructive) {
                                onRemoveKey()
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }

            if let apiURL = provider.apiKeyURL {
                Button("settings.ai.get_api_key".localized) {
                    NSWorkspace.shared.open(apiURL)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }

            HStack(spacing: 8) {
                Circle()
                    .fill(connectionStatus.color)
                    .frame(width: 7, height: 7)
                Text(connectionStatus.text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage, !errorMessage.isEmpty {
                DSCallout(
                    kind: .warning,
                    title: "settings.enhancements.provider_models.error.title".localized,
                    message: errorMessage
                )
            }

            HStack {
                if let onDelete {
                    Button("common.delete".localized, role: .destructive) {
                        onDelete()
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                Button("common.cancel".localized) {
                    onCancel()
                }
                .buttonStyle(.bordered)

                Button("common.save".localized) {
                    onSave()
                }
                .buttonStyle(.bordered)

                Button("settings.enhancements.test_and_save".localized) {
                    onTestAndSave()
                }
                .buttonStyle(.borderedProminent)
                .disabled(connectionStatus == .testing || (!hasSavedAPIKey && apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
            }
        }
        .padding(20)
        .frame(minWidth: 560)
    }

    private var title: String {
        switch mode {
        case .create:
            "settings.enhancements.providers.editor.title_create".localized
        case .edit:
            "settings.enhancements.providers.editor.title_edit".localized
        }
    }

    private var providerHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: provider.icon)
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(provider.displayName)
                    .font(.headline)
                Text("settings.enhancements.providers.editor.provider_label".localized)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}
