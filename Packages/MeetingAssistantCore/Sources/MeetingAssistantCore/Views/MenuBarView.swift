import SwiftUI

/// Menu bar popover view displaying recording status and controls.
public struct MenuBarView: View {
    @EnvironmentObject var recordingManager: RecordingManager
    @Environment(\.openWindow) private var openWindow
    @StateObject private var viewModel: RecordingViewModel

    public init(viewModel: RecordingViewModel? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel ?? RecordingViewModel(recordingManager: RecordingManager.shared))
    }

    public var body: some View {
        VStack(spacing: 16) {
            headerSection

            statusSection

            // Transcription service status indicator
            TranscriptionStatusView(viewModel: viewModel.transcriptionViewModel)

            controlButtons
        }
        .padding()
        .frame(minWidth: 300)
        .tint(MeetingAssistantDesignSystem.Colors.accent)
        .task {
            await viewModel.checkPermission()
        }
        .onAppear {
            NavigationService.shared.register(openWindow: openWindow)
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack {
            Image(systemName: "waveform.circle.fill")
                .font(.title)
                .foregroundStyle(MeetingAssistantDesignSystem.Colors.accent)

            Text("about.title".localized)
                .font(.headline)

            Spacer()

            Button(
                action: { NavigationService.shared.openSettings() },
                label: {
                    Image(systemName: "gear")
                }
            )
            .buttonStyle(.plain)
        }
    }

    private var statusSection: some View {
        Group {
            if let statusText = viewModel.statusText {
                VStack(spacing: 8) {
                    HStack {
                        Circle()
                            .fill(viewModel.isRecording ? MeetingAssistantDesignSystem.Colors.recording : MeetingAssistantDesignSystem.Colors.neutral)
                            .frame(width: 10, height: 10)

                        Text(statusText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()
                    }

                    if viewModel.isRecording, let meeting = viewModel.currentMeeting {
                        MeetingCard(meeting: meeting, duration: viewModel.displayDuration)
                    }
                }
                .padding(MeetingAssistantDesignSystem.Layout.spacing16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.smallCornerRadius))
            }
        }
    }

    private var controlButtons: some View {
        VStack(spacing: 12) {
            if viewModel.isRecording {
                MAActionButton(kind: .destructive, action: stopRecording) {
                    Label(viewModel.recordButtonTitle, systemImage: viewModel.recordButtonIcon)
                        .font(.headline)
                }
            } else {
                RecordingButton(
                    title: viewModel.recordButtonTitle,
                    icon: viewModel.isModelLoaded ? "waveform" : viewModel.recordButtonIcon,
                    isDisabled: !viewModel.canStartRecording,
                    onStart: { source in
                        startRecording(source: source)
                    }
                )
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Actions

    private func startRecording(source: RecordingSource = .microphone) {
        Task {
            await viewModel.startRecording(source: source)
        }
    }

    private func stopRecording() {
        Task {
            await viewModel.stopRecording()
        }
    }
}

/// Card showing current meeting info.
struct MeetingCard: View {
    let meeting: Meeting
    let duration: String

    var body: some View {
        HStack {
            Image(systemName: meeting.appIcon)
                .font(.title2)
                .foregroundStyle(meeting.appColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(meeting.appName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(meeting.type.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(duration)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer()
        }
        .padding(8)
        .background(.background, in: RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.chipCornerRadius))
    }
}

#Preview {
    MenuBarView()
}
