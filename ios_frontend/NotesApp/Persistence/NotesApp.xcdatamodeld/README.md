This folder is a placeholder for the Core Data model bundle `NotesApp.xcdatamodeld`.

In Xcode, create a Core Data Model named **NotesApp** with an entity:

## Entity: NoteEntity
Attributes:
- id: UUID
- title: String
- content: String
- createdAt: Date
- updatedAt: Date
- isDeleted: Boolean (default false)
- lastSyncedAt: Date (Optional)
- syncStatus: Integer 16 (default 1 = dirty)

Also ensure Xcode generates `NoteEntity` as an `NSManagedObject` subclass, or set Codegen = "Class Definition" so `NoteEntity.swift` is auto-generated.

This scaffold references `NoteEntity` in code and assumes the model name is `NotesApp`.
