# iOS Notes App (SwiftUI, Core Data, MVVM)

This folder contains the **Swift iOS** implementation of the offline-first Notes app:
- Create / edit / delete notes
- Local persistence (Core Data)
- Reactive updates (NSFetchedResultsController -> ObservableObject)
- Search
- Sync skeleton (protocol + placeholder engine, last-write-wins reconciliation ready)

## Project layout
The Swift source is under `ios_frontend/NotesApp/`.

## Background sync scheduling (Step 01.02)

This scaffold uses a **plugin-style** background scheduling abstraction:

- `BackgroundSyncScheduling` protocol
- `BGTaskBackgroundSyncScheduler` (iOS 13+ BGTaskScheduler implementation)
- `NoopBackgroundSyncScheduler` fallback

The app remains fully functional even if background scheduling is not available:
- sync-on-resume still triggers in the foreground
- manual sync still works
- background scheduling calls become no-ops

### Enabling BGTaskScheduler (optional)

If you want iOS background refresh scheduling to actually run, you must add the task identifier to the app’s Info.plist:

1. Open `ios_frontend/NotesApp/Resources/Info.plist`
2. Add key: `BGTaskSchedulerPermittedIdentifiers` (Array)
3. Add item: `com.notekeeper.notesapp.sync.refresh`

The identifier must match `BGTaskBackgroundSyncScheduler.taskIdentifier`.

Note: BGTask scheduling is best-effort and subject to iOS heuristics; it is not guaranteed to run at exact intervals.

## Running
This environment may not include Xcode. On macOS:
1. Open `ios_frontend/NotesApp.xcodeproj` in Xcode.
2. Select the `NotesApp` scheme and a simulator/device.
3. Build & run.

The project already includes the SwiftUI sources under `ios_frontend/NotesApp/` and a Core Data model at `NotesApp/Persistence/NotesApp.xcdatamodeld`.
