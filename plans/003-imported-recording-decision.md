# Imported recording decision

## Decision

Choose Option B: imported recordings can be explicitly classified as either
meeting recordings or dictation/audio notes.

The import UI must ask for the capture purpose after the file is selected. It
must not silently classify every imported file as a meeting. Dictation/audio
note is the safe fallback for non-UI callers and legacy call sites.

Imported meeting recordings keep `MeetingApp.importedFile`, but use
`CapturePurpose.meeting`. They may use meeting titles, meeting post-processing,
meeting conversation/Q&A, and history actions. Imported dictations use
`CapturePurpose.dictation` and retain the existing dictation behavior.

This reuses the existing persisted `capturePurpose` field and does not require
a Core Data migration.
