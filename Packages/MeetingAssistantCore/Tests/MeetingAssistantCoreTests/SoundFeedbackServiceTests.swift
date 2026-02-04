import Testing
import AppKit
@testable import MeetingAssistantCore

@Suite("Sound Feedback Service Tests")
struct SoundFeedbackServiceTests {
    
    // MARK: - SoundFeedbackSound Enum Tests
    
    @Test("All sounds have display names")
    func allSoundsHaveDisplayNames() {
        for sound in SoundFeedbackSound.allCases {
            #expect(!sound.displayName.isEmpty, "Sound \(sound.rawValue) should have a display name")
        }
    }
    
    @Test("None sound returns nil for system sound name")
    func noneSoundReturnsNilSystemName() {
        #expect(SoundFeedbackSound.none.systemSoundName == nil)
        #expect(SoundFeedbackSound.none.isSystemSound == false)
    }
    
    @Test("System sounds have correct sound names")
    func systemSoundsHaveCorrectNames() {
        #expect(SoundFeedbackSound.glass.systemSoundName == "Glass")
        #expect(SoundFeedbackSound.ping.systemSoundName == "Ping")
        #expect(SoundFeedbackSound.pop.systemSoundName == "Pop")
        #expect(SoundFeedbackSound.purr.systemSoundName == "Purr")
        #expect(SoundFeedbackSound.submarine.systemSoundName == "Submarine")
        #expect(SoundFeedbackSound.tink.systemSoundName == "Tink")
    }
    
    @Test("All system sounds are marked as system sounds")
    func allSystemSoundsMarked() {
        for sound in SoundFeedbackSound.allCases where sound != .none {
            #expect(sound.isSystemSound, "Sound \(sound.rawValue) should be a system sound")
            #expect(sound.systemSoundName != nil, "Sound \(sound.rawValue) should have a system name")
        }
    }
    
    // MARK: - Settings Default Values Tests
    
    @MainActor
    @Test("Default start sound is pop")
    func defaultStartSoundIsPop() {
        let store = AppSettingsStore.shared
        let originalStart = store.recordingStartSound
        
        store.resetToDefaults()
        
        #expect(store.recordingStartSound == .pop)
        
        // Restore original
        store.recordingStartSound = originalStart
    }
    
    @MainActor
    @Test("Default stop sound is glass")
    func defaultStopSoundIsGlass() {
        let store = AppSettingsStore.shared
        let originalStop = store.recordingStopSound
        
        store.resetToDefaults()
        
        #expect(store.recordingStopSound == .glass)
        
        // Restore original
        store.recordingStopSound = originalStop
    }
    
    @MainActor
    @Test("Sound feedback is disabled by default")
    func soundFeedbackDisabledByDefault() {
        let store = AppSettingsStore.shared
        let originalEnabled = store.soundFeedbackEnabled
        
        store.resetToDefaults()
        
        #expect(store.soundFeedbackEnabled == false)
        
        // Restore original
        store.soundFeedbackEnabled = originalEnabled
    }
}
