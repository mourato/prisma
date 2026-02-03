import SwiftUI

struct RecordingButton: View {
    let title: String
    let icon: String
    let isDisabled: Bool
    let onStart: (RecordingSource) -> Void

    @State private var isDropdownPressed = false

    var body: some View {
        HStack(spacing: 0) {
            // Main Button Area
            Button {
                onStart(.microphone)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))

                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundColor(SettingsDesignSystem.Colors.onAccent)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isDisabled)

            // Vertical Divider
            Rectangle()
                .fill(SettingsDesignSystem.Colors.onAccent.opacity(0.3))
                .frame(width: 1, height: 24)

            // Dropdown Area - Custom implementation for better control
            dropdownButton
        }
        .foregroundColor(SettingsDesignSystem.Colors.onAccent)
        .background(isDisabled ? Color.gray : SettingsDesignSystem.Colors.accent)
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    private var dropdownButton: some View {
        Menu {
            Section(NSLocalizedString("menubar.record_section", bundle: .safeModule, comment: "")) {
                Button {
                    onStart(.all)
                } label: {
                    Label(RecordingSource.all.displayName, systemImage: "circle.circle.fill")
                }

                Button {
                    onStart(.microphone)
                } label: {
                    Label(RecordingSource.microphone.displayName, systemImage: "mic.fill")
                }

                Button {
                    onStart(.system)
                } label: {
                    Label(RecordingSource.system.displayName, systemImage: "display")
                }
            }
        } label: {
            // Fully transparent clickable area
            Color.clear
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .disabled(isDisabled)
        .overlay {
            // Custom chevron with press state feedback
            Image(systemName: "chevron.down")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(SettingsDesignSystem.Colors.onAccent)
                .opacity(isDropdownPressed ? 0.7 : 1.0)
                .allowsHitTesting(false)
        }
        .frame(width: 44, height: 44)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeOut(duration: 0.1)) {
                        isDropdownPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeOut(duration: 0.1)) {
                        isDropdownPressed = false
                    }
                }
        )
        .onChange(of: isDropdownPressed) { _, newValue in
            // Fallback: if Menu opens and captures gesture, reset after delay
            if newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if isDropdownPressed {
                        withAnimation(.easeOut(duration: 0.1)) {
                            isDropdownPressed = false
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        RecordingButton(
            title: "Start Recording",
            icon: "waveform",
            isDisabled: false,
            onStart: { _ in }
        )
        .padding()

        RecordingButton(
            title: "Loading...",
            icon: "hourglass",
            isDisabled: true,
            onStart: { _ in }
        )
        .padding()
    }
    .frame(width: 300)
}
