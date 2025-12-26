import Foundation
import SwiftUI
import Combine

@MainActor
public class RecordingViewModel: ObservableObject {
    // MARK: - Dependencies
    private let recordingManager: any RecordingServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Published Properties
    @Published public var isRecording: Bool = false
    @Published public var isTranscribing: Bool = false
    @Published public var currentMeeting: Meeting?
    // @Published public var permissionStatus: PermissionStatusManager // Refactored to use Child ViewModel
    
    // MARK: - Child ViewModels
    public let transcriptionViewModel: TranscriptionViewModel
    public let permissionViewModel: PermissionViewModel
    
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
    // MARK: - Initialization
    public init(recordingManager: some RecordingServiceProtocol = RecordingManager.shared) {
        self.recordingManager = recordingManager
        
        // Initialize child ViewModels
        self.transcriptionViewModel = TranscriptionViewModel(status: recordingManager.transcriptionStatus)
        
        self.permissionViewModel = PermissionViewModel(
            manager: recordingManager.permissionStatus,
            requestMicrophone: { await recordingManager.requestPermission() },
            requestScreen: { await recordingManager.requestPermission() },
            openMicrophoneSettings: { recordingManager.openMicrophoneSettings() },
            openScreenSettings: { recordingManager.openPermissionSettings() }
        )
        
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
        recordingManager.isRecordingPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$isRecording)
        
        recordingManager.isTranscribingPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$isTranscribing)
        
        recordingManager.currentMeetingPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentMeeting)
            
        // Note: permissionStatus and transcriptionStatus are reference types (Classes),
        // so we don't necessarily need to re-assign them if the reference itself doesn't change.
        // However, if RecordingManager replaces them, we should observe that.
        // Assuming they are constant references in RecordingManager for now based on previous code.
    }
}
