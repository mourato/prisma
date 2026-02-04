import AppKit
import Foundation

// MARK: - Sound Feedback Service

/// Service responsible for playing sound notifications during recording events.
/// Uses macOS built-in system sounds via NSSound for reliable, non-blocking playback.
/// Designed to not interfere with microphone recording.
@MainActor
public final class SoundFeedbackService {
    public static let shared = SoundFeedbackService()

    private let settings = AppSettingsStore.shared

    private init() {}

    // MARK: - Public API

    /// Play sound for recording start event.
    /// Only plays if sound feedback is enabled in settings.
    public func playRecordingStartSound() {
        guard settings.soundFeedbackEnabled else { return }
        play(settings.recordingStartSound)
    }

    /// Play sound for recording stop event.
    /// Only plays if sound feedback is enabled in settings.
    public func playRecordingStopSound() {
        guard settings.soundFeedbackEnabled else { return }
        play(settings.recordingStopSound)
    }

    /// Preview a specific sound in settings UI.
    /// Plays regardless of the global sound feedback toggle.
    public func preview(_ sound: SoundFeedbackSound) {
        play(sound)
    }

    // MARK: - Private Helpers

    /// Play the specified sound using NSSound.
    /// Non-blocking playback that does not interfere with recording.
    private func play(_ sound: SoundFeedbackSound) {
        guard let soundName = sound.systemSoundName else { return }

        // NSSound uses the system's output device and does not interfere with recording
        if let nsSound = NSSound(named: NSSound.Name(soundName)) {
            // Stop any previous playback to avoid overlapping sounds
            nsSound.stop()
            nsSound.play()
        } else {
            AppLogger.warning(
                "Failed to load system sound",
                category: .general,
                extra: ["soundName": soundName]
            )
        }
    }
}
