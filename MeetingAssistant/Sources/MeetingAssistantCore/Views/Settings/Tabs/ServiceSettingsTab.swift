import SwiftUI

// MARK: - Service Settings Tab

/// Tab for configuring local transcription service settings.
public struct ServiceSettingsTab: View {
    @State private var transcriptionStatus: ConnectionStatus = .unknown

    public init() {}

    public var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: "cpu")
                            .font(.title2)
                            .foregroundStyle(.blue)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Processamento Local")
                            .font(.headline)
                        Text("Apple Neural Engine (ANE)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    self.statusBadge
                }
                .padding(.vertical, 4)
            } header: {
                Label("Modelo Local", systemImage: "waveform")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Modelo:")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Parakeet TDT 0.6B v3")
                            .fontWeight(.medium)
                    }

                    HStack {
                        Text("Idiomas:")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("25 europeus (incl. PT)")
                            .fontWeight(.medium)
                    }
                }
                .font(.subheadline)

                HStack {
                    Button(action: self.testConnection) {
                        Label("Verificar Status", systemImage: "arrow.clockwise")
                    }
                    .disabled(self.transcriptionStatus == .testing)

                    Spacer()

                    if self.transcriptionStatus == .testing {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            } header: {
                Label("Modelo de Transcrição", systemImage: "text.bubble")
            }
        }
        .padding()
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(self.transcriptionStatus.color)
                .frame(width: 8, height: 8)
            Text(self.transcriptionStatus.text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(self.transcriptionStatus.color.opacity(0.1))
        )
    }

    private func testConnection() {
        self.transcriptionStatus = .testing

        Task {
            do {
                let isHealthy = try await TranscriptionClient.shared.healthCheck()
                await MainActor.run {
                    self.transcriptionStatus = isHealthy ? .success : .failure(nil)
                }
            } catch {
                await MainActor.run {
                    self.transcriptionStatus = .failure(error.localizedDescription)
                }
            }
        }
    }
}

#Preview {
    ServiceSettingsTab()
}
