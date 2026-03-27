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
1. Create/open an Xcode iOS App project (SwiftUI lifecycle) and set its root to `NotesApp/` sources.
2. Ensure the `.xcdatamodeld` exists and is included (see `NotesApp/Persistence/NotesApp.xcdatamodeld`).
3. Build & run on a simulator/device.

If you already have an Xcode project, just add the `NotesApp/` folder and set the app entry to `NotesAppApp`.
"""
