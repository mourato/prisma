import Foundation
import SwiftUI
import Combine

@MainActor
public class RecordingViewModel: ObservableObject {
    // MARK: - Dependencies
    private let recordingManager: RecordingManager
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Published Properties
    @Published public var isRecording: Bool = false
    @Published public var isTranscribing: Bool = false
    @Published public var currentMeeting: Meeting?
    @Published public var permissionStatus: PermissionStatusManager
    @Published public var transcriptionStatus: TranscriptionStatus
    
    // MARK: - Computed Properties
    public var statusText: String {
        if isRecording {
            return "Gravando..."
        } else if isTranscribing {
            return "Transcrevendo..."
        } else {
            return "Aguardando reunião"
        }
    }
    
    // MARK: - Initialization
    public init(recordingManager: RecordingManager = .shared) {
        self.recordingManager = recordingManager
        self.permissionStatus = recordingManager.permissionStatus
        self.transcriptionStatus = recordingManager.transcriptionStatus
        
        setupBindings()
    }
    
// MARK: - Methods
    public func startRecording() async {
        await recordingManager.startRecording()
    }
    
    public func stopRecording() async {
        await recordingManager.stopRecording()
    }
    
    public func checkPermission() async {
        await recordingManager.checkPermission()
    }
    
    public func requestPermission() async {
        await recordingManager.requestPermission()
    }
    
    public func openMicrophoneSettings() {
        recordingManager.openMicrophoneSettings()
    }
    
    public func openPermissionSettings() {
        recordingManager.openPermissionSettings()
    }
    
    // MARK: - Private Methods
    private func setupBindings() {
        recordingManager.$isRecording
            .receive(on: DispatchQueue.main)
            .assign(to: &$isRecording)
        
        recordingManager.$isTranscribing
            .receive(on: DispatchQueue.main)
            .assign(to: &$isTranscribing)
        
        recordingManager.$currentMeeting
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentMeeting)
            
        // Note: permissionStatus and transcriptionStatus are reference types (Classes),
        // so we don't necessarily need to re-assign them if the reference itself doesn't change.
        // However, if RecordingManager replaces them, we should observe that.
        // Assuming they are constant references in RecordingManager for now based on previous code.
    }
}
