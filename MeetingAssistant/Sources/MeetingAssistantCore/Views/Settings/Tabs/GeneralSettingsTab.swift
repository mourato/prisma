import SwiftUI

// MARK: - General Settings Tab

/// Tab for general app settings like recording preferences and monitored apps.
public struct GeneralSettingsTab: View {
    @StateObject private var viewModel = GeneralSettingsViewModel()

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: SettingsDesignSystem.Layout.sectionSpacing) {
                self.recordingSection
                self.appsSection
            }
            .padding()
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var recordingSection: some View {
        SettingsGroup("Gravação", icon: "recordingtape") {
            VStack(alignment: .leading, spacing: 16) {
                Toggle("Iniciar gravação automaticamente ao detectar reunião", isOn: self.$viewModel.autoStartRecording)

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Pasta de gravações:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack {
                        TextField("Caminho", text: self.$viewModel.recordingsPath)
                            .textFieldStyle(.roundedBorder)

                        Button("Escolher...") {
                            self.viewModel.selectRecordingsDirectory()
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var appsSection: some View {
        SettingsGroup("Apps Monitorados", icon: "app.badge") {
            VStack(alignment: .leading, spacing: 12) {
                Text("O aplicativo monitora automaticamente o estado destes apps para iniciar/parar gravações.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)

                ForEach(MeetingApp.allCases, id: \.self) { app in
                    HStack(spacing: 12) {
                        Image(systemName: app.icon)
                            .font(.title3)
                            .foregroundStyle(app.color)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.displayName)
                                .font(.body)
                                .fontWeight(.medium)
                            Text("Monitoramento ativo")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }

                        Spacer()
                    }
                    .padding(8)
                    .background(Color.primary.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}

#Preview {
    GeneralSettingsTab()
}
