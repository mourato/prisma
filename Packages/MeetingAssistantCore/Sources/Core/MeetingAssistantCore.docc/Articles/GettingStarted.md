# Getting Started with MeetingAssistantCore

This guide helps you integrate and use MeetingAssistantCore in your macOS application.

## Installation

MeetingAssistantCore is a Swift Package. Add it to your project via Xcode or `Package.swift`:

```swift
.package(path: "Packages/MeetingAssistantCore")
```

## Basic Usage

### Initializing the Recording Manager

```swift
import MeetingAssistantCore

let recordingManager = RecordingManager.shared
```

### Starting a Recording

```swift
await recordingManager.startRecording()
```

### Stopping and Transcribing

```swift
let url = await recordingManager.stopRecording()
// Proceed to transcription...
```
