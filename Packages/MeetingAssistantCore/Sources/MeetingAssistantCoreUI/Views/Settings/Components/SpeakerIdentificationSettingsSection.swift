import SwiftUI
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

public struct SpeakerIdentificationSettingsSection: View {
    @ObservedObject private var settings: AppSettingsStore
    @ObservedObject private var modelManager: FluidAIModelManager

    public init(
        settings: AppSettingsStore = .shared,
        modelManager: FluidAIModelManager = .shared
    ) {
        self.settings = settings
        self.modelManager = modelManager
    }

    public var body: some View {
        MAToggleRow(
            "settings.ai.diarization".localized,
            description: "settings.ai.diarization_desc".localized,
            isOn: $settings.isDiarizationEnabled
        )

        if settings.isDiarizationEnabled {
            modelStatusSection

            Divider()
                .padding(.vertical, 2)

            VStack(spacing: 12) {
                HStack {
                    Text("settings.ai.num_speakers".localized)

                    Spacer()

                    if let num = settings.numSpeakers {
                        Stepper(
                            value: Binding(
                                get: { num },
                                set: { settings.numSpeakers = $0 }
                            ),
                            in: 1...20
                        ) {
                            Text("\(num)")
                                .fontWeight(.medium)
                                .frame(width: 24)
                        }
                    } else {
                        Text("settings.ai.speakers_auto".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Toggle(
                        "",
                        isOn: Binding(
                            get: { settings.numSpeakers != nil },
                            set: { isOn in
                                settings.numSpeakers = isOn ? 2 : nil
                                if isOn {
                                    settings.minSpeakers = nil
                                    settings.maxSpeakers = nil
                                }
                            }
                        )
                    )
                    .labelsHidden()
                    .toggleStyle(.switch)
                }

                if settings.numSpeakers == nil {
                    HStack {
                        Text("settings.ai.min_speakers".localized)

                        Spacer()

                        if let min = settings.minSpeakers {
                            Stepper(
                                value: Binding(
                                    get: { min },
                                    set: { settings.minSpeakers = $0 }
                                ),
                                in: 1...(settings.maxSpeakers ?? 20)
                            ) {
                                Text("\(min)")
                                    .fontWeight(.medium)
                                    .frame(width: 24)
                            }
                        } else {
                            Text("settings.ai.speakers_auto".localized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Toggle(
                            "",
                            isOn: Binding(
                                get: { settings.minSpeakers != nil },
                                set: { isOn in
                                    settings.minSpeakers = isOn ? 1 : nil
                                }
                            )
                        )
                        .labelsHidden()
                        .toggleStyle(.switch)
                    }

                    HStack {
                        Text("settings.ai.max_speakers".localized)

                        Spacer()

                        if let max = settings.maxSpeakers {
                            Stepper(
                                value: Binding(
                                    get: { max },
                                    set: { settings.maxSpeakers = $0 }
                                ),
                                in: (settings.minSpeakers ?? 1)...20
                            ) {
                                Text("\(max)")
                                    .fontWeight(.medium)
                                    .frame(width: 24)
                            }
                        } else {
                            Text("settings.ai.speakers_auto".localized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Toggle(
                            "",
                            isOn: Binding(
                                get: { settings.maxSpeakers != nil },
                                set: { isOn in
                                    settings.maxSpeakers = isOn ? 10 : nil
                                }
                            )
                        )
                        .labelsHidden()
                        .toggleStyle(.switch)
                    }
                }
            }
        }
    }

    // MARK: - Model Status

    @ViewBuilder
    private var modelStatusSection: some View {
        let phase = modelManager.downloadPhase

        // Only show when there's activity or an error
        if phase.isInProgress || phase == .ready || modelManager.lastError != nil {
            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.itemSpacing) {
                HStack(spacing: 12) {
                    phaseIcon(for: phase)
                        .frame(width: 24, height: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(phase.localizedDescription)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        if phase.isInProgress {
                            Text("settings.ai.please_wait".localized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    if phase.isInProgress {
                        ProgressView()
                            .controlSize(.small)
                    } else if case .failed = phase {
                        Button {
                            Task {
                                await modelManager.retryFailedModels()
                            }
                        } label: {
                            Text("settings.ai.retry".localized)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    } else if phase == .ready {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(MeetingAssistantDesignSystem.Colors.success)
                            .accessibilityLabel("settings.ai.ready".localized)
                    }
                }
            }
            .padding(.vertical, MeetingAssistantDesignSystem.Layout.spacing4)
            .animation(.easeInOut(duration: 0.2), value: phase)
        }
    }

    @ViewBuilder
    private func phaseIcon(for phase: FluidAIModelManager.DownloadPhase) -> some View {
        switch phase {
        case .idle:
            Image(systemName: "circle.dashed")
                .foregroundStyle(.secondary)
                .accessibilityLabel("settings.ai.phase_idle".localized)
        case .downloadingASR, .downloadingDiarization:
            Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(MeetingAssistantDesignSystem.Colors.accent)
                .symbolEffect(.pulse)
                .accessibilityLabel("settings.ai.downloading".localized)
        case .loadingASR, .loadingDiarization:
            Image(systemName: "gearshape.circle.fill")
                .foregroundStyle(MeetingAssistantDesignSystem.Colors.warning)
                .symbolEffect(.pulse)
                .accessibilityLabel("settings.ai.loading".localized)
        case .ready:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(MeetingAssistantDesignSystem.Colors.success)
                .accessibilityLabel("settings.ai.ready".localized)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(MeetingAssistantDesignSystem.Colors.error)
                .accessibilityLabel("settings.ai.failed".localized)
        }
    }
}

private struct SpeakerIdentificationSettingsSectionPreview: View {
    private let settings: AppSettingsStore

    init() {
        let settings = AppSettingsStore.shared
        settings.isDiarizationEnabled = true
        settings.numSpeakers = nil
        settings.minSpeakers = 2
        settings.maxSpeakers = 6
        self.settings = settings
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing12) {
            SpeakerIdentificationSettingsSection(settings: settings, modelManager: .shared)
        }
        .padding()
        .frame(width: 760)
    }
}

#Preview("Speaker Identification Settings") {
    SpeakerIdentificationSettingsSectionPreview()
}
