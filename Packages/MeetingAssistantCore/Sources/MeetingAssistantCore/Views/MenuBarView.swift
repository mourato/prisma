import SwiftUI

/// Menu bar popover view displaying recording status and controls.
public struct MenuBarView: View {
    @EnvironmentObject var recordingManager: RecordingManager
    @Environment(\.openWindow) private var openWindow
    @StateObject private var viewModel: RecordingViewModel

    public init(viewModel: RecordingViewModel? = nil) {
        // Allow injection for previews/tests, otherwise delay initialization until onAppear/Environment is available
        // Note: Since we need EnvironmentObject, we can't fully init StateObject dependent on it in init().
        // However, we can use a custom init to accept a VM if provided (e.g. tests),
        // OR we just rely on .onAppear to configure if needed.
        // BUT, a better pattern here is to NOT initialize StateObject with a dependency if we can avoid it,
        // OR pass the dependency into the VM method calls.
        // Given existing architecture, we will construct it in the init with a default if needed,
        // but ideally we should construct it based on the EnvironmentObject.
        // SwiftUI @StateObject auto-initialization happens before body.

        // Correct Approach for this refactor:
        // We will Initialize StateObject with a placeholder or shared, but we will UPDATE it or pass the dependency
        // actually, to fix "Deceptive Dependency Injection", we should initialize the ViewModel using the manager
        // passed in. But EnvironmentObject is only available in body.
        // So we change the architecture slightly:
        // 1. MenuBarView shouldn't own the ViewModel if it depends on Environment.
        // 2. OR, MenuBarView should just use RecordingViewModel which is ALREADY an ObservableObject?
        // Let's check RecordingViewModel. It wraps RecordingManager.

        // Simplest fix that respects the critique:
        // RecordingManager IS the source of truth. RecordingViewModel is a wrapper.
        // We should inject RecordingViewModel directly if possible, OR make RecordingViewModel NOT hold the manager tightly.

        // Let's stick to the plan: Update MenuBarView to accept dependencies.
        // For now, let's keep the StateObject but initialize it using the Shared instance explicitely implies coupling.
        // Better: Pass the ViewModel in logic.

        // Standard SwiftUI pattern:
        // Parent creates VM, passes to Child.
        // AppDelegate creates RecordingManager.
        // We can create RecordingViewModel in AppDelegate and pass it down.

        // Let's assume we want to construct it here for now but use the EnvironmentObject if possible.
        // Actually, looking at AppDelegate, it passes `recordingManager`.
        // The ViewModel wraps it.
        // We will change `viewModel` to be a derived state or simple wrapper,
        // OR we just assume `RecordingManager` IS the mechanism and we use it directly?
        // RecordingViewModel adds "statusText" logic.

        // Let's instantiate the VM with the shared instance (Current behavior) but allow injection.
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
                .foregroundStyle(SettingsDesignSystem.Colors.accent)

            Text(NSLocalizedString("about.title", bundle: .safeModule, comment: ""))
                .font(.headline)

            Spacer()

            Button(action: { NavigationService.shared.openSettings() }) {
                Image(systemName: "gear")
            }
            .buttonStyle(.plain)
        }
    }

    private var statusSection: some View {
        Group {
            if let statusText = viewModel.statusText {
                VStack(spacing: 8) {
                    HStack {
                        Circle()
                            .fill(viewModel.isRecording ? .red : .gray)
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
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var controlButtons: some View {
        VStack(spacing: 12) {
            if !viewModel.isRecording {
                HStack {
                    Text(NSLocalizedString("menubar.meeting.type_label", bundle: .safeModule, comment: ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker(NSLocalizedString("menubar.meeting.type_picker", bundle: .safeModule, comment: ""), selection: $viewModel.selectedMeetingType) {
                        ForEach(MeetingType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 4)
            }

            if viewModel.isRecording {
                Button(action: stopRecording) {
                    Label(
                        viewModel.recordButtonTitle,
                        systemImage: viewModel.recordButtonIcon
                    )
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
                .background(Color.red)
                .foregroundColor(.white)
                .clipShape(Capsule())
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
        .background(.background, in: RoundedRectangle(cornerRadius: 6))
    }
}

#Preview {
    MenuBarView()
}
