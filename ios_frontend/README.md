# iOS Notes App (SwiftUI, Core Data, MVVM)

This folder contains the **Swift iOS** implementation of the offline-first Notes app:
- Create / edit / delete notes
- Local persistence (Core Data)
- Reactive updates (NSFetchedResultsController -> ObservableObject)
- Search
- Sync skeleton (protocol + placeholder engine, last-write-wins reconciliation ready)

## Project layout
The Swift source is under `ios_frontend/NotesApp/`.

## Running
This environment may not include Xcode. On macOS:
1. Open `ios_frontend/NotesApp.xcodeproj` in Xcode.
2. Select the `NotesApp` scheme and a simulator/device.
3. Build & run.

The project already includes the SwiftUI sources under `ios_frontend/NotesApp/` and a Core Data model at `NotesApp/Persistence/NotesApp.xcdatamodeld`.
