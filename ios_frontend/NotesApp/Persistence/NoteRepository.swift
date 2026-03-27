import Foundation

protocol NoteRepository {
    // PUBLIC_INTERFACE
    /// Creates a new note and persists it locally.
    func createNote(title: String, content: String) async throws -> Note

    // PUBLIC_INTERFACE
    /// Updates an existing note locally; marks it dirty for future sync.
    func upsertNote(_ note: Note) async throws

    // PUBLIC_INTERFACE
    /// Soft-deletes a note (tombstone) locally; marks it dirty for future sync.
    func deleteNote(id: UUID) async throws

    // PUBLIC_INTERFACE
    /// Loads notes matching an optional query (title/content contains, case/diacritic insensitive).
    func fetchNotes(query: String?) async throws -> [Note]

    // PUBLIC_INTERFACE
    /// Loads notes that need syncing (dirty/failed or never synced).
    func fetchDirtyNotes() async throws -> [Note]

    // PUBLIC_INTERFACE
    /// Applies remote notes into the local store using last-write-wins by `updatedAt`.
    func reconcileRemoteNotes(_ remoteNotes: [RemoteNote]) async throws
}
